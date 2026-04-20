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

import 'package:flutter/foundation.dart';
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
        supportsTypography: false,
        supportsTheme: false,
        supportsHighlights: false,
        supportsAnnotations: false,
        supportsPageAnimation: false,
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

  @override
  Future<void> goToPosition(ReadingPosition position) async {}

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
      onProgressUpdated: () {},
    );

    // Must start tracking so scheduleDisposeFallbackSave is not a no-op.
    manager.startTracking();
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
      'scheduleDisposeFallbackSave does nothing when tracking was never started',
      () async {
    // Create a fresh manager that never called startTracking.
    final unstartedManager = ReadingProgressManager(
      engine: engine,
      book: _book('unstarted-book'),
      lifecycle: lifecycle,
      onProgressUpdated: () {},
    );

    unstartedManager.scheduleDisposeFallbackSave();
    engine.dispose();

    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(spyDb.positionUpdates, isEmpty,
        reason: 'No save when reading was never started');
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
