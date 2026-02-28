import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../lib/core/models/book.dart';
import '../../lib/modules/reader/reader_engine/reader_engine.dart';
import '../../lib/core/utils/lifecycle_registry.dart';
import '../../lib/modules/reader/controllers/reading_progress_manager.dart';

class MockReadingProgressManager implements ReadingProgressManager {
  @override
  final ReaderEngine engine;
  @override
  final Book book;
  @override
  final LifecycleRegistry lifecycle;
  @override
  final VoidCallback onProgressUpdated;

  MockReadingProgressManager({
    required this.engine,
    required this.book,
    required this.lifecycle,
    required this.onProgressUpdated,
  });

  @override
  int get readSeconds => 0;

  @override
  double get currentProgress => 0.5;

  @override
  bool get shouldShowReminder => false;

  @override
  void startTracking() {}

  @override
  Future<void> saveCurrentPosition() async {}

  @override
  Future<void> seekTo(double val) async {}
}
