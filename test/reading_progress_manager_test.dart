/// Tests for the Phase-1 dispose-race fix in ReadingProgressManager.
///
/// Scenario: the widget tree disposes without going through PopScope.
/// ReaderController calls scheduleDisposeFallbackSave() and then
/// immediately disposes the engine.  The fallback save must:
///   - capture engine state synchronously (before engine is gone)
///   - complete its DB write without touching the engine again
///   - never throw or call dispose'd engine methods
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/database_service.dart';
import 'package:nyan_read/core/utils/lifecycle_registry.dart';
import 'package:nyan_read/modules/reader/controllers/reading_progress_manager.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_position.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeEngine extends ReaderEngine {
  bool _disposed = false;

  @override
  ReaderCapabilities get capabilities => const ReaderCapabilities(
        typography: CapabilityLevel.none,
        theme: CapabilityLevel.none,
        highlights: CapabilityLevel.none,
        annotations: CapabilityLevel.none,
        pageAnimation: CapabilityLevel.none,
        chapterNavigation: ReaderChapterNavigation.none,
      );

  @override
  Future<void> initialize() async {}

  @override
  Widget buildReader(BuildContext context) => const SizedBox.shrink();

  @override
  ReadingPosition? getCurrentPosition() {
    if (_disposed) throw StateError('engine is disposed');
    return TxtReadingPosition(paragraphIndex: 42);
  }

  @override
  double? getProgress() {
    if (_disposed) throw StateError('engine is disposed');
    return 0.42;
  }

  bool throwOnGoTo = false;

  @override
  Future<void> goToPosition(ReadingPosition position) async {
    if (throwOnGoTo) throw StateError('goToPosition failed');
  }

  @override
  void setConfig(ReaderConfig config) {}

  @override
  Future<void> seekToProgress(double progress) async {}

  @override
  Future<List<ReaderChapter>> getChapters() async => [];

  @override
  Future<void> goToChapter(ChapterLocator locator) async {}

  @override
  Future<void> nextPage() async {}

  @override
  Future<void> previousPage() async {}

  @override
  bool get hasBottomBar => false;

  @override
  void dispose() {
    _disposed = true;
  }
}

/// Records every updateBookPosition call so we can assert on them later.
class _SpyDatabaseService extends DatabaseService {
  final List<Map<String, dynamic>> positionUpdates = [];
  bool throwOnGetPosition = false;
  Map<String, dynamic>? storedPosition;
  Completer<void>? readGate;

  @override
  Future<Map<String, dynamic>?> getBookPosition(String bookId) async {
    await readGate?.future;
    if (throwOnGetPosition) throw StateError('db read failed');
    return storedPosition; // null = no saved position
  }

  @override
  Future<void> updateBookPosition(
    String bookId,
    String positionType,
    String positionPayload, {
    double? progress,
  }) async {
    positionUpdates.add({
      'bookId': bookId,
      'positionType': positionType,
      'positionPayload': positionPayload,
      'progress': progress,
    });
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Book _book(String id) => Book(
      id: id,
      title: 'Test Book',
      author: 'Author',
      filePath: '/test/$id.txt',
      format: 'txt',
    );

// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SpyDatabaseService spyDb;
  late _FakeEngine engine;
  late LifecycleRegistry lifecycle;
  late ReadingProgressManager manager;

  setUp(() async {
    spyDb = _SpyDatabaseService();
    engine = _FakeEngine();
    lifecycle = LifecycleRegistry();

    await GetIt.instance.reset();
    GetIt.instance.allowReassignment = true;
    GetIt.instance.registerSingleton<DatabaseService>(spyDb);

    manager = ReadingProgressManager(
      engine: engine,
      book: _book('dispose-test-book'),
      lifecycle: lifecycle,
      databaseService: spyDb,
      onProgressUpdated: () {},
    );

    // Must start tracking so scheduleDisposeFallbackSave is not a no-op.
    manager.startTracking();
    // Saves are gated until restore resolves (no saved position here).
    await manager.restoreLastPosition();
  });

  tearDown(() async {
    lifecycle.disposeAll();
    await GetIt.instance.reset();
  });

  // -------------------------------------------------------------------------

  test(
      'scheduleDisposeFallbackSave captures engine state before engine.dispose() '
      'and completes the DB write without touching the engine again', () async {
    // This is the exact ordering inside ReaderController.dispose():
    //   1. scheduleDisposeFallbackSave()
    //   2. engine.dispose()
    manager.scheduleDisposeFallbackSave();
    engine.dispose(); // engine is now dead

    // Give the fire-and-forget async write time to complete.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(spyDb.positionUpdates, hasLength(1),
        reason: 'Exactly one fallback DB write must be issued');

    final update = spyDb.positionUpdates.first;
    expect(update['bookId'], 'dispose-test-book');
    expect(update['positionType'], 'txt');
    expect(update['progress'], closeTo(0.42, 0.001));
  });

