import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/book.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/lifecycle_registry.dart';
import '../reader_engine/reader_engine.dart';

/// Owns the "where is the reader right now" state for a single open book.
///
/// Split surface:
///   - [progressListenable] — a `ValueListenable<double>` that ticks every
///     time the 0..1 scroll/CFI progress changes.  Read-heavy UI (the tiny
///     "42%" label at the foot of the reader, the overlay slider thumb) is
///     expected to subscribe to this directly so the 1s reading heartbeat
///     never rebuilds the whole reader tree.
///   - [onProgressUpdated] — a callback the host controller wires into its
///     own `notifyListeners`.  This now fires **only when the underlying
///     position changed** (TOC index, paragraph index, CFI), NOT on every
///     progress tick.  Everything that depends on position (chapter sync,
///     TOC highlight) already lives behind this gate.
class ReadingProgressManager {
  final ReaderEngine engine;
  final Book book;
  final LifecycleRegistry lifecycle;
  final DatabaseService databaseService;

  /// Fired only when [currentPosition] changes (paragraph/CFI/page).
  /// Progress-only ticks do NOT call this; they route through
  /// [progressListenable] instead.
  final VoidCallback onProgressUpdated;

  int _readSeconds = 0;
  ReadingPosition? _currentPosition;
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);
  bool _trackingStarted = false;
  bool _prepareForExitRequested = false;
  Future<void>? _saveInFlight;
  bool _disposed = false;

  DatabaseService get _db => databaseService;

  ReadingProgressManager({
    required this.engine,
    required this.book,
    required this.lifecycle,
    required this.databaseService,
    required this.onProgressUpdated,
  });

  int get readSeconds => _readSeconds;
  ReadingPosition? get currentPosition => _currentPosition;
  double get currentProgress => _progressNotifier.value;

  /// Read-only reactive handle for progress-bound widgets.  Widgets that
  /// care about the scrubber value should subscribe to this instead of
  /// the reader-wide ChangeNotifier to avoid full-subtree rebuilds.
  ValueListenable<double> get progressListenable => _progressNotifier;

  bool get shouldShowReminder => _readSeconds > 0 && _readSeconds % 3600 == 0;

  void startTracking() {
    if (_trackingStarted) return;
    _trackingStarted = true;

    // 1s reading heartbeat: keeps [progressListenable] in sync with engine
    // scroll and accrues [_readSeconds].  Position-scoped listeners are
    // only poked via [refreshFromEngine] when the engine reports a new
    // paragraph/CFI, so hidden UI (overlay, TOC) stays inert during
    // pure scrolling.
    lifecycle.registerTimer(
      Timer.periodic(const Duration(seconds: 1), (_) {
        _readSeconds++;
        refreshFromEngine();
      }),
    );

    // Auto-save every 30 seconds during an active reading session.
    lifecycle.registerTimer(
      Timer.periodic(const Duration(seconds: 30), (_) {
        unawaited(saveCurrentPosition());
      }),
    );
  }

  Future<void> restoreLastPosition() async {
    try {
      debugPrint("DEBUG: restoreLastPosition called for book ${book.id}");
      final positionData = await _db.getBookPosition(book.id);
      if (positionData == null) {
        debugPrint("DEBUG: No saved position found in DB");
        return;
      }

      final type = positionData['position_type'] as String;
      final payload = positionData['position_payload'] as String;
      debugPrint("DEBUG: RESTORING position: type=$type, payload=$payload");

      final position = ReadingPosition.fromJson(type, payload);

      if (position.hasLocation) {
        await engine.goToPosition(position);
        await Future<void>.delayed(const Duration(milliseconds: 180));
        refreshFromEngine();

        final shouldFallbackToProgress =
            position.cfi != null &&
            position.cfi!.isNotEmpty &&
            book.currentProgress > 0 &&
            ((_currentPosition == null) || _progressNotifier.value <= 0.0);

        if (shouldFallbackToProgress) {
          debugPrint(
              "DEBUG: EPUB position restore did not advance, falling back to saved progress ${book.currentProgress}");
          await engine.seekToProgress(book.currentProgress);
          await Future<void>.delayed(const Duration(milliseconds: 120));
          refreshFromEngine();
        }

        debugPrint("DEBUG: Position restored to engine successfully");
      }
    } catch (e) {
      debugPrint('Error restoring position: $e');
    }
  }

  void refreshFromEngine() {
    if (_disposed) return;
    final position = engine.getCurrentPosition();
    final progress = engine.getProgress() ?? 0.0;

    final didPositionChange = _currentPosition?.toJson() != position?.toJson();

    _currentPosition = position;
    // ValueNotifier dedups on ==, so calling this every tick is a no-op
    // unless the value actually advanced.
    _progressNotifier.value = progress;

    if (didPositionChange) {
      onProgressUpdated();
    }
  }

  Future<void> seekTo(double val) async {
    _progressNotifier.value = val;
    await engine.seekToProgress(val);
    refreshFromEngine();
    await saveCurrentPosition();
  }

  Future<void> saveCurrentPosition() {
    final pending = _saveInFlight;
    if (pending != null) {
      return pending;
    }

    final future = _performSaveCurrentPosition();
    _saveInFlight = future;
    return future.whenComplete(() {
      if (identical(_saveInFlight, future)) {
        _saveInFlight = null;
      }
    });
  }

  Future<void> saveForLifecyclePause() => saveCurrentPosition();

  Future<void> prepareForExit() {
    _prepareForExitRequested = true;
    return saveCurrentPosition();
  }

  /// Fallback save when the widget disposes WITHOUT going through PopScope
  /// (e.g. forced route replacement, process stop, or Android back gesture
  /// that bypasses our handler).
  ///
  /// IMPORTANT:  the caller is about to dispose the engine.  We must read
  /// every piece of engine state synchronously here and hand the detached
  /// snapshot to a fire-and-forget DB write whose continuation never
  /// touches the engine again.  Do NOT route through
  /// [saveCurrentPosition] because the in-flight dedup there could hand
  /// back a pre-existing save that is still trying to talk to the engine.
  void scheduleDisposeFallbackSave() {
    if (!_trackingStarted || _prepareForExitRequested) return;

    ReadingPosition? snapshotPosition;
    double snapshotProgress = _progressNotifier.value;
    try {
      snapshotPosition = engine.getCurrentPosition();
      snapshotProgress = engine.getProgress() ?? snapshotProgress;
    } catch (e) {
      debugPrint('scheduleDisposeFallbackSave: engine snapshot failed: $e');
      return;
    }
    if (snapshotPosition == null) return;

    final capturedPosition = snapshotPosition;
    final capturedProgress = snapshotProgress;
    final bookId = book.id;
    final format = book.format;
    final db = _db;
    unawaited(() async {
      try {
        await db.updateBookPosition(
          bookId,
          format,
          capturedPosition.toJson(),
          progress: capturedProgress,
        );
      } catch (e) {
        debugPrint('Fallback dispose save failed: $e');
      }
    }());
  }

  Future<void> _performSaveCurrentPosition() async {
    try {
      final position = engine.getCurrentPosition();
      final progress = engine.getProgress() ?? _progressNotifier.value;
      _currentPosition = position;
      _progressNotifier.value = progress;

      debugPrint(
          "DEBUG: _saveCurrentPosition called. Engine returned: ${position?.toJson()}, progress: $progress");

      if (position != null) {
        await _db.updateBookPosition(
          book.id,
          book.format,
          position.toJson(),
          progress: progress,
        );
        debugPrint("DEBUG: Position and progress saved to DB");
      } else {
        debugPrint("DEBUG: Engine returned null position, NOT saving.");
      }
    } catch (e) {
      debugPrint('Error saving position: $e');
    }
  }

  /// Called by the owning controller when the reader surface is torn down.
  /// Safe to call multiple times.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _progressNotifier.dispose();
  }
}
