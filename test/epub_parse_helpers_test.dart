/// Golden tests for computeEpubParseResult (analysis item #6, §3.5 protected
/// surface):
///   1. paragraphCount stays byte-for-byte equivalent to upstream — it drives
///      persisted progress mapping and MUST NOT change.
///   2. Anchored chapters resolve to ABSOLUTE flat indexes (the deliberate
///      divergence from upstream's relative-index bug), including the
///      2nd..nth anchored chapter sharing one HTML file.
library;

import 'package:epub_view/epub_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/modules/reader/reader_engine/epub/epub_parse_helpers.dart';

String _html(List<String> bodyElements) =>
    '<html><head></head><body>${bodyElements.join()}</body></html>';

EpubChapter _chapter({
  required String title,
  required String fileName,
  required String html,
  String? anchor,
  List<EpubChapter>? subChapters,
}) {
  return EpubChapter()
    ..Title = title
    ..ContentFileName = fileName
    ..Anchor = anchor
    ..HtmlContent = html
    ..SubChapters = subChapters ?? <EpubChapter>[];
}

EpubBook _book(List<EpubChapter> chapters) =>
    EpubBook()..Chapters = chapters;

void main() {
  group('computeEpubParseResult golden', () {
    test('plain multi-file book: cumulative start indexes, exact count', () {
      final file1 = _html(['<p>a</p>', '<p>b</p>', '<p>c</p>']);
      final file2 = _html(['<p>d</p>', '<p>e</p>']);
      final book = _book([
        _chapter(title: 'One', fileName: 'ch1.xhtml', html: file1),
        _chapter(title: 'Two', fileName: 'ch2.xhtml', html: file2),
      ]);

      final result = computeEpubParseResult(book);

      expect(result.paragraphCount, 5);
      expect(result.chapterStartIndexes, [0, 3]);
    });

    test('anchored chapters in a shared file resolve to absolute indexes',
        () {
      // The classic "one HTML file, many chapters via anchors" layout that
      // upstream mis-indexed: chapter Two/Three point into file2 by anchor.
      final file1 = _html(['<p>a</p>', '<p>b</p>', '<p>c</p>']);
      final file2 = _html([
        '<p>intro</p>',
        '<p>more</p>',
        '<h2 id="sec2">Two</h2>',
        '<h2 id="sec3">Three</h2>',
      ]);
      final book = _book([
        _chapter(title: 'One', fileName: 'ch1.xhtml', html: file1),
        _chapter(
            title: 'Two', fileName: 'body.xhtml', html: file2, anchor: 'sec2'),
        _chapter(
            title: 'Three',
            fileName: 'body.xhtml',
            html: file2,
            anchor: 'sec3'),
      ]);

      final result = computeEpubParseResult(book);

      expect(result.paragraphCount, 7);
      // Upstream bug produced [0, 2, 7] (relative index, then end-of-file
      // fallback for the same-file second anchor). Fixed: absolute indexes.
      expect(result.chapterStartIndexes, [0, 5, 6]);
    });

    test('missing anchor falls back to the start of its own file', () {
      final file1 = _html(['<p>a</p>', '<p>b</p>']);
      final file2 = _html(['<p>c</p>', '<p>d</p>', '<p>e</p>']);
      final book = _book([
        _chapter(title: 'One', fileName: 'ch1.xhtml', html: file1),
        _chapter(
            title: 'Two',
            fileName: 'ch2.xhtml',
            html: file2,
            anchor: 'nope'),
      ]);

      final result = computeEpubParseResult(book);

      expect(result.paragraphCount, 5);
      expect(result.chapterStartIndexes, [0, 2]);
    });

    test('sub-chapters are flattened DFS pre-order and indexed', () {
      final file1 = _html(['<p>a</p>', '<p>b</p>']);
      final file2 = _html(['<p>c</p>', '<h2 id="s1">Sub</h2>', '<p>d</p>']);
      final book = _book([
        _chapter(
          title: 'One',
          fileName: 'ch1.xhtml',
          html: file1,
          subChapters: [
            _chapter(
                title: 'Sub',
                fileName: 'ch2.xhtml',
                html: file2,
                anchor: 's1'),
          ],
        ),
      ]);

      final result = computeEpubParseResult(book);

      expect(result.paragraphCount, 5);
      expect(result.chapterStartIndexes, [0, 3]);
    });

    test('navigation-only chapter without HTML contributes zero paragraphs',
        () {
      final file1 = _html(['<p>a</p>']);
      final book = _book([
        _chapter(title: 'Cover', fileName: 'nav.xhtml', html: ''),
        _chapter(title: 'One', fileName: 'ch1.xhtml', html: file1),
      ]);

      final result = computeEpubParseResult(book);

      expect(result.paragraphCount, 1);
      expect(result.chapterStartIndexes, [0, 0]);
    });
  });
}
