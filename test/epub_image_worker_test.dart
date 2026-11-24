/// One worker per EPUB path answers many image requests from a single zip.
library;

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/modules/reader/reader_engine/epub/epub_image_worker.dart';
import 'package:path/path.dart' as p;

void main() {
  test('serves several entries, null for missing, and stops cleanly',
      () async {
    final dir = Directory.systemTemp.createTempSync('img_worker_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final archive = Archive()
      ..addFile(ArchiveFile('OEBPS/a.png', 3, [1, 2, 3]))
      ..addFile(ArchiveFile('OEBPS/b.png', 2, [9, 8]));
    final path = p.join(dir.path, 'book.epub');
    File(path).writeAsBytesSync(ZipEncoder().encode(archive));

    final results = await Future.wait([
      EpubImageWorker.extract(path, 'OEBPS/a.png'),
      EpubImageWorker.extract(path, 'OEBPS/b.png'),
      EpubImageWorker.extract(path, 'OEBPS/missing.png'),
      EpubImageWorker.extract(path, ''),
    ]);

    expect(results[0], [1, 2, 3]);
    expect(results[1], [9, 8]);
    expect(results[2], isNull);
    expect(results[3], isNull);

    EpubImageWorker.close(path);
    // A closed worker is replaced by a fresh one on the next request.
    expect(await EpubImageWorker.extract(path, 'OEBPS/a.png'), [1, 2, 3]);
    EpubImageWorker.close(path);
  });

  test('unreadable epub answers null instead of hanging', () async {
    final dir = Directory.systemTemp.createTempSync('img_worker_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'bad.epub');
    File(path).writeAsStringSync('not a zip');

    expect(await EpubImageWorker.extract(path, 'x.png'), isNull);
    EpubImageWorker.close(path);
  });
}
