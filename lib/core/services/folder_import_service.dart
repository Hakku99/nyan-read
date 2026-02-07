import 'dart:io';
import 'package:path/path.dart' as path;

/// Result of a folder import operation
class ImportResult {
  final int successCount;
  final int skippedCount;
  final int failedCount;
  final List<String> errors;
  final List<File> importedFiles;

  ImportResult({
    required this.successCount,
    required this.skippedCount,
    required this.failedCount,
    required this.errors,
    required this.importedFiles,
  });

  int get totalProcessed => successCount + skippedCount + failedCount;
}

/// Service for handling folder import and batch book operations
class FolderImportService {
  static final FolderImportService _instance = FolderImportService._internal();
  static FolderImportService get instance => _instance;

  FolderImportService._internal();

  /// Supported book file extensions
  static const List<String> supportedExtensions = ['.epub', '.txt', '.pdf'];

  /// Scan a folder recursively for supported book files
  ///
  /// [folderPath] - Path to the folder to scan
  /// [includeHidden] - Whether to include hidden files (starting with '.')
  ///
  /// Returns a list of book files found
  Future<List<File>> scanFolder(
    String folderPath, {
    bool includeHidden = false,
  }) async {
    final List<File> books = [];
    final dir = Directory(folderPath);

    if (!await dir.exists()) {
      throw Exception('Folder does not exist: $folderPath');
    }

    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final fileName = path.basename(entity.path);

          // Filter hidden files
          if (!includeHidden && fileName.startsWith('.')) {
            continue;
          }

          // Filter by supported extensions
          final ext = path.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(ext)) {
            books.add(entity);
          }
        }
      }
    } catch (e) {
      throw Exception('Error scanning folder: $e');
    }

    return books;
  }

  /// Check if a file is hidden (starts with '.')
  bool isHiddenFile(File file) {
    final fileName = path.basename(file.path);
    return fileName.startsWith('.');
  }

  /// Get file extension without the dot
  String getFileExtension(File file) {
    return path.extension(file.path).replaceAll('.', '').toLowerCase();
  }

  /// Check if a file is a supported book format
  bool isSupportedFile(File file) {
    final ext = path.extension(file.path).toLowerCase();
    return supportedExtensions.contains(ext);
  }

  /// Group files by extension for statistics
  Map<String, int> groupByExtension(List<File> files) {
    final Map<String, int> groups = {};

    for (final file in files) {
      final ext = getFileExtension(file);
      groups[ext] = (groups[ext] ?? 0) + 1;
    }

    return groups;
  }

  /// Filter out files that already exist in the target directory
  ///
  /// [files] - Files to check
  /// [targetDirectory] - Directory to check against
  ///
  /// Returns a list of files that don't exist in the target directory
  Future<List<File>> filterDuplicates(
    List<File> files,
    Directory targetDirectory,
  ) async {
    final List<File> uniqueFiles = [];

    for (final file in files) {
      final fileName = path.basename(file.path);
      final targetPath = path.join(targetDirectory.path, fileName);
      final targetFile = File(targetPath);

      if (!await targetFile.exists()) {
        uniqueFiles.add(file);
      }
    }

    return uniqueFiles;
  }

  /// Get statistics about a list of files
  Map<String, dynamic> getFileStatistics(List<File> files) {
    final stats = <String, dynamic>{
      'total': files.length,
      'byExtension': groupByExtension(files),
      'hidden': files.where((f) => isHiddenFile(f)).length,
    };

    return stats;
  }
}
