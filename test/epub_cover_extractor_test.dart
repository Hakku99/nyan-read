/// Tests for the file-streaming EPUB cover extractor (review #10): the
/// details page no longer reads the whole book into memory — the worker
/// isolate streams the zip and inflates only the cover entry.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nyan_read/modules/bookshelf/epub_cover_extractor.dart';

const String _container = '<?xml version="1.0"?>'
    '<container><rootfiles>'
    '<rootfile full-path="OEBPS/content.opf"/>'
    '</rootfiles></container>';

String _opf({required bool withCover}) => '<?xml version="1.0"?>'
    '<package><manifest>'
    '<item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>'
    '${withCover ? '<item id="cov" href="cover.png" media-type="image/png" properties="cover-image"/>' : ''}'
    '</manifest><spine><itemref idref="ch1"/></spine></package>';

Future<File> _writeEpub(Directory dir, {required bool withCover}) async {
  final archive = Archive();
  void add(String name, List<int> bytes) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('META-INF/container.xml', utf8.encode(_container));
  add('OEBPS/content.opf', utf8.encode(_opf(withCover: withCover)));
  add('OEBPS/ch1.xhtml',
      utf8.encode('<html><body><p>hi</p></body></html>'));
  if (withCover) {
    add('OEBPS/cover.png', img.encodePng(img.Image(width: 8, height: 8)));
  }

  final file = File('${dir.path}/book.epub');
  await file.writeAsBytes(Uint8List.fromList(ZipEncoder().encode(archive)));
  return file;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nyan_cover_test');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('extracts and JPEG-encodes the declared cover from a file path',
      () async {
    final file = await _writeEpub(tempDir, withCover: true);

    final jpeg = await extractEpubCoverAsJpegFromFile(file.path);

    expect(jpeg, isNotNull);
    expect(img.decodeJpg(jpeg!), isNotNull,
        reason: 'output must be a decodable JPEG');
  });

  test('returns null when the book declares no cover', () async {
    final file = await _writeEpub(tempDir, withCover: false);
    expect(await extractEpubCoverAsJpegFromFile(file.path), isNull);
  });

  test('returns null for a missing or unreadable file', () async {
    expect(
        await extractEpubCoverAsJpegFromFile('${tempDir.path}/nope.epub'),
        isNull);
  });
}
