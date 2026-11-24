import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/book.dart';
import 'book_cover_cache.dart';
import 'book_source_platform.dart';

class PdfCompatibleSource {
  final String path;
  final bool isTemporary;

  const PdfCompatibleSource({
    required this.path,
    required this.isTemporary,
  });
}

class BookSourceAccess {
  static const String unavailableMessage =
      "This book's source file may have been moved, renamed, deleted, or access has expired. Import the same file again to restore it; your progress and notes are kept.";

  static String technicalMessage(Book book) => technicalMessageFor(
        sourceType: book.sourceType,
        sourceLocator: book.sourceLocator,
      );

  static String technicalMessageFor({
    required String sourceType,
    required String sourceLocator,
  }) =>
      'Source [$sourceType][$sourceLocator] is unavailable. It may have been moved, renamed, deleted, or access has expired.';

  static Future<bool> isAvailable(Book book) => isAvailableFor(
        sourceType: book.sourceType,
        sourceLocator: book.sourceLocator,
      );

  static Future<bool> isAvailableFor({
    required String sourceType,
    required String sourceLocator,
  }) async {
    try {
      switch (BookSourceType.normalize(sourceType)) {
        case BookSourceType.filePath:
          final file = File(sourceLocator);
          if (!await file.exists()) return false;
          final stat = await file.stat();
          return stat.type == FileSystemEntityType.file;
        // Tree-child uris read through the same provider machinery as
        // per-file grants — only the grant they inherit differs.
        case BookSourceType.androidContentUri:
        case BookSourceType.androidTreeUri:
          return await BookSourcePlatform.isUriReadable(sourceLocator);
        default:
          return false;
      }
    } catch (_) {
      return false;
    }
  }

  static Future<Uint8List> readBytes(Book book) => readBytesFor(
        sourceType: book.sourceType,
        sourceLocator: book.sourceLocator,
      );

  static Future<Uint8List> readBytesFor({
    required String sourceType,
    required String sourceLocator,
  }) async {
    switch (BookSourceType.normalize(sourceType)) {
      case BookSourceType.filePath:
        return File(sourceLocator).readAsBytes();
      case BookSourceType.androidContentUri:
      case BookSourceType.androidTreeUri:
        return _readUriBytesViaTempFile(sourceLocator);
      default:
        throw UnsupportedError('Unsupported source type: $sourceType');
    }
  }

  /// Reads a `content://` source through a native temp-file copy instead of
  /// `invokeMethod<Uint8List>`: marshalling a whole book across the platform
  /// channel holds two full copies in memory at once (native buffer + Dart
  /// copy) — a large EPUB was a straight OOM face. The native side streams
  /// the Uri to disk; Dart reads one copy and deletes the file immediately.
  static Future<Uint8List> _readUriBytesViaTempFile(
      String sourceLocator) async {
    String? tempPath;
    try {
      tempPath = await BookSourcePlatform.copyUriToTempFile(
        sourceLocator,
        extension: '.tmp',
      );
      return await File(tempPath).readAsBytes();
    } catch (_) {
      // Fallback to the direct channel read so a copy failure (e.g. a
      // provider that rejects openInputStream twice) degrades to the old
      // behavior instead of a dead book.
      return BookSourcePlatform.readUriBytes(sourceLocator);
    } finally {
      if (tempPath != null) {
        try {
          await File(tempPath).delete();
        } catch (_) {
          // Leftovers age out via the 24h cache scavenger.
        }
      }
    }
  }

  static Future<PdfCompatibleSource> preparePdfCompatibleSource(Book book) async {
    return prepareReadableFile(book, extension: '.pdf');
  }

  /// Resolves [book] to a plain filesystem path a helper isolate can read
  /// directly (dart:io works off the main isolate; platform channels do
  /// not). `content://` sources are materialized to a temp file — callers
  /// MUST delete it when [PdfCompatibleSource.isTemporary] is true.
  ///
  /// This is the memory-lean way to feed a parser isolate: the book bytes
  /// never exist on the main isolate at all, instead of being read here and
  /// then copied again across the isolate boundary.
  static Future<PdfCompatibleSource> prepareReadableFile(
    Book book, {
    required String extension,
  }) async {
    switch (BookSourceType.normalize(book.sourceType)) {
      case BookSourceType.filePath:
        return PdfCompatibleSource(path: book.sourceLocator, isTemporary: false);
      case BookSourceType.androidContentUri:
      case BookSourceType.androidTreeUri:
        return _prepareUriSource(book, extension);
      default:
        throw UnsupportedError('Unsupported source type: ${book.sourceType}');
    }
  }

