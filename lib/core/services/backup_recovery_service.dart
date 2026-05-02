import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:intl/intl.dart';
import 'database_service.dart';
import 'service_locator.dart';

class BackupRecoveryService extends WidgetsBindingObserver {
  // Mechanism A: keep at most 3 healthy cold-backup snapshots on disk.
  static const int _maxBackups = 3;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    debugPrint(
        '--- [BackupRecoveryService] Lifecycle observer registered; cold-backup system armed ---');
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      debugPrint(
          '--- [BackupRecoveryService] App paused: triggering silent cold backup ---');
      _performColdBackup();
    }
  }

  /// Mechanism A: silent cold backup + rolling sandbox.
  Future<void> _performColdBackup() async {
    try {
      final dbPath = await getDatabasesPath();
      final mainDbPath = join(dbPath, 'nyan_read.db');
      final backupDir = Directory(join(dbPath, 'backups'));

      if (!File(mainDbPath).existsSync()) {
        debugPrint(
            '--- [BackupRecoveryService] Main database missing; skipping cold backup ---');
        return;
      }

      if (!backupDir.existsSync()) {
        backupDir.createSync(recursive: true);
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final snapshotDir =
          Directory(join(backupDir.path, 'snapshot_$timestamp'));
      snapshotDir.createSync(recursive: true);

      // Offload the copy (main DB + -wal + -shm, all three are required for
      // a consistent snapshot) to an isolate so the UI never stalls on sync
      // file I/O during lifecycle pauses.
      await Isolate.run(() {
        try {
          final mainDbFile = File(mainDbPath);
          final walFile = File('$mainDbPath-wal');
          final shmFile = File('$mainDbPath-shm');

          mainDbFile.copySync(join(snapshotDir.path, 'nyan_read.db'));
          if (walFile.existsSync()) {
            walFile.copySync(join(snapshotDir.path, 'nyan_read.db-wal'));
          }
          if (shmFile.existsSync()) {
            shmFile.copySync(join(snapshotDir.path, 'nyan_read.db-shm'));
          }

          debugPrint(
              '--- [Isolate] Cold backup written: ${snapshotDir.path} ---');
        } catch (e) {
          debugPrint('--- [Isolate] Cold backup file copy failed: $e ---');
        }
      });

      await _cleanupOldBackups(backupDir);
    } catch (e, stack) {
      debugPrint(
          '--- [BackupRecoveryService] _performColdBackup raised fatal error: $e\n$stack ---');
    }
  }

  /// Offloads the directory scan + sync deletes to a helper isolate so the
  /// boot / lifecycle pause path never blocks the UI thread with file-system
  /// work. Only primitive strings cross the isolate boundary; logs are
  /// collected and replayed on the main isolate.  (Phase 2 / P0-7.)
  Future<void> _cleanupOldBackups(Directory backupDir) async {
    try {
      final logs = await Isolate.run(
        () => _runCleanupOldBackupsInIsolate(backupDir.path, _maxBackups),
      );
      for (final line in logs) {
        debugPrint(line);
      }
    } catch (e) {
      debugPrint(
          '--- [BackupRecoveryService] Old-backup cleanup crashed: $e ---');
    }
  }

  static List<String> _runCleanupOldBackupsInIsolate(
      String backupDirPath, int maxBackups) {
    final logs = <String>[];
    try {
      final backupDir = Directory(backupDirPath);
      if (!backupDir.existsSync()) return logs;

      final dirs = backupDir.listSync().whereType<Directory>().toList();
      // Newest first.
      dirs.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );

      if (dirs.length > maxBackups) {
        for (var i = maxBackups; i < dirs.length; i++) {
          try {
            dirs[i].deleteSync(recursive: true);
            logs.add(
                '--- [BackupRecoveryService] Deleted stale cold backup: ${dirs[i].path} ---');
          } catch (e) {
            logs.add(
                '--- [BackupRecoveryService] Failed to delete stale cold backup: $e ---');
          }
        }
      }
    } catch (e) {
      logs.add(
          '--- [BackupRecoveryService] Old-backup cleanup aborted: $e ---');
    }
    return logs;
  }

  /// Mechanism C: asset downgrade export (Markdown).
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

  /// 机制 D: 全局资产结构化导出 (Data Portability)
  /// 正确架构：sqflite Platform Channel 只能在主线程调用。
  /// 主线程负责全量数据抓取，纯 Dart 的 jsonEncode + 文件写入才放入 Isolate。
  Future<String> exportGlobalUserData() async {
    final dbService = getIt<DatabaseService>();
    final tempDir = await getTemporaryDirectory();

    // [主线程] 执行 3 次全量查询，消灭 N+1 风暴
    // Platform Channel (sqflite) 只能在主线程被安全调用
    final allBooksList = await dbService.getAllBooks();
    final allHighlightsList = await dbService.getAllHighlights();
    final allBookmarksList = await dbService.getAllBookmarks();

    debugPrint('--- [Export] 主线程数据抓取完成: ${allBooksList.length} 本书 ---');

    // 将纯 Dart 数据传入 Isolate，由其完成 CPU 密集型的序列化与 I/O
    final payload = _ExportPayload(
      tempDirPath: tempDir.path,
      books: allBooksList,
      highlights: allHighlightsList,
      bookmarks: allBookmarksList,
    );
    return await Isolate.run(() => _heavyJsonSerializeTask(payload));
  }

  /// [Isolate 内部] 接收主线程传来的纯数据，完成序列化与文件写入
  /// 注意：这里没有任何 Platform Channel 调用，完全是纯 Dart 计算
  static Future<String> _heavyJsonSerializeTask(_ExportPayload payload) async {
    try {
      // 1. 内存 Map 提速组装 (O(1) 查询聚合)
      final highlightsMap = <String, List<Map<String, dynamic>>>{};
      for (final h in payload.highlights) {
        final bookId = h['book_id'] as String;
        highlightsMap.putIfAbsent(bookId, () => []).add(h);
      }

      final bookmarksMap = <String, List<Map<String, dynamic>>>{};
      for (final b in payload.bookmarks) {
        final bookId = b['book_id'] as String;
        bookmarksMap.putIfAbsent(bookId, () => []).add(b);
      }

      // 2. 构建嵌套树
      final assembledBooksList = payload.books.map((book) {
        final bookId = book['id'] as String;
        final mutableBook = Map<String, dynamic>.from(book);
        mutableBook['highlights'] = highlightsMap[bookId] ?? [];
        mutableBook['bookmarks'] = bookmarksMap[bookId] ?? [];
        return mutableBook;
      }).toList();

      final exportMap = {
        'version': 1,
        'export_date': DateTime.now().toIso8601String(),
        'app_name': 'Nyan Read',
        'books': assembledBooksList,
      };

      // 3. 绞肉机：极其沉重的 JSON 序列化 (现在完全与 UI 线程隔离)
      final jsonString = jsonEncode(exportMap);

      // 4. I/O 写入临时沙盒目录
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile =
          File(join(payload.tempDirPath, 'nyan_read_export_$timestamp.json'));
      await tempFile.writeAsString(jsonString, flush: true);

      debugPrint(
          '--- [Isolate Serialize] 完成! 尺寸: ${(tempFile.lengthSync() / 1024).toStringAsFixed(2)} KB ---');
      return tempFile.path;
    } catch (e, stack) {
      debugPrint('--- [Isolate Serialize Error] $e\n$stack ---');
      throw Exception('Data export failed: $e');
    }
  }

  /// 机制 E: 全局资产导入恢复 (Data Restore)
  /// file_picker 选文件 → Isolate 负责 readAsString + jsonDecode → 主线程 restoreDataBatch
  Future<int> importGlobalUserData() async {
    // 1. 在主线程唤起文件选择器（Platform Channel）
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );

    if (pick == null || pick.files.single.path == null) {
      return -1; // 用户取消，无需报错
    }

    final filePath = pick.files.single.path!;

    // 2. 将 readAsString + jsonDecode 推入 Isolate 防 OOM 与掉帧
    final parsedJson = await Isolate.run(() => _heavyJsonParseTask(filePath));

    // 3. 将解析后的纯 Dart Map 交给主线程 DatabaseService 批量写入
    final dbService = getIt<DatabaseService>();
    final restoredCount = await dbService.restoreDataBatch(parsedJson);
    return restoredCount;
  }

  /// [Isolate 内部] 单纯做文件读取和 JSON 解析，无任何 Platform Channel 调用
  static Map<String, dynamic> _heavyJsonParseTask(String filePath) {
    final content = File(filePath).readAsStringSync();
    return jsonDecode(content) as Map<String, dynamic>;
  }
}

class _ExportPayload {
  final String tempDirPath;
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> highlights;
  final List<Map<String, dynamic>> bookmarks;

  _ExportPayload({
    required this.tempDirPath,
    required this.books,
    required this.highlights,
    required this.bookmarks,
  });
}
