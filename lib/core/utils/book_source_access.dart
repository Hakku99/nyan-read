import 'dart:io';
import 'dart:typed_data';

import '../models/book.dart';
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
      "This book's source file may have been moved, renamed, deleted, or access has expired. Remove it from your bookshelf and import it again.";

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
        final tempPath = await BookSourcePlatform.copyUriToTempFile(
          book.sourceLocator,
          extension: extension,
        );
        return PdfCompatibleSource(path: tempPath, isTemporary: true);
      default:
        throw UnsupportedError('Unsupported source type: ${book.sourceType}');
    }
  }
}
