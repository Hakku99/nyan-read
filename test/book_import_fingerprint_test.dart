/// First tests for BookImportFingerprint (BACKLOG test-blindspot item),
/// seeded by the library-folders work: tree-child uris must dedupe cleanly
/// against both themselves and legacy per-file imports of the same content.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/utils/book_import_fingerprint.dart';

void main() {
  group('normalizeLocator', () {
    test('file paths normalize separators and case', () {
      expect(
        BookImportFingerprint.normalizeLocator(
            BookSourceType.filePath, r'C:\Books\..\Books\A.TXT'),
        BookImportFingerprint.normalizeLocator(
            BookSourceType.filePath, r'C:\Books\a.txt'),
      );
    });

    test('content and tree uris are trimmed but otherwise untouched', () {
      const uri =
          'content://com.android.externalstorage.documents/tree/primary%3ABooks/document/primary%3ABooks%2Fa.txt';
      expect(
        BookImportFingerprint.normalizeLocator(
            BookSourceType.androidTreeUri, '  $uri '),
        uri,
      );
      // Percent-encoding must NOT be decoded — the uri is an opaque key.
      expect(
        BookImportFingerprint.normalizeLocator(
            BookSourceType.androidContentUri, uri),
        uri,
      );
    });
  });

  group('computeBytes', () {
    Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

    test('is deterministic for identical content + hint extension', () {
      final a = BookImportFingerprint.computeBytes(bytes('hello book'),
          locatorHint: 'a.txt');
      final b = BookImportFingerprint.computeBytes(bytes('hello book'),
          locatorHint: 'b.txt');
      expect(a, isNotNull);
      // Same ext + same size + same bytes → same signature regardless of
      // name: THIS is what dedupes a tree import against a legacy per-file
      // import of the same book.
      expect(a, b);
    });

    test('differs when content or extension differs', () {
      final base = BookImportFingerprint.computeBytes(bytes('hello book'),
          locatorHint: 'a.txt');
      expect(
          BookImportFingerprint.computeBytes(bytes('another book!'),
              locatorHint: 'a.txt'),
          isNot(base));
      expect(
          BookImportFingerprint.computeBytes(bytes('hello book'),
              locatorHint: 'a.epub'),
          isNot(base));
    });
  });
}
