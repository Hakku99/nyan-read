import 'dart:io';
import 'package:path/path.dart' as path;

/// Result of a folder scan operation
class FolderScanResult {
  final List<File> files;
  final int totalScanned;
  final int skippedHidden;
  final Map<String, int> skippedExtensions;
  final List<String> errors;

  FolderScanResult({
    required this.files,
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

  /// Scan a folder recursively for supported book files
  ///
  /// [folderPath] - Path to the folder to scan
  /// [includeHidden] - Whether to include hidden files (starting with '.')
  ///
  /// Returns a [FolderScanResult] with found files and statistics
  Future<FolderScanResult> scanFolder(
    String folderPath, {
    bool includeHidden = false,
  }) async {
    final List<File> books = [];
    final Map<String, int> skippedExtensions = {};
    final List<String> errors = [];
    int totalScanned = 0;
    int skippedHidden = 0;

    final dir = Directory(folderPath);

    if (!await dir.exists()) {
      throw Exception('Folder does not exist: $folderPath');
    }

    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalScanned++;
          final fileName = path.basename(entity.path);

          // Filter hidden files
          if (!includeHidden && fileName.startsWith('.')) {
            skippedHidden++;
            continue;
          }

          // Filter by supported extensions
          final ext = path.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(ext)) {
            books.add(entity);
          } else {
            skippedExtensions[ext] = (skippedExtensions[ext] ?? 0) + 1;
          }
        }
      }
    } catch (e) {
      errors.add('Error scanning folder: $e');
    }

    return FolderScanResult(
      files: books,
      totalScanned: totalScanned,
      skippedHidden: skippedHidden,
      skippedExtensions: skippedExtensions,
      errors: errors,
    );
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

  /// Filter out files that already exist in the database (by filename)
  ///
  /// [files] - Files to check
  /// [existingFilenames] - Set of filenames already in the library
  ///
  /// Returns a list of files that are NOT in the existingFilenames set
  List<File> filterDuplicates(
    List<File> files,
    Set<String> existingFilenames,
  ) {
    return files.where((file) {
      final fileName = path.basename(file.path);
      return !existingFilenames.contains(fileName);
    }).toList();
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
