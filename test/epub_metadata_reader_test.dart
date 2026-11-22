/// EPUB import metadata (audit P1 #5): the OPF's dc:title / dc:creator replace
/// the scraped filename and the 'Unknown' author placeholder.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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
    '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">$metadataBody</metadata>'
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

  test('overlong fields are capped', () async {
    final file = await _writeEpub(
        tempDir, '<dc:title>${'x' * 500}</dc:title>');
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
