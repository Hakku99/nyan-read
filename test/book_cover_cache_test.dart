/// Tests for BookCoverCache LRU eviction (analysis item #14 / AGENTS §2.4:
/// cover cache ≤ budget with oldest-first eviction).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/utils/book_cover_cache.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nyan_cover_cache');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  File writeCover(String name, int size, DateTime modified) {
    final f = File(path.join(tempDir.path, name));
    f.writeAsBytesSync(List.filled(size, 0xAB));
    f.setLastModifiedSync(modified);
    return f;
  }

  test('does nothing while under budget', () {
    final now = DateTime.now();
    final a = writeCover('a.jpg', 100, now);
    final b = writeCover('b.jpg', 100, now);

    BookCoverCache.evictLruSync(tempDir.path, 1000);

    expect(a.existsSync(), isTrue);
    expect(b.existsSync(), isTrue);
  });

  test('evicts oldest-mtime files first until under budget', () {
    final now = DateTime.now();
    final oldest =
        writeCover('old.jpg', 400, now.subtract(const Duration(days: 3)));
    final middle =
        writeCover('mid.jpg', 400, now.subtract(const Duration(days: 2)));
    final newest = writeCover('new.jpg', 400, now);

    // Budget of 800: must drop exactly the oldest file (total 1200 -> 800).
    BookCoverCache.evictLruSync(tempDir.path, 800);

    expect(oldest.existsSync(), isFalse);
    expect(middle.existsSync(), isTrue);
    expect(newest.existsSync(), isTrue);
  });

  test('missing directory is a no-op', () {
    BookCoverCache.evictLruSync(
        path.join(tempDir.path, 'does-not-exist'), 100);
  });
}
