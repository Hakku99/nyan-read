import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
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

  /// 机制 B: 全局沙盒清道夫 (Global Cache Scavenger)
  /// 在后台 Isolate 中静默清除 getTemporaryDirectory() 下的 EPUB 解压碎片和孤儿缓存。
  /// 绝对不触碰 getApplicationDocumentsDirectory()，保护书库资产。
  /// 增加老化过滤：仅清除超过 24 小时的文件，避免误杀正常缓存。
  Future<void> runCacheScavenger() async {
    try {
      // 在主线程获取路径
      final tempDir = await getTemporaryDirectory();

      debugPrint('--- [Cache Scavenger] 启动全局临时碎片扫荡，目标沙盒: ${tempDir.path} ---');

      // 绞肉机隔离：将耗时的目录遍历和成百上千个小文件的物理删除推送至 Isolate
      await Isolate.run(() => _heavyCacheCleanupTask(tempDir.path));
    } catch (e, stack) {
      debugPrint('--- [Cache Scavenger] 清道夫防线崩溃: $e\n$stack ---');
    }
  }

  /// 顶级方法，用于被 Isolate.run() 调用
  static void _heavyCacheCleanupTask(String tempDirPath) {
    try {
      final tempDir = Directory(tempDirPath);
      if (!tempDir.existsSync()) return;

      int deletedFilesCount = 0;
      int deletedSize = 0;
      final now = DateTime.now();

      // 同步遍历，避免在 Isolate 中产生过多 Future 微任务导致内存冲刷
      final entities = tempDir.listSync(recursive: true, followLinks: false);

      for (final entity in entities) {
        if (entity is File) {
          try {
            // 敌我识别：获取最后修改时间
            final lastModified = entity.lastModifiedSync();
            final differenceHours = now.difference(lastModified).inHours;

            // 仅清理老化超过 24 小时（24小时）的残留物
            if (differenceHours >= 24) {
              final size = entity.lengthSync();
              entity.deleteSync();
              deletedSize += size;
              deletedFilesCount++;
            }
          } catch (e) {
            // 忽略单文件删除失败（如文件正被底层持有关联或无权限）
          }
        }
      }

      final megabytes = (deletedSize / (1024 * 1024)).toStringAsFixed(2);
      debugPrint(
          '--- [Isolate Scavenger] 扫荡完成！共抹除 $deletedFilesCount 个临时碎片，释放 $megabytes MB 缓存空间 ---');
    } catch (e) {
      debugPrint('--- [Isolate Scavenger] 清理任务异常: $e ---');
    }
  }
}
