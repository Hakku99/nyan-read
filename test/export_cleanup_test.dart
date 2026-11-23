/// Stale export JSON is removed on the next launch regardless of age; other
/// fresh temp files are left alone.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/backup_recovery_service.dart';
import 'package:nyan_read/core/utils/book_cover_cache.dart';
import 'package:path/path.dart' hide equals;

void main() {
  test('scavenger deletes fresh export JSON but keeps other fresh files', () {
    final dir = Directory.systemTemp.createTempSync('scav_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final export = File(join(dir.path, 'nyan_read_export_123.json'))
      ..writeAsStringSync('{}');
    final other = File(join(dir.path, 'other_cache.bin'))
      ..writeAsStringSync('x');

    BackupRecoveryService.cacheCleanupTask(dir.path);

    expect(export.existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
  });

  test('scavenger never ages out the cover cache subdirectory', () {
    final dir = Directory.systemTemp.createTempSync('scav_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory(join(dir.path, BookCoverCache.dirName)).createSync();
    final cover = File(join(dir.path, BookCoverCache.dirName, 'book1.jpg'))
      ..writeAsStringSync('x')
      ..setLastModifiedSync(DateTime.now().subtract(const Duration(days: 3)));
    final stale = File(join(dir.path, 'stale.bin'))
      ..writeAsStringSync('x')
      ..setLastModifiedSync(DateTime.now().subtract(const Duration(days: 3)));

    BackupRecoveryService.cacheCleanupTask(dir.path);

    expect(cover.existsSync(), isTrue);
    expect(stale.existsSync(), isFalse);
  });
}
