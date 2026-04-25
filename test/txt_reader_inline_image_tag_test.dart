import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_reader.dart';

void main() {
  group('TXT inline image tag parsing', () {
    test('parses standalone img tag with quoted src and alt', () {
      final tag = tryParseTxtStandaloneImgTag(
        '<img src="images/pic-1.png" alt="cover image">',
      );

      expect(tag, isNotNull);
      expect(tag!.src, 'images/pic-1.png');
      expect(tag.alt, 'cover image');
    });

    test('parses standalone img tag with unquoted src', () {
      final tag = tryParseTxtStandaloneImgTag('<img src=images/pic-2.jpg>');

      expect(tag, isNotNull);
      expect(tag!.src, 'images/pic-2.jpg');
    });

    test('ignores non-standalone img tag content', () {
      final tag = tryParseTxtStandaloneImgTag(
        'prefix <img src="images/pic-1.png"> suffix',
      );

      expect(tag, isNull);
    });
  });

  group('TXT inline image source resolving', () {
    test('resolves relative img src against txt parent directory', () {
      final book = Book(
        id: 'b1',
        title: 'Book',
        author: 'Author',
        sourceLocator: '/books/novel/book.txt',
        sourceType: BookSourceType.filePath,
        format: 'txt',
      );

      final resolved = resolveTxtImageSourceUri(
        book: book,
        rawSrc: 'images/chapter-1.png',
      );

      expect(resolved, isNotNull);
      expect(resolved!.toString(), 'file:///books/novel/images/chapter-1.png');
    });

    test('returns null for relative src on non-file-path source', () {
      final book = Book(
        id: 'b2',
        title: 'Book',
        author: 'Author',
        sourceLocator: 'content://provider/doc/123',
        sourceType: BookSourceType.androidContentUri,
        format: 'txt',
      );

      final resolved = resolveTxtImageSourceUri(
        book: book,
        rawSrc: 'images/chapter-1.png',
      );

      expect(resolved, isNull);
    });
  });
}
