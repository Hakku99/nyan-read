// Local repro for folder-import scanning (not part of `flutter test`).
// Run: dart run tool/reproduce_scan.dart
//
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:path/path.dart' as path;

// Simple reproduction of FolderImportService.scanFolder
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

class FolderImportScanner {
  static const List<String> supportedExtensions = ['.epub', '.txt', '.pdf'];

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

    print('Scanning folder: $folderPath');

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
            print('Found supported file: ${entity.path}');
          } else {
            skippedExtensions[ext] = (skippedExtensions[ext] ?? 0) + 1;
            print('Skipping unsupported file: ${entity.path} (ext: $ext)');
          }
        }
      }
    } catch (e) {
      errors.add('Error scanning folder: $e');
      print('Error scanning folder: $e');
    }

    return FolderScanResult(
      files: books,
      totalScanned: totalScanned,
      skippedHidden: skippedHidden,
      skippedExtensions: skippedExtensions,
      errors: errors,
    );
  }
}

void main() async {
  final tempDir = await Directory.systemTemp.createTemp('nyan_read_test_');
  print('Created temp dir: ${tempDir.path}');

  try {
    // Create test files
    await File(path.join(tempDir.path, 'book1.epub')).create();
    await File(path.join(tempDir.path, 'book2.txt')).create();
    await File(path.join(tempDir.path, 'image.png')).create();
    await File(path.join(tempDir.path, '.hidden.epub')).create();

    // Create subfolder
    final subDir = Directory(path.join(tempDir.path, 'subdir'));
    await subDir.create();
    await File(path.join(subDir.path, 'book3.pdf')).create();

    print('Files created. Starting scan...');

    final scanner = FolderImportScanner();
    final result = await scanner.scanFolder(tempDir.path);

    print('Scan complete. Found ${result.files.length} files.');
    print('Total scanned: ${result.totalScanned}');
    print('Skipped hidden: ${result.skippedHidden}');
    print('Skipped extensions: ${result.skippedExtensions}');

    for (final file in result.files) {
      print(' - ${path.basename(file.path)}');
    }

    if (result.files.length != 3) {
      print('TEST FAILED: Expected 3 files (book1.epub, book2.txt, book3.pdf)');
      exit(1);
    } else {
      print('TEST PASSED');
    }
  } catch (e) {
    print('TEST ERROR: $e');
    exit(1);
  } finally {
    // Cleanup
    // await tempDir.delete(recursive: true);
    print('Test finished.');
  }
}
