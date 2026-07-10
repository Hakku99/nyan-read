import 'package:flutter/painting.dart';
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

  group('TXT inline image provider selection (offline promise)', () {
    test('blocks http and https sources', () {
      // A tracking pixel embedded in a downloaded TXT must never fire a
      // network request (analysis item #3).
      expect(txtImageProviderFor(Uri.parse('http://evil.example/p.png')),
          isNull);
      expect(txtImageProviderFor(Uri.parse('https://evil.example/p.png')),
          isNull);
    });

    test('allows local file sources', () {
      expect(txtImageProviderFor(Uri.parse('file:///books/a.png')),
          isA<FileImage>());
    });

    test('allows inline data URIs', () {
      expect(
        txtImageProviderFor(
            Uri.parse('data:image/png;base64,aGVsbG8=')),
        isA<MemoryImage>(),
      );
    });

    test('rejects unknown schemes', () {
      expect(txtImageProviderFor(Uri.parse('ftp://host/a.png')), isNull);
    });
  });
}
