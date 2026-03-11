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
        case BookSourceType.androidContentUri:
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
        return BookSourcePlatform.readUriBytes(sourceLocator);
      default:
        throw UnsupportedError('Unsupported source type: $sourceType');
    }
  }

  static Future<PdfCompatibleSource> preparePdfCompatibleSource(Book book) async {
    switch (BookSourceType.normalize(book.sourceType)) {
      case BookSourceType.filePath:
        return PdfCompatibleSource(path: book.sourceLocator, isTemporary: false);
      case BookSourceType.androidContentUri:
        final tempPath = await BookSourcePlatform.copyUriToTempFile(
          book.sourceLocator,
          extension: '.pdf',
        );
        return PdfCompatibleSource(path: tempPath, isTemporary: true);
      default:
        throw UnsupportedError('Unsupported source type: ${book.sourceType}');
    }
  }
}
