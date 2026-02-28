import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

// --- Background Isolate Payloads & Results ---

/// 扫描进度载体 (用于回调给 UI)
class ScanProgress {
  final int totalScanned;
  final int validFound;
  ScanProgress(this.totalScanned, this.validFound);
}

/// 发给 Isolate 的参数载体
class _ScanPayload {
  final String folderPath;
  final bool includeHidden;
  final Set<String> existingFilenames;
  final SendPort? progressPort;

  _ScanPayload(this.folderPath, this.includeHidden, this.existingFilenames,
      this.progressPort);
}

/// 最终扫描结果 (所有文件以绝对路径 String 和解析好的 Map 返回)
class FolderScanResult {
  final List<String> filePaths;
  final List<Map<String, dynamic>> parsedBooks; // 直接可以直接入库的 Book Map
  final int totalScanned;
  final int skippedHidden;
  final Map<String, int> skippedExtensions;
  final List<String> errors;

  FolderScanResult({
    required this.filePaths,
    required this.parsedBooks,
    required this.totalScanned,
    required this.skippedHidden,
    required this.skippedExtensions,
    required this.errors,
  });
}

/// Service for handling folder import and batch book operations
class FolderImportService {
  static final FolderImportService _instance = FolderImportService._internal();
  static FolderImportService get instance => _instance;

  FolderImportService._internal();

  /// Supported book file extensions
  static const List<String> supportedExtensions = ['.epub', '.txt', '.pdf'];

  /// Background Folder Scan via Isolate
  /// 完全解决主线程 I/O 阻塞
  Future<FolderScanResult> scanFolderBackground(
    String folderPath,
    Set<String> existingFilenames, {
    bool includeHidden = false,
    Function(ScanProgress)? onProgress,
  }) async {
    final receivePort = ReceivePort();

    if (onProgress != null) {
      receivePort.listen((message) {
        if (message is ScanProgress) {
          onProgress(message);
        }
      });
    }

    final payload = _ScanPayload(
        folderPath, includeHidden, existingFilenames, receivePort.sendPort);

    // 发射到后台 Isolate 运算
    final result = await Isolate.run(() async {
      return await _heavyScanTask(payload);
    });

    receivePort.close();
    return result;
  }

  /// 顶层 (脱离原本单例) 的后台重计算任务
  static Future<FolderScanResult> _heavyScanTask(_ScanPayload payload) async {
    final List<String> validFilePaths = [];
    final List<Map<String, dynamic>> parsedBooks = [];
    final Map<String, int> skippedExtensions = {};
    final List<String> errors = [];
    int totalScanned = 0;
    int skippedHidden = 0;

    final dir = Directory(payload.folderPath);

    if (!dir.existsSync()) {
      errors.add("Folder does not exist: ${payload.folderPath}");
      return FolderScanResult(
          filePaths: validFilePaths,
          parsedBooks: parsedBooks,
          totalScanned: 0,
          skippedHidden: 0,
          skippedExtensions: skippedExtensions,
          errors: errors);
    }

    try {
      // 这里的阻塞将严格拘谨在 Isolate 里
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalScanned++;
          final fileName = path.basename(entity.path);

          // Filter hidden
          if (!payload.includeHidden && fileName.startsWith('.')) {
            skippedHidden++;
            continue;
          }

          // Filter by ext
          final ext = path.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(ext)) {
            // Deduplication
            if (!payload.existingFilenames.contains(fileName)) {
              validFilePaths.add(entity.path);

              // ============================================
              // 在这里直接完成耗时的元数据组装/头文件基础解析
              // ============================================
              parsedBooks.add({
                'id': const Uuid().v4(), // 需要引入 uuid 兜底
                'title': path.basenameWithoutExtension(entity.path),
                'author': 'Unknown',
                'file_path': entity.path,
                'format': ext.replaceAll('.', ''),
                'is_private': 0,
                'added_at': DateTime.now().millisecondsSinceEpoch,
                'current_progress': 0.0,
              });
            }
          } else {
            skippedExtensions[ext] = (skippedExtensions[ext] ?? 0) + 1;
          }

          // 限流汇报进度: 每 100 个文件，或者有新书时，发送一次进度
          if (totalScanned % 100 == 0) {
            payload.progressPort
                ?.send(ScanProgress(totalScanned, validFilePaths.length));
          }
        }
      }
    } catch (e) {
      errors.add('Error scanning folder: $e');
    }

    return FolderScanResult(
      filePaths: validFilePaths,
      parsedBooks: parsedBooks,
      totalScanned: totalScanned,
      skippedHidden: skippedHidden,
      skippedExtensions: skippedExtensions,
      errors: errors,
    );
  }
}
