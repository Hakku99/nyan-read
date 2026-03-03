import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';
import 'service_locator.dart';

class BackupRecoveryService extends WidgetsBindingObserver {
  // 机制 A：最多保留 3 份健康快照
  static const int _maxBackups = 3;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    debugPrint('--- [BackupRecoveryService] 地堡系统初始化，已监听生命周期 ---');
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      debugPrint('--- [BackupRecoveryService] 触发静默冷备机制 (App paused) ---');
      _performColdBackup();
    }
  }

  /// 机制 A: 静默冷备与滚动沙盒
  Future<void> _performColdBackup() async {
    try {
      final dbPath = await getDatabasesPath();
      final mainDbPath = join(dbPath, 'nyan_read.db');
      final backupDir = Directory(join(dbPath, 'backups'));

      if (!File(mainDbPath).existsSync()) {
        debugPrint('--- [BackupRecoveryService] 主数据库不存在，跳过冷备 ---');
        return;
      }

      if (!backupDir.existsSync()) {
        backupDir.createSync(recursive: true);
      }

      // 生成带时间戳的沙盒目录
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final snapshotDir =
          Directory(join(backupDir.path, 'snapshot_$timestamp'));
      snapshotDir.createSync(recursive: true);

      // 使用 Isolate 将物理复制切离主线程绞肉机。必须同时复制 -wal 和 -shm 保证数据一致性。
      await Isolate.run(() {
        try {
          final mainDbFile = File(mainDbPath);
          final walFile = File('$mainDbPath-wal');
          final shmFile = File('$mainDbPath-shm');

          mainDbFile.copySync(join(snapshotDir.path, 'nyan_read.db'));
          if (walFile.existsSync())
            walFile.copySync(join(snapshotDir.path, 'nyan_read.db-wal'));
          if (shmFile.existsSync())
            shmFile.copySync(join(snapshotDir.path, 'nyan_read.db-shm'));

          debugPrint('--- [Isolate] 数据库静默冷备成功: ${snapshotDir.path} ---');
        } catch (e) {
          debugPrint('--- [Isolate] 数据库物理冷备失败: $e ---');
        }
      });

      // 自动清理，保持滚动沙盒
      await _cleanupOldBackups(backupDir);
    } catch (e, stack) {
      debugPrint(
          '--- [BackupRecoveryService] performColdBackup 出现严重异常: $e\n$stack ---');
    }
  }

  Future<void> _cleanupOldBackups(Directory backupDir) async {
    try {
      final dirs = backupDir.listSync().whereType<Directory>().toList();
      dirs.sort((a, b) =>
          b.statSync().modified.compareTo(a.statSync().modified)); // 新的在前

      if (dirs.length > _maxBackups) {
        for (var i = _maxBackups; i < dirs.length; i++) {
          try {
            dirs[i].deleteSync(recursive: true);
            debugPrint(
                '--- [BackupRecoveryService] 清理旧冷备: ${dirs[i].path} ---');
          } catch (e) {
            debugPrint('--- [BackupRecoveryService] 清理旧冷备失败: $e ---');
          }
        }
      }
    } catch (e) {
      debugPrint('--- [BackupRecoveryService] 清理旧冷备出现全局异常: $e ---');
    }
  }

  /// 机制 C: 资产降维导出 (Markdown Export)
  Future<String> exportBookNotesToMarkdown(String bookId) async {
    try {
      final dbService = getIt<DatabaseService>();
      final book = await dbService.getBookById(bookId);
      if (book == null) {
        return '# Error\nBook not found.';
      }

      final highlights = await dbService.getHighlights(bookId);
      final bookmarks = await dbService.getBookmarks(bookId);

      final buffer = StringBuffer();
      buffer.writeln('# ${book['title'] ?? 'Unknown Book'} - 笔记导出');
      buffer.writeln(
          '导出时间: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}\n');

      if (highlights.isEmpty && bookmarks.isEmpty) {
        buffer.writeln('本书暂无高亮或笔记。');
        return buffer.toString();
      }

      if (highlights.isNotEmpty) {
        buffer.writeln('## 高亮与笔记\n');
        for (final h in highlights) {
          final text = h['selected_text'] ?? '';
          final note = h['note'];

          buffer.writeln('> $text');
          if (note != null && note.toString().isNotEmpty) {
            buffer.writeln('📝 $note');
          }
          buffer.writeln('');
        }
      }

      if (bookmarks.isNotEmpty) {
        buffer.writeln('## 书签记录\n');
        for (final b in bookmarks) {
          final snippet = b['content_snippet'] ?? '位置标记';
          final note = b['note'];

          buffer.writeln('> $snippet');
          if (note != null && note.toString().isNotEmpty) {
            buffer.writeln('📝 $note');
          }
          buffer.writeln('');
        }
      }

      debugPrint('--- [BackupRecoveryService] 资产降维导出成功，Book ID: $bookId ---');
      return buffer.toString();
    } catch (e, stack) {
      debugPrint('--- [BackupRecoveryService] 导出Markdown失败: $e\n$stack ---');
      return '# Error\nFailed to export notes: $e';
    }
  }
}
