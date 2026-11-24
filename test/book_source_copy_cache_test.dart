/// SAF sources are copied once per content signature and reused on reopen.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/utils/book_source_access.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late int copies;

  Book book({String? signature = 'sig-1', String locator = 'content://a/1'}) =>
      Book(
        id: 'b',
        title: 't',
        author: 'a',
        format: 'epub',
        sourceLocator: locator,
        sourceType: BookSourceType.androidContentUri,
        contentSignature: signature,
      );

  setUp(() {
    root = Directory.systemTemp.createTempSync('copy_cache_');
    copies = 0;
    BookSourceAccess.cacheRoot = () async => root;
    BookSourceAccess.copyUri = (uri, {required extension}) async {
      copies++;
      final f = File(p.join(root.path, 'tmp_$copies$extension'))
        ..writeAsStringSync('book:$uri');
      return f.path;
    };
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('second open reuses the cached copy and never marks it temporary',
      () async {
    final first = await BookSourceAccess.prepareReadableFile(book(),
        extension: '.epub');
    final second = await BookSourceAccess.prepareReadableFile(book(),
        extension: '.epub');

    expect(copies, 1);
    expect(first.isTemporary, isFalse);
    expect(second.path, first.path);
    expect(File(second.path).readAsStringSync(), 'book:content://a/1');
  });

  test('same signature after relinking to another Uri still hits', () async {
    await BookSourceAccess.prepareReadableFile(book(), extension: '.epub');
    await BookSourceAccess.prepareReadableFile(
        book(locator: 'content://b/9'),
        extension: '.epub');
    expect(copies, 1);
  });

  test('different signature or extension misses', () async {
    await BookSourceAccess.prepareReadableFile(book(), extension: '.epub');
    await BookSourceAccess.prepareReadableFile(book(signature: 'sig-2'),
        extension: '.epub');
    await BookSourceAccess.prepareReadableFile(book(), extension: '.pdf');
    expect(copies, 3);
  });

  test('book without a signature gets a fresh temporary copy each time',
      () async {
    final a = await BookSourceAccess.prepareReadableFile(book(signature: null),
        extension: '.epub');
    final b = await BookSourceAccess.prepareReadableFile(book(signature: null),
        extension: '.epub');
    expect(copies, 2);
    expect(a.isTemporary, isTrue);
    expect(b.isTemporary, isTrue);
  });

  test('empty cached file is treated as a miss', () async {
    final first = await BookSourceAccess.prepareReadableFile(book(),
        extension: '.epub');
    File(first.path).writeAsStringSync('');
    final again = await BookSourceAccess.prepareReadableFile(book(),
        extension: '.epub');
    expect(copies, 2);
    expect(File(again.path).lengthSync(), greaterThan(0));
  });

  group('size cap', () {
    late int originalCap;
    setUp(() => originalCap = BookSourceAccess.copyCacheMaxBytes);
    tearDown(() => BookSourceAccess.copyCacheMaxBytes = originalCap);

    test('a single copy bigger than the cap is kept and still openable',
        () async {
      BookSourceAccess.copyCacheMaxBytes = 1; // every copy is oversized
      final src = await BookSourceAccess.prepareReadableFile(book(),
          extension: '.epub');
      // Give the background prune time to run (it must spare this file).
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(File(src.path).existsSync(), isTrue);
      final again = await BookSourceAccess.prepareReadableFile(book(),
          extension: '.epub');
      expect(copies, 1); // second open is a cache hit, not a re-copy
      expect(again.path, src.path);
    });

    test('opening another book prunes older copies but not the new one',
        () async {
      BookSourceAccess.copyCacheMaxBytes = 1;
      final first = await BookSourceAccess.prepareReadableFile(book(),
          extension: '.epub');
      File(first.path)
          .setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 1)));
      final second = await BookSourceAccess.prepareReadableFile(
          book(signature: 'sig-2'),
          extension: '.epub');

      // Poll: the prune runs in a background isolate.
      for (var i = 0; i < 40 && File(first.path).existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(File(first.path).existsSync(), isFalse);
      expect(File(second.path).existsSync(), isTrue);
    });
  });
}
