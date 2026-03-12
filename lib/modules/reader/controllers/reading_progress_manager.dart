import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/book.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/utils/lifecycle_registry.dart';
import '../reader_engine/reader_engine.dart';

class ReadingProgressManager {
  final ReaderEngine engine;
  final Book book;
  final LifecycleRegistry lifecycle;

  // Callback to update the main controller UI
  final VoidCallback onProgressUpdated;

  int _readSeconds = 0;
  ReadingPosition? _currentPosition;
  double _currentProgress = 0.0;
  bool _trackingStarted = false;
  bool _prepareForExitRequested = false;
  Future<void>? _saveInFlight;

  DatabaseService get _db => getIt<DatabaseService>();

  ReadingProgressManager({
    required this.engine,
    required this.book,
    required this.lifecycle,
    required this.onProgressUpdated,
  });

  int get readSeconds => _readSeconds;
  ReadingPosition? get currentPosition => _currentPosition;
  double get currentProgress => _currentProgress;
  bool get shouldShowReminder => _readSeconds > 0 && _readSeconds % 3600 == 0;

  void startTracking() {
    if (_trackingStarted) return;
    _trackingStarted = true;

    // 1s reading heartbeat keeps UI progress in sync.
    lifecycle.registerTimer(
      Timer.periodic(const Duration(seconds: 1), (_) {
        _readSeconds++;
        if (_readSeconds > 0 && _readSeconds % 3600 == 0) {
          onProgressUpdated();
        }
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
            ((_currentPosition == null) || _currentProgress <= 0.0);

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
    final position = engine.getCurrentPosition();
    final progress = engine.getProgress() ?? 0.0;

    final didPositionChange = _currentPosition?.toJson() != position?.toJson();
    final didProgressChange = progress != _currentProgress;

    _currentPosition = position;
    _currentProgress = progress;

    if (didPositionChange || didProgressChange) {
      onProgressUpdated();
    }
  }

  Future<void> seekTo(double val) async {
    _currentProgress = val;
    onProgressUpdated();
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

  void scheduleDisposeFallbackSave() {
    if (!_trackingStarted || _prepareForExitRequested) return;
    unawaited(saveCurrentPosition());
  }

  Future<void> _performSaveCurrentPosition() async {
    try {
      final position = engine.getCurrentPosition();
      final progress = engine.getProgress() ?? _currentProgress;
      _currentPosition = position;
      _currentProgress = progress;

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
}
