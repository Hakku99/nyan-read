import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/models/book.dart';
import '../../../core/services/database_service.dart';
import '../reader_engine/reader_engine.dart';
import '../../../core/utils/lifecycle_registry.dart';

class ReadingProgressManager {
  final ReaderEngine engine;
  final Book book;
  final LifecycleRegistry lifecycle;

  // Callback to update the main controller UI
  final VoidCallback onProgressUpdated;

  int _readSeconds = 0;
  double _currentProgress = 0.0;

  ReadingProgressManager({
    required this.engine,
    required this.book,
    required this.lifecycle,
    required this.onProgressUpdated,
  });

  int get readSeconds => _readSeconds;
  double get currentProgress => _currentProgress;
  bool get shouldShowReminder => _readSeconds > 0 && _readSeconds % 3600 == 0;

  void startTracking() {
    // 1秒阅读回调，用于全屏跟手同步进度角标
    lifecycle.registerTimer(
      Timer.periodic(const Duration(seconds: 1), (_) {
        _readSeconds++;
        // 1hr reminder triggers a broader UI update
        if (_readSeconds > 0 && _readSeconds % 3600 == 0) {
          onProgressUpdated();
        }
        _syncProgress();
      }),
    );

    // 每30秒的防抖自动保存
    lifecycle.registerTimer(
      Timer.periodic(const Duration(seconds: 30), (_) {
        saveCurrentPosition();
      }),
    );
  }

  void _syncProgress() {
    final p = engine.getProgress() ?? 0.0;
    if (p != _currentProgress) {
      _currentProgress = p;
      onProgressUpdated();
    }
  }

  /// 乐观更新进度并跳转
  Future<void> seekTo(double val) async {
    _currentProgress = val;
    onProgressUpdated(); // Optimistic update
    await engine.seekToProgress(val);
    await saveCurrentPosition(); // 保存进度
  }

  /// 负责保存阅读进度到数据库
  Future<void> saveCurrentPosition() async {
    try {
      final position = engine.getCurrentPosition();
      final progress = engine.getProgress() ?? _currentProgress;

      debugPrint(
          "DEBUG: _saveCurrentPosition called. Engine returned: ${position?.toJson()}, progress: $progress");

      if (position != null) {
        await DatabaseService().updateBookPosition(
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
