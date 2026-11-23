import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../models/book.dart';
import '../services/database_service.dart';
import 'book_source_access.dart';
import 'book_source_platform.dart';

/// Where an already-imported book currently reads from.
class BookSourceRef {
  final String bookId;
  final String sourceType;
  final String sourceLocator;

  const BookSourceRef({
    required this.bookId,
    required this.sourceType,
    required this.sourceLocator,
  });
}

/// Mutable per-batch copy of [BookImportDedupIndex.booksBySignature]; the
/// lists are copied too so a batch never edits the index it was built from.
Map<String, List<BookSourceRef>> copyBooksBySignature(
  Map<String, List<BookSourceRef>> source,
) =>
    {for (final e in source.entries) e.key: [...e.value]};

class BookImportDedupIndex {
  final Set<String> signatures;
  final Set<String> normalizedLocators;

  /// Signature → every book carrying it, so a duplicate hit can be traced back
  /// to the books whose source may need re-linking (several books can share a
  /// signature, e.g. after a restore).
  final Map<String, List<BookSourceRef>> booksBySignature;

  const BookImportDedupIndex({
    required this.signatures,
    required this.normalizedLocators,
    this.booksBySignature = const {},
  });
}

class BookImportFingerprint {
  static const int _sampleBytes = 64 * 1024;

  /// Builds a dedup index for the import flow.
  ///
  /// When [computeMissing] is false (the default), only rows that already have a
  /// stored `content_signature` are indexed — avoiding per-file SHA-256 I/O on
  /// the UI-critical import path. Legacy books without a signature are picked up
  /// by [SignatureBackfillService] in the background.
  static Future<BookImportDedupIndex> buildExistingIndex(
    DatabaseService db, {
    bool computeMissing = false,
  }) async {
    final rows = await db.getBookImportEntries();
    final signatures = <String>{};
    final normalizedLocators = <String>{};
    final booksBySignature = <String, List<BookSourceRef>>{};

    for (final row in rows) {
      final bookId = row['id'] as String?;
      final sourceLocator = row['file_path'] as String?;
      final sourceType = BookSourceType.normalize(row['source_type'] as String?);
      final existingSignature = row['content_signature'] as String?;

      if (sourceLocator == null || sourceLocator.isEmpty) {
        continue;
      }

      normalizedLocators.add(normalizeLocator(sourceType, sourceLocator));

      if (existingSignature != null && existingSignature.isNotEmpty) {
        signatures.add(existingSignature);
        if (bookId != null && bookId.isNotEmpty) {
          booksBySignature.putIfAbsent(existingSignature, () => []).add(
                BookSourceRef(
                  bookId: bookId,
                  sourceType: sourceType,
                  sourceLocator: sourceLocator,
                ),
              );
        }
        continue;
      }

      if (!computeMissing) continue;

      // Slow path: compute and backfill inline (only used by SignatureBackfillService).
      final computedSignature = await computeForSource(
        sourceType: sourceType,
        sourceLocator: sourceLocator,
        locatorHint: sourceLocator,
      );
      if (computedSignature != null) {
        signatures.add(computedSignature);
        if (bookId != null && bookId.isNotEmpty) {
          await db.updateBookContentSignature(bookId, computedSignature);
        }
      }
    }

    return BookImportDedupIndex(
      signatures: signatures,
      normalizedLocators: normalizedLocators,
      booksBySignature: booksBySignature,
    );
  }

  /// Re-points ONE book among [candidates] (the books sharing a signature hit)
  /// at the freshly picked source: the first whose current source is
  /// unreadable, and only when the new source is readable. A readable old
  /// source is never replaced, so a sampled-signature collision between two
  /// different files cannot hijack a healthy book. Progress, bookmarks,
  /// highlights and privacy are untouched (same book id).
  /// Returns the candidate that was re-linked, or null when none was.
  static Future<BookSourceRef?> relinkIfStale(
    DatabaseService db, {
    required Iterable<BookSourceRef> candidates,
    required String newSourceType,
    required String newSourceLocator,
    required String newStorageType,
    Future<bool> Function({
      required String sourceType,
      required String sourceLocator,
    }) isAvailable = BookSourceAccess.isAvailableFor,
  }) async {
    if (candidates.isEmpty) return null;
    if (!await isAvailable(
      sourceType: newSourceType,
      sourceLocator: newSourceLocator,
    )) {
      return null;
    }
    for (final existing in candidates) {
      if (await isAvailable(
        sourceType: existing.sourceType,
        sourceLocator: existing.sourceLocator,
      )) {
        continue;
      }
      await db.relinkBookSource(
        existing.bookId,
        locator: newSourceLocator,
        sourceType: newSourceType,
        storageType: newStorageType,
      );
      return existing;
    }
    return null;
  }

  /// Returns books that are missing a content signature, for background backfill.
  static Future<List<Map<String, dynamic>>> fetchLegacyBooksNeedingSignature(
    DatabaseService db,
  ) async {
    final rows = await db.getBookImportEntries();
    return rows.where((row) {
      final sig = row['content_signature'] as String?;
      final loc = row['file_path'] as String?;
      return (sig == null || sig.isEmpty) && (loc != null && loc.isNotEmpty);
    }).toList();
  }

