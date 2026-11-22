/// EPUB import metadata (audit P1 #5): the OPF's dc:title / dc:creator replace
/// the scraped filename and the 'Unknown' author placeholder.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/modules/bookshelf/epub_metadata_reader.dart';

const String _container = '<?xml version="1.0"?>'
    '<container><rootfiles>'
    '<rootfile full-path="OEBPS/content.opf"/>'
    '</rootfiles></container>';

// Real OPFs declare the dc: prefix on <metadata>; the parser must match the
// prefixed elements, not just unprefixed ones.
String _opf(String metadataBody) => '<?xml version="1.0"?>'
    '<package xmlns="http://www.idpf.org/2007/opf" version="3.0">'
    '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/" '
    'xmlns:opf="http://www.idpf.org/2007/opf">$metadataBody</metadata>'
    '<manifest><item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/></manifest>'
    '<spine><itemref idref="ch1"/></spine></package>';

Future<File> _writeEpub(Directory dir, String metadataBody,
    {String name = 'book.epub'}) async {
  final archive = Archive();
  void add(String entry, String text) {
    final bytes = utf8.encode(text);
    archive.addFile(ArchiveFile(entry, bytes.length, bytes));
  }

  add('META-INF/container.xml', _container);
  add('OEBPS/content.opf', _opf(metadataBody));
  add('OEBPS/ch1.xhtml', '<html><body><p>hi</p></body></html>');
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(Uint8List.fromList(ZipEncoder().encode(archive)));
  return file;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nyan_meta_test');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('reads prefixed dc:title and joins multiple dc:creator', () async {
    final file = await _writeEpub(
        tempDir,
        '<dc:title>  The Cat\n  Sat </dc:title>'
        '<dc:creator>Ada Lovelace</dc:creator>'
        '<dc:creator>夏目漱石</dc:creator>');

    final meta = await readEpubMetadataFromFile(file.path);

    expect(meta?.title, 'The Cat Sat');
    expect(meta?.author, 'Ada Lovelace, 夏目漱石');
  });

  test('absent or blank fields come back null so the caller keeps defaults',
      () async {
    final blank = await _writeEpub(tempDir, '<dc:title>   </dc:title>',
        name: 'blank.epub');
    final none = await _writeEpub(tempDir, '', name: 'none.epub');

    expect((await readEpubMetadataFromFile(blank.path))?.title, isNull);
    final meta = await readEpubMetadataFromFile(none.path);
    expect(meta?.title, isNull);
    expect(meta?.author, isNull);
  });

  for (final placeholder in [
    'Untitled',
    ' UNKNOWN ',
    '未命名',
    'urn:uuid:123e4567-e89b-12d3-a456-426614174000',
  ]) {
    test('placeholder title "$placeholder" is ignored, author kept', () async {
      final file = await _writeEpub(tempDir,
          '<dc:title>$placeholder</dc:title><dc:creator>Real Author</dc:creator>');
      final meta = await readEpubMetadataFromFile(file.path);
      expect(meta?.title, isNull);
      expect(meta?.author, 'Real Author');
    });
  }

  test('EPUB3 main title wins over a subtitle listed first', () async {
    final file = await _writeEpub(
        tempDir,
        '<dc:title id="sub">A Subtitle</dc:title>'
        '<dc:title id="main">The Real Title</dc:title>'
        '<meta refines="#sub" property="title-type">subtitle</meta>'
        '<meta refines="#main" property="title-type">main</meta>');
    expect(
        (await readEpubMetadataFromFile(file.path))?.title, 'The Real Title');
  });

  test('untitled-type entries beat typed non-main ones', () async {
    final file = await _writeEpub(
        tempDir,
        '<dc:title id="series">The Series</dc:title>'
        '<dc:title>Plain Title</dc:title>'
        '<meta refines="#series" property="title-type">collection</meta>');
    expect((await readEpubMetadataFromFile(file.path))?.title, 'Plain Title');
  });

  test('non-author creators are dropped (EPUB2 opf:role and EPUB3 refines)',
      () async {
    final file = await _writeEpub(
        tempDir,
        '<dc:creator opf:role="ill">Painter</dc:creator>'
        '<dc:creator id="tr">Translator</dc:creator>'
        '<meta refines="#tr" property="role">trl</meta>'
        '<dc:creator opf:role="aut">Real Author</dc:creator>'
        '<dc:creator>Roleless Co-author</dc:creator>');
    expect((await readEpubMetadataFromFile(file.path))?.author,
        'Real Author, Roleless Co-author');
  });

  test('creators fall back to everyone when none is an author', () async {
    final file = await _writeEpub(
        tempDir, '<dc:creator opf:role="edt">The Editor</dc:creator>');
    expect((await readEpubMetadataFromFile(file.path))?.author, 'The Editor');
  });

  test('cap never splits a surrogate pair', () async {
    // 199 ASCII + one emoji (2 UTF-16 units) straddles a unit-based cut.
    final title = '${'x' * 199}😀tail';
    final file = await _writeEpub(tempDir, '<dc:title>$title</dc:title>');
    final capped = (await readEpubMetadataFromFile(file.path))!.title!;
    expect(capped.runes.length, 200);
    expect(capped.endsWith('😀'), isTrue);
  });

  test('resolveImportedTitleAuthor prefers OPF values, else filename/Unknown',
      () {
    expect(
        resolveImportedTitleAuthor(
            '[Z-Lib] junk (1).epub', (title: 'Real', author: 'Ada')),
        (title: 'Real', author: 'Ada'));
    expect(resolveImportedTitleAuthor('Dune.epub', null),
        (title: 'Dune', author: 'Unknown'));
    // Partial metadata: each field falls back independently.
    expect(resolveImportedTitleAuthor('Dune.epub', (title: null, author: 'F')),
        (title: 'Dune', author: 'F'));
    expect(
        resolveImportedTitleAuthor('Dune.epub', (title: 'Dune!', author: null)),
        (title: 'Dune!', author: 'Unknown'));
  });

  group('library-folder temp copy', () {
    const channel = MethodChannel('com.example.nyan_read/book_source');
    final binding = TestWidgetsFlutterBinding.ensureInitialized();

    tearDown(() {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('is materialized for a tree URI, read, then deleted', () async {
      final temp = await _writeEpub(tempDir, '<dc:title>From Tree</dc:title>',
          name: 'materialized.epub');
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      String? requestedExtension;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        expect(call.method, 'copyUriToTempFile');
        requestedExtension = (call.arguments as Map)['extension'] as String;
        return temp.path;
      });

      final meta = await readEpubMetadataForImport(
        sourceType: BookSourceType.androidTreeUri,
        sourceLocator: 'content://tree/doc',
      );

      expect(meta?.title, 'From Tree');
      expect(requestedExtension, '.epub');
      expect(temp.existsSync(), isFalse, reason: 'temp copy must be deleted');
    });

    test('is deleted even when the copy is not a readable EPUB', () async {
      final temp = File('${tempDir.path}/bad.epub')..writeAsStringSync('nope');
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => temp.path);

      final meta = await readEpubMetadataForImport(
        sourceType: BookSourceType.androidTreeUri,
        sourceLocator: 'content://tree/doc',
      );

      expect(meta, isNull);
      expect(temp.existsSync(), isFalse);
    });

    test('a picker copy is never deleted by the wrapper', () async {
      final copy = await _writeEpub(tempDir, '<dc:title>Keep</dc:title>',
          name: 'picker.epub');
      await readEpubMetadataForImport(
        sourceType: BookSourceType.androidContentUri,
        sourceLocator: 'content://x',
        transientFilePath: copy.path,
      );
      expect(copy.existsSync(), isTrue);
    });
  });

  test('overlong fields are capped', () async {
    final file = await _writeEpub(tempDir, '<dc:title>${'x' * 500}</dc:title>');
    expect((await readEpubMetadataFromFile(file.path))?.title, hasLength(200));
  });

  test('missing or non-EPUB files return null instead of throwing', () async {
    expect(await readEpubMetadataFromFile('${tempDir.path}/nope.epub'), isNull);
    final junk = File('${tempDir.path}/junk.epub')..writeAsStringSync('nope');
    expect(await readEpubMetadataFromFile(junk.path), isNull);
  });

  test('import wrapper reads the file-path source', () async {
    final file = await _writeEpub(tempDir, '<dc:title>From Path</dc:title>');
    final meta = await readEpubMetadataForImport(
      sourceType: BookSourceType.filePath,
      sourceLocator: file.path,
    );
    expect(meta?.title, 'From Path');
  });

  test('import wrapper prefers the picker copy over the source locator',
      () async {
    final copy = await _writeEpub(tempDir, '<dc:title>Picker Copy</dc:title>',
        name: 'copy.epub');
    final meta = await readEpubMetadataForImport(
      sourceType: BookSourceType.androidContentUri,
      sourceLocator: 'content://not/readable',
      transientFilePath: copy.path,
    );
    expect(meta?.title, 'Picker Copy');
  });

  test('import wrapper returns null for an unsupported source type', () async {
    expect(
        await readEpubMetadataForImport(
            sourceType: 'bogus', sourceLocator: 'x'),
        isNull);
  });
}