  test(
      'scheduleDisposeFallbackSave does nothing when prepareForExit was already called '
      '(normal exit path)', () async {
    await manager.prepareForExit();

    // After a clean exit, fallback save must be suppressed.
    manager.scheduleDisposeFallbackSave();
    engine.dispose();

    await Future<void>.delayed(const Duration(milliseconds: 50));

    // prepareForExit wrote once; scheduleDisposeFallbackSave must add nothing.
    expect(spyDb.positionUpdates, hasLength(1));
  });

  test(
      'prepareForExit (lock-triggered exit) skips the write while canSavePosition '
      'is false and suppresses the dispose fallback, so a PDF start-up never '
      'overwrites the saved position', () async {
    var ready = false;
    final gated = ReadingProgressManager(
      engine: engine,
      book: _book('gated-book'),
      lifecycle: lifecycle,
      databaseService: spyDb,
      onProgressUpdated: () {},
      canSavePosition: () => ready,
    )..startTracking();

    await gated.prepareForExit();
    gated.scheduleDisposeFallbackSave();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(spyDb.positionUpdates, isEmpty);

    ready = true;
    await gated.prepareForExit();
    expect(spyDb.positionUpdates.where((u) => u['bookId'] == 'gated-book'),
        hasLength(1));
  });

  test(
      'scheduleDisposeFallbackSave does nothing when tracking was never started',
      () async {
    // Create a fresh manager that never called startTracking.
    final unstartedManager = ReadingProgressManager(
      engine: engine,
      book: _book('unstarted-book'),
      lifecycle: lifecycle,
      databaseService: spyDb,
      onProgressUpdated: () {},
    );

    unstartedManager.scheduleDisposeFallbackSave();
    engine.dispose();

    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(spyDb.positionUpdates, isEmpty,
        reason: 'No save when reading was never started');
  });

  group('restore gate (TXT/EPUB)', () {
    ReadingProgressManager fresh({bool Function()? canSave}) =>
        ReadingProgressManager(
          engine: engine,
          book: _book('gate-book'),
          lifecycle: lifecycle,
          databaseService: spyDb,
          onProgressUpdated: () {},
          canSavePosition: canSave,
        )..startTracking();

    test('saves are skipped until restore resolves', () async {
      final m = fresh();
      await m.saveCurrentPosition();
      await m.prepareForExit();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(spyDb.positionUpdates, isEmpty);
    });

    test('dispose fallback is gated on its own', () async {
      final m = fresh();
      m.scheduleDisposeFallbackSave();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(spyDb.positionUpdates, isEmpty);
    });

    test('gated prepareForExit does not suppress the later fallback save',
        () async {
      final m = fresh();
      await m.prepareForExit(); // skipped by the gate
      await m.restoreLastPosition();
      m.scheduleDisposeFallbackSave();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(spyDb.positionUpdates, hasLength(1));
    });

    test('saves are skipped while restore is in flight, written after',
        () async {
      spyDb.readGate = Completer<void>();
      final m = fresh();
      final restore = m.restoreLastPosition();
      await m.saveCurrentPosition();
      expect(spyDb.positionUpdates, isEmpty);
      spyDb.readGate!.complete();
      await restore;
      await m.saveCurrentPosition();
      expect(spyDb.positionUpdates, hasLength(1));
    });

    test('saves go through after goToPosition throws', () async {
      spyDb.storedPosition = {
        'position_type': 'txt',
        'position_payload': '{"paragraphIndex": 7}',
      };
      engine.throwOnGoTo = true;
      final m = fresh();
      await m.restoreLastPosition();
      await m.saveCurrentPosition();
      expect(spyDb.positionUpdates, hasLength(1));
    });

    test('saves go through after restore resolves', () async {
      final m = fresh();
      await m.restoreLastPosition();
      await m.saveCurrentPosition();
      expect(spyDb.positionUpdates, hasLength(1));
    });

    test('saves go through after restore throws', () async {
      spyDb.throwOnGetPosition = true;
      final m = fresh();
      await m.restoreLastPosition();
      await m.saveCurrentPosition();
      expect(spyDb.positionUpdates, hasLength(1));
    });

    test('custom canSavePosition (PDF) overrides the restore flag', () async {
      var allowed = false;
      final m = fresh(canSave: () => allowed);
      await m.restoreLastPosition();
      await m.saveCurrentPosition();
      expect(spyDb.positionUpdates, isEmpty);
      allowed = true;
      await m.saveCurrentPosition();
      expect(spyDb.positionUpdates, hasLength(1));
    });
  });

  test('no crash or exception when engine is already disposed before snapshot',
      () async {
    // Edge case: engine disposed before scheduleDisposeFallbackSave is called.
    engine.dispose();

    // Must not throw – the try/catch in scheduleDisposeFallbackSave absorbs it.
    expect(() => manager.scheduleDisposeFallbackSave(), returnsNormally);

    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Engine threw on getCurrentPosition, so no write should happen.
    expect(spyDb.positionUpdates, isEmpty);
  });
}