  static Future<String?> computeForSource({
    required String sourceType,
    required String sourceLocator,
    required String locatorHint,
    String? transientFilePath,
  }) async {
    try {
      if (transientFilePath != null && transientFilePath.isNotEmpty) {
        return compute(File(transientFilePath), locatorHint: locatorHint);
      }

      if (BookSourceType.normalize(sourceType) == BookSourceType.filePath) {
        return compute(File(sourceLocator), locatorHint: locatorHint);
      }

      // content/tree URI: ask the provider for just size + head + tail and
      // hash those with the same _buildSignature as every other branch, so the
      // signature equals the one the whole-file branch below produces. Null
      // (stale APK, no random access, bad reply) falls through to it.
      final sample = await BookSourcePlatform.sampleUri(
        sourceLocator,
        sampleBytes: _sampleBytes,
      );
      if (sample != null) {
        return _buildSignature(
            locatorHint, sample.size, sample.head, sample.tail);
      }

      final bytes = await BookSourceAccess.readBytesFor(
        sourceType: sourceType,
        sourceLocator: sourceLocator,
      );
      return computeBytes(bytes, locatorHint: locatorHint);
    } catch (e) {
      debugPrint('fingerprint failed: ${e.runtimeType}');
      return null;
    }
  }

  static Future<String?> compute(File file, {String? locatorHint}) async {
    if (!await file.exists()) return null;

    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) return null;

    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final sample = await _readSampleAsync(raf, stat.size);
      return _buildSignature(
        locatorHint ?? file.path,
        stat.size,
        sample.prefix,
        sample.suffix,
      );
    } catch (_) {
      return null;
    } finally {
      await raf?.close();
    }
  }

  static String? computeSync(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final stat = file.statSync();
    if (stat.type != FileSystemEntityType.file) return null;

    RandomAccessFile? raf;
    try {
      raf = file.openSync();
      final sample = _readSampleSync(raf, stat.size);
      return _buildSignature(file.path, stat.size, sample.prefix, sample.suffix);
    } catch (_) {
      return null;
    } finally {
      raf?.closeSync();
    }
  }

  static String? computeBytes(Uint8List bytes, {required String locatorHint}) {
    try {
      final prefixLength = math.min(bytes.length, _sampleBytes);
      final prefix = bytes.sublist(0, prefixLength);
      final suffix = bytes.length > _sampleBytes
          ? bytes.sublist(bytes.length - _sampleBytes)
          : <int>[];
      return _buildSignature(locatorHint, bytes.length, prefix, suffix);
    } catch (_) {
      return null;
    }
  }

  static String normalizeLocator(String sourceType, String sourceLocator) {
    if (BookSourceType.normalize(sourceType) == BookSourceType.filePath) {
      return path.normalize(sourceLocator).toLowerCase();
    }
    return sourceLocator.trim();
  }

  static String _buildSignature(
    String locatorHint,
    int fileSize,
    List<int> prefix,
    List<int> suffix,
  ) {
    final ext = path.extension(locatorHint).toLowerCase();
    final header = utf8.encode('nyan-read-v1|$ext|$fileSize|');
    // Feed each buffer directly rather than spreading prefix+suffix into a
    // single ~130 KB List<int>. The spread boxes every byte individually and
    // allocates a full heap list — for many files in a loop that blocks the
    // main isolate long enough to delay vsync and stall the entrance animation.
    final out = _DigestSink();
    sha256.startChunkedConversion(out)
      ..add(header)
      ..add(prefix)
      ..add(suffix)
      ..close();
    return out.value.toString();
  }

  static Future<_Sample> _readSampleAsync(RandomAccessFile raf, int fileSize) async {
    final prefixLength = math.min(fileSize, _sampleBytes);
    final prefix = await raf.read(prefixLength);

    List<int> suffix = const [];
    if (fileSize > _sampleBytes) {
      final suffixOffset = math.max(0, fileSize - _sampleBytes);
      await raf.setPosition(suffixOffset);
      suffix = await raf.read(math.min(_sampleBytes, fileSize));
    }

    return _Sample(prefix: prefix, suffix: suffix);
  }

  static _Sample _readSampleSync(RandomAccessFile raf, int fileSize) {
    final prefixLength = math.min(fileSize, _sampleBytes);
    final prefix = raf.readSync(prefixLength);

    List<int> suffix = const [];
    if (fileSize > _sampleBytes) {
      final suffixOffset = math.max(0, fileSize - _sampleBytes);
      raf.setPositionSync(suffixOffset);
      suffix = raf.readSync(math.min(_sampleBytes, fileSize));
    }

    return _Sample(prefix: prefix, suffix: suffix);
  }
}

class _Sample {
  final List<int> prefix;
  final List<int> suffix;

  const _Sample({required this.prefix, required this.suffix});
}

/// Minimal [Sink] that captures the single [Digest] emitted by
/// [sha256.startChunkedConversion] so callers avoid [AccumulatorSink]'s
/// list allocation when only one event is expected.
class _DigestSink implements Sink<Digest> {
  Digest? _value;
  Digest get value => _value!;

  @override
  void add(Digest data) => _value = data;

  @override
  void close() {}
}