  /// Directory (under the app cache dir) holding reusable SAF copies. The
  /// cache scavenger must skip it (it has its own LRU cap), same as `covers/`.
  static const String copyCacheDirName = 'book_copies';

  @visibleForTesting
  static int copyCacheMaxBytes = 500 * 1024 * 1024;

  @visibleForTesting
  static Future<String> Function(String uri, {required String extension})
      copyUri = BookSourcePlatform.copyUriToTempFile;

  @visibleForTesting
  static Future<Directory> Function() cacheRoot = getApplicationCacheDirectory;

  static String _cacheKey(String? signature) =>
      signature == null ? '' : signature.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// Deletes the cached copies of books that are gone from the shelf. Callers
  /// must pass only signatures no remaining book shares (duplicates by
  /// signature are deduped at import, but a sampled-signature collision could
  /// still exist). Best-effort: a missed copy is LRU-evicted later.
  static Future<void> removeCachedCopies(Iterable<String?> signatures) async {
    final keys = {for (final s in signatures) _cacheKey(s)}..remove('');
    if (keys.isEmpty) return;
    await _deleteCopies(keys.contains);
  }

  /// Deletes every cached copy whose signature is not in [liveSignatures].
  /// Reclaims copies orphaned by a kill between a book's delete and its copy
  /// removal, and by deletes made before copies were reclaimed at all. Run
  /// with the full shelf (public and private) or live copies are lost; that
  /// only costs one re-copy, never data.
  static Future<void> sweepOrphanCopies(Iterable<String?> liveSignatures) {
    final live = {for (final s in liveSignatures) _cacheKey(s)};
    return _deleteCopies((key) => !live.contains(key));
  }

  static Future<void> _deleteCopies(bool Function(String key) shouldDelete) async {
    try {
      final dir = Directory(p.join((await cacheRoot()).path, copyCacheDirName));
      if (!await dir.exists()) return;
      // Collect first: deleting while the listing is open can skip entries.
      final matches = [
        for (final entity in await dir.list().toList())
          if (entity is File && shouldDelete(p.basenameWithoutExtension(entity.path)))
            entity,
      ];
      for (final file in matches) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint('[BookSourceAccess] copy delete failed: ${e.runtimeType}');
        }
      }
    } catch (e) {
      debugPrint('[BookSourceAccess] copy cache removal failed: ${e.runtimeType}');
    }
  }

  /// Keyed by content signature, not locator: the signature is what the book
  /// IS, and it survives relinking (N2) to a different Uri. A source replaced
  /// in place with different bytes keeps serving the old copy until evicted —
  /// acceptable, since progress and anchors are tied to the imported content.
  /// Books without a signature (legacy, not yet backfilled) are never cached.
  static Future<PdfCompatibleSource> _prepareUriSource(
    Book book,
    String extension,
  ) async {
    final safeSignature = _cacheKey(book.contentSignature);
    if (safeSignature.isEmpty) {
      final tempPath = await copyUri(book.sourceLocator, extension: extension);
      return PdfCompatibleSource(path: tempPath, isTemporary: true);
    }

    final dir = p.join((await cacheRoot()).path, copyCacheDirName);
    final cached = File(p.join(dir, '$safeSignature$extension'));
    try {
      if (await cached.exists() && await cached.length() > 0) {
        // Touch for LRU; failure only makes the entry look older.
        try {
          await cached.setLastModified(DateTime.now());
        } catch (_) {}
        return PdfCompatibleSource(path: cached.path, isTemporary: false);
      }
    } catch (e) {
      debugPrint('[BookSourceAccess] copy cache read failed: ${e.runtimeType}');
    }

    final tempPath = await copyUri(book.sourceLocator, extension: extension);
    try {
      await Directory(dir).create(recursive: true);
      // rename is atomic on one filesystem (both live under the Android
      // cacheDir), so a reader never sees a half-written cache entry.
      await File(tempPath).rename(cached.path);
      final max = copyCacheMaxBytes;
      final keep = cached.path;
      // keepPath: the prune must not delete the copy being handed out, or a
      // book larger than the cap would vanish before it is opened.
      unawaited(Isolate.run(
              () => BookCoverCache.evictLruSync(dir, max, keepPath: keep))
          .catchError((Object _) {})); // best-effort; next open prunes again
      return PdfCompatibleSource(path: cached.path, isTemporary: false);
    } catch (e) {
      debugPrint('[BookSourceAccess] copy cache write failed: ${e.runtimeType}');
      return PdfCompatibleSource(path: tempPath, isTemporary: true);
    }
  }
}
