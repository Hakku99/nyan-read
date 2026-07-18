/// Golden tests for the self-hosted EPUB parse pipeline (§3.5 protected
/// surface):
///   1. Paragraph enumeration (linearizer) is locked — persisted positions
///      address paragraphs by absolute flat index (§3.6).
///   2. Anchored chapters resolve to ABSOLUTE flat indexes via the id →
///      paragraph map.
///   3. The own package parser (P3c, replaced epubx) reads container/OPF/
///      NCX/nav structures and tolerates real-world malformations
///      (backslash hrefs, percent-encoding, missing files).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/modules/reader/reader_engine/epub/epub_package_parser.dart';
import 'package:nyan_read/modules/reader/reader_engine/epub/epub_parse_helpers.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';

String _html(List<String> bodyElements) =>
    '<html><head></head><body>${bodyElements.join()}</body></html>';

EpubChapterSource _chapter({
  required String title,
  required String fileName,
  required String html,
  String? anchor,
}) {
  return EpubChapterSource(
    title: title,
    contentFileName: fileName,
    anchor: anchor,
    readHtml: () async => html.isEmpty ? null : html,
  );
}

void main() {
  group('paragraph walk golden', () {
    test('plain multi-file book: cumulative start indexes, exact count',
        () async {
      final file1 = _html(['<p>a</p>', '<p>b</p>', '<p>c</p>']);
      final file2 = _html(['<p>d</p>', '<p>e</p>']);

      final result = await computeEpubParseResultFromSources([
        _chapter(title: 'One', fileName: 'ch1.xhtml', html: file1),
        _chapter(title: 'Two', fileName: 'ch2.xhtml', html: file2),
      ]);

      expect(result.paragraphCount, 5);
      expect(result.chapterStartIndexes, [0, 3]);
    });

    test('anchored chapters in a shared file resolve to absolute indexes',
        () async {
      // The classic "one HTML file, many chapters via anchors" layout.
      final file1 = _html(['<p>a</p>', '<p>b</p>', '<p>c</p>']);
      final file2 = _html([
        '<p>intro</p>',
        '<p>more</p>',
        '<h2 id="sec2">Two</h2>',
        '<h2 id="sec3">Three</h2>',
      ]);

      final result = await computeEpubParseResultFromSources([
        _chapter(title: 'One', fileName: 'ch1.xhtml', html: file1),
        _chapter(
            title: 'Two', fileName: 'body.xhtml', html: file2, anchor: 'sec2'),
        _chapter(
            title: 'Three',
            fileName: 'body.xhtml',
            html: file2,
            anchor: 'sec3'),
      ]);

      expect(result.paragraphCount, 7);
      expect(result.chapterStartIndexes, [0, 5, 6]);
    });

    test('missing anchor falls back to the start of its own file', () async {
      final result = await computeEpubParseResultFromSources([
        _chapter(
            title: 'One',
            fileName: 'ch1.xhtml',
            html: _html(['<p>a</p>', '<p>b</p>'])),
        _chapter(
            title: 'Two',
            fileName: 'ch2.xhtml',
            html: _html(['<p>c</p>', '<p>d</p>', '<p>e</p>']),
            anchor: 'nope'),
      ]);

      expect(result.paragraphCount, 5);
      expect(result.chapterStartIndexes, [0, 2]);
    });

    test('navigation-only chapter without HTML contributes zero paragraphs',
        () async {
      final result = await computeEpubParseResultFromSources([
        _chapter(title: 'Cover', fileName: 'nav.xhtml', html: ''),
        _chapter(
            title: 'One', fileName: 'ch1.xhtml', html: _html(['<p>a</p>'])),
      ]);

      expect(result.paragraphCount, 1);
      expect(result.chapterStartIndexes, [0, 0]);
    });
  });

  group('paragraph content extraction', () {
    String contentAt(EpubParseResult r, int i) {
      final start = r.paragraphRanges[i * 2];
      final end = r.paragraphRanges[i * 2 + 1];
      return utf8.decode(r.paragraphBytes.sublist(start, end));
    }

    test('content arrays are structurally 1:1 with paragraphCount', () async {
      final result = await computeEpubParseResultFromSources([
        _chapter(
            title: 'One',
            fileName: 'ch1.xhtml',
            // The empty <p></p> is dropped by the linearizer — blank
            // structural elements must not become blank screen space.
            html: _html(['<p>a</p>', '<h2>b</h2>', '<p></p>'])),
        _chapter(
            title: 'Two', fileName: 'ch2.xhtml', html: _html(['<p>c</p>'])),
      ]);

      expect(result.paragraphCount, 3);
      expect(result.paragraphRanges.length, result.paragraphCount * 2);
      expect(result.paragraphKinds.length, result.paragraphCount);
    });

    test('raw text nodes between <br>s become real paragraphs (LN layout)',
        () async {
      // The DanMachi-style transcription layout that broke the upstream
      // element-only walk: prose lives in TEXT NODES separated by <br/>,
      // inside one big content div.
      final result = await computeEpubParseResultFromSources([
        _chapter(
            title: 'One',
            fileName: 'ch1.xhtml',
            html: _html([
              '<div class="content">line one<br/><br/>'
                  'line two<br/>line three</div>',
            ])),
      ]);

      expect(result.paragraphCount, 3);
      expect(contentAt(result, 0), 'line one');
      expect(contentAt(result, 1), 'line two');
      expect(contentAt(result, 2), 'line three');
    });

    test('text paragraphs collapse whitespace runs like a renderer', () async {
      final result = await computeEpubParseResultFromSources([
        _chapter(
            title: 'One',
            fileName: 'ch1.xhtml',
            html: _html(['<p>  hello\n   world  </p>'])),
      ]);

      expect(contentAt(result, 0), 'hello world');
      expect(result.paragraphKinds[0], EpubParagraphKind.text);
    });

    test('h1-h6 text is tagged with the heading kind (P2 styling)', () async {
      final result = await computeEpubParseResultFromSources([
        _chapter(
            title: 'One',
            fileName: 'ch1.xhtml',
            html: _html([
              '<h2>Chapter Title</h2>',
              '<p>body text</p>',
              '<div><h3><span>Nested</span> Heading</h3></div>',
            ])),
      ]);

      expect(result.paragraphCount, 3);
      expect(result.paragraphKinds[0], EpubParagraphKind.heading);
      expect(contentAt(result, 0), 'Chapter Title');
      expect(result.paragraphKinds[1], EpubParagraphKind.text);
      expect(result.paragraphKinds[2], EpubParagraphKind.heading);
      expect(contentAt(result, 2), 'Nested Heading');
    });

    test('image-only elements become image paragraphs carrying the src',
        () async {
      final result = await computeEpubParseResultFromSources([
        _chapter(
            title: 'One',
            fileName: 'ch1.xhtml',
            html: _html([
              '<p>before</p>',
              '<img src="../images/fig1.png" alt="figure">',
              '<div><img src="pics/fig2.jpg"></div>',
            ])),
      ]);

      expect(result.paragraphCount, 3);
      expect(result.paragraphKinds[0], EpubParagraphKind.text);
      expect(result.paragraphKinds[1], EpubParagraphKind.image);
      expect(contentAt(result, 1), '../images/fig1.png');
      expect(result.paragraphKinds[2], EpubParagraphKind.image);
      expect(contentAt(result, 2), 'pics/fig2.jpg');
    });

    test('mixed text + inline image emits both paragraphs', () async {
      final result = await computeEpubParseResultFromSources([
        _chapter(
            title: 'One',
            fileName: 'ch1.xhtml',
            html: _html(['<p>caption text<img src="pics/fig.png"/></p>'])),
      ]);

      expect(result.paragraphCount, 2);
      expect(result.paragraphKinds[0], EpubParagraphKind.text);
      expect(result.paragraphKinds[1], EpubParagraphKind.image);
    });

    test('CJK text round-trips through the UTF-8 byte store', () async {
      final result = await computeEpubParseResultFromSources([
        _chapter(
            title: 'One',
            fileName: 'ch1.xhtml',
            html: _html(['<p>第一章：起点。</p>'])),
      ]);

      expect(contentAt(result, 0), '第一章：起点。');
    });
  });

  group('package parser (own container/OPF/NCX, P3c)', () {
    Uint8List buildEpubZip({
      String tocHrefSeparator = '/',
      bool includeNcx = true,
      bool epub3Cover = false,
    }) {
      const container = '''
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
      final opf = '''
<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata>
    ${epub3Cover ? '' : '<meta name="cover" content="cover-img"/>'}
  </metadata>
  <manifest>
    <item id="ch1" href="Text/ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="Text/ch2.xhtml" media-type="application/xhtml+xml"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="cover-img" href="Images/cover.jpg" media-type="image/jpeg"${epub3Cover ? ' properties="cover-image"' : ''}/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>''';
      final sep = tocHrefSeparator;
      final ncx = '''
<?xml version="1.0"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <navMap>
    <navPoint id="n1"><navLabel><text>第一章</text></navLabel>
      <content src="Text${sep}ch1.xhtml"/>
      <navPoint id="n1a"><navLabel><text>小节</text></navLabel>
        <content src="Text${sep}ch1.xhtml#sec1"/>
      </navPoint>
    </navPoint>
    <navPoint id="n2"><navLabel><text>第二章</text></navLabel>
      <content src="Text${sep}ch2.xhtml"/>
    </navPoint>
  </navMap>
</ncx>''';
      final ch1 = _html([
        '<p>alpha</p>',
        '<h2 id="sec1">Section</h2>',
        '<p>beta</p>',
      ]);
      final ch2 = _html(['<p>gamma</p>']);

      final archive = Archive();
      void add(String name, String content) {
        final bytes = utf8.encode(content);
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }

      add('META-INF/container.xml', container);
      add('OEBPS/content.opf', opf);
      if (includeNcx) add('OEBPS/toc.ncx', ncx);
      add('OEBPS/Text/ch1.xhtml', ch1);
      add('OEBPS/Text/ch2.xhtml', ch2);
      archive.addFile(ArchiveFile('OEBPS/Images/cover.jpg', 3, [9, 9, 9]));
      return Uint8List.fromList(ZipEncoder().encode(archive));
    }

    test('parses container → OPF → NCX and resolves hrefs', () async {
      final package = parseEpubPackage(buildEpubZip());

      expect(package.toc.length, 2);
      expect(package.toc[0].title, '第一章');
      expect(package.toc[0].fileName, 'OEBPS/Text/ch1.xhtml');
      expect(package.toc[0].children.single.anchor, 'sec1');
      expect(package.coverPath, 'OEBPS/Images/cover.jpg');
      expect(package.spinePaths,
          ['OEBPS/Text/ch1.xhtml', 'OEBPS/Text/ch2.xhtml']);

      final result = await computeEpubParseResultForPackage(package);
      // Flattened chapters: 第一章, 小节(anchor sec1), 第二章.
      expect(result.paragraphCount, 4); // alpha, Section, beta, gamma
      expect(result.chapterStartIndexes, [0, 1, 3]);
    });

    test('tolerates backslash TOC hrefs (Windows-authored books)', () async {
      final package = parseEpubPackage(buildEpubZip(tocHrefSeparator: r'\'));

      expect(package.toc[0].fileName, 'OEBPS/Text/ch1.xhtml');
      final result = await computeEpubParseResultForPackage(package);
      expect(result.paragraphCount, 4);
    });

    test('falls back to spine order when no TOC exists', () async {
      final package = parseEpubPackage(buildEpubZip(includeNcx: false));

      expect(package.toc.length, 2);
      expect(package.toc[0].title, isNull);
      expect(package.toc[0].fileName, 'OEBPS/Text/ch1.xhtml');
    });

    test('EPUB3 cover-image property wins over EPUB2 meta', () async {
      final package = parseEpubPackage(buildEpubZip(epub3Cover: true));
      expect(package.coverPath, 'OEBPS/Images/cover.jpg');
    });

    test('non-zip bytes throw FormatException', () {
      expect(() => parseEpubPackage(Uint8List.fromList([1, 2, 3])),
          throwsFormatException);
    });
  });

  group('image resource extraction', () {
    Uint8List zipWith(Map<String, List<int>> entries) {
      final archive = Archive();
      entries.forEach((name, bytes) {
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      });
      return Uint8List.fromList(ZipEncoder().encode(archive));
    }

    test('matches relative hrefs against nested archive paths', () async {
      final zip = zipWith({
        'OEBPS/images/fig1.png': [1, 2, 3],
        'OEBPS/text/ch1.xhtml': [9],
      });

      expect(extractEpubImageBytes(zip, '../images/fig1.png'), [1, 2, 3]);
      expect(extractEpubImageBytes(zip, 'images/fig1.png'), [1, 2, 3]);
      expect(extractEpubImageBytes(zip, 'fig1.png'), [1, 2, 3]);
    });

    test('returns null for missing resources and junk input', () async {
      final zip = zipWith({
        'OEBPS/images/fig1.png': [1]
      });

      expect(extractEpubImageBytes(zip, 'nope.png'), isNull);
      expect(extractEpubImageBytes(zip, ''), isNull);
      expect(extractEpubImageBytes(Uint8List.fromList([0, 1, 2]), 'x.png'),
          isNull);
    });

    test('file-streaming variant inflates only the requested entry',
        () async {
      final zip = zipWith({
        'OEBPS/Images/fig1.png': [7, 8, 9],
        'OEBPS/Text/ch1.xhtml': [1],
      });
      final dir = await Directory.systemTemp.createTemp('nyan_epub_zip');
      addTearDown(() async {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      });
      final file = File('${dir.path}/book.epub');
      await file.writeAsBytes(zip);

      expect(extractEpubImageBytesFromFile(file.path, '../Images/fig1.png'),
          [7, 8, 9]);
      expect(extractEpubImageBytesFromFile(file.path, 'missing.png'), isNull);
      expect(extractEpubImageBytesFromFile('${dir.path}/nope.epub', 'x.png'),
          isNull);
    });
  });

  group('position migration (legacy CFI+index → index-only)', () {
    test('legacy dual-format payload restores through paragraphIndex', () {
      const legacyJson =
          '{"cfi":"epubcfi(/6/8[chap02]!/4/2/14)","paragraphIndex":42}';
      final position = ReadingPosition.fromJson('epub', legacyJson);

      expect(position.paragraphIndex, 42);
      expect(position.hasLocation, isTrue);
    });

    test('new index-only payload round-trips without a cfi field', () {
      final json = const ReadingPosition(paragraphIndex: 7).toJson();

      expect(json, isNot(contains('cfi')));
      final restored = ReadingPosition.fromJson('epub', json);
      expect(restored.paragraphIndex, 7);
      expect(restored.hasLocation, isTrue);
    });

    test('viewport edges round-trip for sub-paragraph restore precision', () {
      final json = const ReadingPosition(
        paragraphIndex: 7,
        paragraphLeadingEdge: -0.25,
        paragraphTrailingEdge: 0.4,
      ).toJson();

      final restored = ReadingPosition.fromJson('epub', json);
      expect(restored.paragraphLeadingEdge, -0.25);
      expect(restored.paragraphTrailingEdge, 0.4);
    });

    test('enumVersion marker round-trips; absent in legacy payloads', () {
      final json = const ReadingPosition(
        paragraphIndex: 7,
        enumVersion: kEpubEnumerationVersion,
      ).toJson();
      expect(ReadingPosition.fromJson('epub', json).enumVersion,
          kEpubEnumerationVersion);

      // Legacy payloads (pre spine-primary) have no marker.
      final legacy =
          ReadingPosition.fromJson('epub', '{"paragraphIndex":42}');
      expect(legacy.enumVersion, isNull);
      expect(legacy.paragraphIndex, 42);
    });
  });

  // Golden lock for the spine-primary enumeration (review #6/#7, §3.5
  // approved 2026-07-18). The TOC-complete equivalence case lives in the
  // package-parser group above ([0, 1, 3] / count 4 must never move).
  group('spine-primary enumeration (review #6/#7)', () {
    Archive archiveWithFiles(Map<String, String> files) {
      final archive = Archive();
      files.forEach((name, content) {
        final bytes = utf8.encode(content);
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      });
      return archive;
    }

    String contentAt(EpubParseResult r, int i) {
      final start = r.paragraphRanges[i * 2];
      final end = r.paragraphRanges[i * 2 + 1];
      return utf8.decode(r.paragraphBytes.sublist(start, end));
    }

    EpubTocEntry entry(
      String? title,
      String? file, {
      String? anchor,
      List<EpubTocEntry> children = const [],
    }) {
      return EpubTocEntry(
          title: title, fileName: file, anchor: anchor, children: children);
    }

    test('spine files missing from the TOC are rendered in spine order',
        () async {
      // "hidden.xhtml" is in the spine but absent from the TOC — the old
      // TOC-driven walk silently dropped its prose.
      final package = EpubPackage(
        archive: archiveWithFiles({
          'ch1.xhtml': _html(['<p>one</p>']),
          'hidden.xhtml': _html(['<p>hidden prose</p>']),
          'ch2.xhtml': _html(['<p>two</p>']),
        }),
        toc: [entry('One', 'ch1.xhtml'), entry('Two', 'ch2.xhtml')],
        spinePaths: const ['ch1.xhtml', 'hidden.xhtml', 'ch2.xhtml'],
        coverPath: null,
      );

      final result = await computeEpubParseResultForPackage(package);

      expect(result.paragraphCount, 3);
      expect(contentAt(result, 0), 'one');
      expect(contentAt(result, 1), 'hidden prose');
      expect(contentAt(result, 2), 'two');
      expect(result.chapterStartIndexes, [0, 2]);
    });

    test('interleaved TOC (A→B→A#anchor) linearizes A exactly once',
        () async {
      final package = EpubPackage(
        archive: archiveWithFiles({
          'a.xhtml': _html(['<p>a1</p>', '<h2 id="x">a2</h2>']),
          'b.xhtml': _html(['<p>b1</p>']),
        }),
        toc: [
          entry('A', 'a.xhtml'),
          entry('B', 'b.xhtml'),
          entry('A late', 'a.xhtml', anchor: 'x'),
        ],
        spinePaths: const ['a.xhtml', 'b.xhtml'],
        coverPath: null,
      );

      final result = await computeEpubParseResultForPackage(package);

      // Old walk re-linearized A for the third entry: 4 paragraphs and a
      // shifted b1. Now: a1, a2, b1 — once each.
      expect(result.paragraphCount, 3);
      expect(contentAt(result, 2), 'b1');
      expect(result.chapterStartIndexes, [0, 2, 1]);
    });

    test('spine order wins when the TOC lists chapters out of order',
        () async {
      final package = EpubPackage(
        archive: archiveWithFiles({
          'ch1.xhtml': _html(['<p>alpha</p>']),
          'ch2.xhtml': _html(['<p>gamma</p>']),
        }),
        toc: [entry('One', 'ch1.xhtml'), entry('Two', 'ch2.xhtml')],
        spinePaths: const ['ch2.xhtml', 'ch1.xhtml'],
        coverPath: null,
      );

      final result = await computeEpubParseResultForPackage(package);

      expect(contentAt(result, 0), 'gamma');
      expect(contentAt(result, 1), 'alpha');
      // Non-monotonic starts are legal; ContentMetaManager scans, not
      // bisects.
      expect(result.chapterStartIndexes, [1, 0]);
    });

    test('TOC-only files (not in spine) are appended, not dropped',
        () async {
      final package = EpubPackage(
        archive: archiveWithFiles({
          'ch1.xhtml': _html(['<p>main</p>']),
          'extra.xhtml': _html(['<p>appendix</p>']),
        }),
        toc: [entry('Main', 'ch1.xhtml'), entry('Extra', 'extra.xhtml')],
        spinePaths: const ['ch1.xhtml'],
        coverPath: null,
      );

      final result = await computeEpubParseResultForPackage(package);

      expect(result.paragraphCount, 2);
      expect(contentAt(result, 1), 'appendix');
      expect(result.chapterStartIndexes, [0, 1]);
    });

    test('label-only section headers anchor at the first content beneath',
        () async {
      final package = EpubPackage(
        archive: archiveWithFiles({
          'ch1.xhtml': _html(['<p>one</p>']),
          'ch2.xhtml': _html(['<p>two</p>']),
        }),
        toc: [
          entry('One', 'ch1.xhtml'),
          entry('Part II', null, children: [entry('Two', 'ch2.xhtml')]),
        ],
        spinePaths: const ['ch1.xhtml', 'ch2.xhtml'],
        coverPath: null,
      );

      final result = await computeEpubParseResultForPackage(package);

      // Flattened: One, Part II (label-only), Two.
      expect(result.chapterStartIndexes, [0, 1, 1]);
    });

    test('hand-built package without spine degrades to TOC-driven order',
        () async {
      final package = EpubPackage(
        archive: archiveWithFiles({
          'ch1.xhtml': _html(['<p>one</p>']),
        }),
        toc: [entry('One', 'ch1.xhtml')],
        coverPath: null,
      );

      final result = await computeEpubParseResultForPackage(package);

      expect(result.paragraphCount, 1);
      expect(result.chapterStartIndexes, [0]);
    });
  });

  group('zip bomb guards', () {
    // Limits are injected small so the tests never allocate bomb-sized data;
    // the production defaults (kMaxEpubEntryBytes / kMaxEpubPackageBytes)
    // only change the threshold, not the mechanism under test.
    Archive archiveWith(String name, List<int> bytes) {
      final archive = Archive();
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
      return archive;
    }

    test('readZipBytes throws on entries over the ceiling', () {
      final archive = archiveWith('big.bin', List<int>.filled(32, 7));
      expect(
        () => readZipBytes(archive, 'big.bin', maxEntryBytes: 16),
        throwsFormatException,
      );
    });

    test('readZipBytes returns entries within the ceiling', () {
      final archive = archiveWith('ok.bin', [1, 2, 3]);
      expect(readZipBytes(archive, 'ok.bin', maxEntryBytes: 16), [1, 2, 3]);
    });

    test('parseEpubFileInIsolate rejects oversized packages before reading',
        () async {
      final dir = await Directory.systemTemp.createTemp('nyan_epub_guard');
      addTearDown(() async {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      });
      final file = File('${dir.path}/huge.epub');
      await file.writeAsBytes(List<int>.filled(64, 0));

      expect(
        () => parseEpubFileInIsolate(file.path, maxPackageBytes: 32),
        throwsFormatException,
      );
    });

    test('a normal book still parses through the guarded file path',
        () async {
      const container = '<?xml version="1.0"?>'
          '<container><rootfiles>'
          '<rootfile full-path="OEBPS/content.opf"/>'
          '</rootfiles></container>';
      const opf = '<?xml version="1.0"?>'
          '<package><manifest>'
          '<item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>'
          '</manifest><spine><itemref idref="ch1"/></spine></package>';
      final ch1 = _html(['<p>hello</p>', '<p>world</p>']);

      final archive = Archive();
      void add(String name, String content) {
        final bytes = utf8.encode(content);
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }

      add('META-INF/container.xml', container);
      add('OEBPS/content.opf', opf);
      add('OEBPS/ch1.xhtml', ch1);

      final dir = await Directory.systemTemp.createTemp('nyan_epub_guard_ok');
      addTearDown(() async {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      });
      final file = File('${dir.path}/book.epub');
      await file.writeAsBytes(Uint8List.fromList(ZipEncoder().encode(archive)));

      final result = await parseEpubFileInIsolate(file.path);
      expect(result.paragraphCount, 2);
    });
  });
}
