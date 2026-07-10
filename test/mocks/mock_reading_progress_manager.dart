import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/database_service.dart';
import 'package:nyan_read/core/utils/lifecycle_registry.dart';
import 'package:nyan_read/modules/reader/controllers/reading_progress_manager.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';

class MockReadingProgressManager implements ReadingProgressManager {
  MockReadingProgressManager({
    required this.engine,
    required this.book,
    required this.lifecycle,
    DatabaseService? databaseService,
    required this.onProgressUpdated,
  }) : databaseService = databaseService ?? _NoopDatabaseService();

  @override
  final ReaderEngine engine;

  @override
  final Book book;

  @override
  final LifecycleRegistry lifecycle;

  @override
  final DatabaseService databaseService;

  @override
  final VoidCallback onProgressUpdated;

  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.5);

  @override
  ReadingPosition? get currentPosition => null;

  @override
  double get currentProgress => _progressNotifier.value;

  @override
  ValueListenable<double> get progressListenable => _progressNotifier;

  @override
  void startTracking() {}

  @override
  void refreshFromEngine() {}

  @override
  Future<void> restoreLastPosition() async {}

  @override
  Future<void> saveCurrentPosition() async {}

  @override
  Future<void> saveForLifecyclePause() async {}

  @override
  Future<void> prepareForExit() async {}

  @override
  void scheduleDisposeFallbackSave() {}

  @override
  Future<void> seekTo(double val) async {}

  @override
  void dispose() {
    _progressNotifier.dispose();
  }
}

class _NoopDatabaseService extends DatabaseService {}
