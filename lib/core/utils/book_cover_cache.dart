import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Disk cache for extracted book covers (AGENTS §2.4: cover cache ≤100 MB
/// with LRU eviction). Keyed by book id; one JPEG per book.
///
/// Lives under the application *cache* directory — deliberately NOT the
/// temporary directory, which our own cache scavenger wipes after 24h, and
/// NOT documents, which iOS backs up to iCloud (covers are re-derivable).
class BookCoverCache {
  BookCoverCache._();

  static const String _dirName = 'covers';
  static const int _maxBytes = 100 * 1024 * 1024;

  static Future<File> _fileFor(String bookId) async {
    final cacheDir = await getApplicationCacheDirectory();
    return File(path.join(cacheDir.path, _dirName, '$bookId.jpg'));
  }

  /// Returns the cached cover JPEG, or null on miss. A hit refreshes the
  /// file's mtime so LRU eviction sees it as recently used.
  static Future<Uint8List?> read(String bookId) async {
    try {
      final file = await _fileFor(bookId);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      // Touch for LRU; failure is harmless (eviction just sees it older).
      try {
        await file.setLastModified(DateTime.now());
      } catch (_) {}
      return bytes;
    } catch (e) {
      debugPrint('[BookCoverCache] read failed: $e');
      return null;
    }
  }

  /// Persists [jpegBytes] for [bookId] and prunes the cache directory back
  /// under the 100 MB budget (oldest-mtime-first, in a helper isolate).
  static Future<void> write(String bookId, Uint8List jpegBytes) async {
    if (jpegBytes.isEmpty) return;
    try {
      final file = await _fileFor(bookId);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(jpegBytes, flush: true);
      final dirPath = file.parent.path;
      await Isolate.run(() => _evictLruSync(dirPath, _maxBytes));
    } catch (e) {
      debugPrint('[BookCoverCache] write failed: $e');
    }
  }

  @visibleForTesting
  static void evictLruSync(String dirPath, int maxBytes) =>
      _evictLruSync(dirPath, maxBytes);

  static void _evictLruSync(String dirPath, int maxBytes) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return;

    final files = dir.listSync().whereType<File>().toList();
    var total = 0;
    final stats = <({File file, int size, DateTime modified})>[];
    for (final f in files) {
      try {
        final s = f.statSync();
        total += s.size;
        stats.add((file: f, size: s.size, modified: s.modified));
      } catch (_) {}
    }
    if (total <= maxBytes) return;

    stats.sort((a, b) => a.modified.compareTo(b.modified));
    for (final entry in stats) {
      if (total <= maxBytes) break;
      try {
        entry.file.deleteSync();
        total -= entry.size;
      } catch (_) {}
    }
  }
}
