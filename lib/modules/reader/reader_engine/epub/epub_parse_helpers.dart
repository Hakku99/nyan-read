// Phase 2 · P0-5 (AGENTS.md §3.5.1):
//
// Self-contained equivalents of `parseChapters` / `parseParagraphs` from
// `package:epub_view/src/data/epub_parser.dart`.  The upstream functions live
// under `src/` which is a **private** path — importing it fails Dart's
// `public_member_api_docs` and is a ticking time bomb: any epub_view bump can
// silently rename / relocate it.  We inline them here so we own the
// algorithm, so we can run it inside `compute()`, and so the engine depends
// only on epub_view's *public* surface (`EpubDocument`, `EpubController`,
// `EpubView`, `EpubCfiReader`).
//
// IMPORTANT: the paragraph-counting logic MUST stay byte-for-byte equivalent
// to the upstream implementation, because both the reader's "resume at last
// paragraph" invariant (AGENTS.md §3.6) and our highlight mapping address
// paragraphs by absolute flat index.  The chapter-*start*-index logic
// deliberately diverges from upstream (it had a relative-vs-absolute index
// bug — see computeEpubParseResult); chapter indexes are never persisted so
// the divergence is migration-free.  Golden tests live in
// test/epub_parse_helpers_test.dart — keep them green when refactoring.

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:epub_view/epub_view.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Lightweight DTO for the main isolate.  We intentionally avoid shipping
/// `Paragraph` objects (they hold `dom.Element` which drags the whole
/// Document graph and is expensive to deep-copy across isolates); the
/// engine only needs the *count* and the chapter start offsets to drive
/// progress + chapter navigation.
class EpubParseResult {
  EpubParseResult({
    required this.paragraphCount,
    required this.chapterStartIndexes,
    required this.chapters,
    this.missingResourcePaths = const <String>[],
  });

  final int paragraphCount;
  final List<int> chapterStartIndexes;
  final List<EpubChapterMeta> chapters;
  final List<String> missingResourcePaths;
}

class EpubChapterMeta {
  EpubChapterMeta({required this.title});

  final String? title;
}

/// Equivalent of the upstream `parseChapters`: flattens chapters + their
/// direct sub-chapters in DFS pre-order.  Must match exactly, because the
/// chapter index we surface to ReaderController is the index into *this*
/// flattened list.
List<EpubChapter> flattenEpubChapters(EpubBook epubBook) =>
    (epubBook.Chapters ?? const <EpubChapter>[]).fold<List<EpubChapter>>(
      <EpubChapter>[],
      (acc, next) {
        acc.add(next);
        (next.SubChapters ?? const <EpubChapter>[]).forEach(acc.add);
        return acc;
      },
    );

List<dom.Element> _convertDocumentToElements(dom.Document document) {
  final bodies = document.getElementsByTagName('body');
  if (bodies.isEmpty) return const <dom.Element>[];
  return bodies.first.children;
}

/// Inlined equivalent of `EpubCfiReader.chapterDocument(chapter)`.
///
/// Upstream implementation (kept verbatim so our paragraph count matches):
///   1. Normalise XHTML self-closing tags (`<br/>` → `<br></br>`), because
///      `package:html`'s lenient parser counts them differently otherwise.
///   2. Regex-extract the `<body>…</body>` slab.
///   3. Parse the slab with `package:html`.
///
/// Returns `null` for chapters with no HTML content or no body match — both
/// are legitimate for navigation-only TOC entries in real EPUBs.
dom.Document? _chapterDocument(EpubChapter chapter) {
  final htmlContent = chapter.HtmlContent;
  if (htmlContent == null) return null;

  final normalised = htmlContent.replaceAllMapped(
    RegExp(r'<\s*([^\s>]+)([^>]*)\/\s*>'),
    (match) => '<${match.group(1)}${match.group(2)}></${match.group(1)}>',
  );
  final bodyMatch = RegExp(
    r'<body.*?>.+?</body>',
    caseSensitive: false,
    multiLine: true,
    dotAll: true,
  ).firstMatch(normalised);
  if (bodyMatch == null) return null;

  return html_parser.parse(bodyMatch.group(0));
}

List<dom.Element> _removeAllDiv(List<dom.Element> elements) {
  final List<dom.Element> result = [];
  for (final node in elements) {
    if (node.localName == 'div' && node.children.length > 1) {
      result.addAll(_removeAllDiv(node.children));
    } else {
      result.add(node);
    }
  }
  return result;
}

/// Equivalent of the upstream `parseParagraphs`, but returns only the
/// metrics the reader engine needs.  `content` is ignored upstream (the
/// upstream function takes it but only reads chapter.ContentFileName),
/// so we drop it from the signature.
///
/// DELIBERATE DIVERGENCE from upstream (analysis item #6): upstream stores
/// the *file-relative* element index for anchored chapters, so TOC jumps on
/// "one HTML file, many chapters via anchors" EPUBs landed near the book
/// start. We store the absolute flat index (`file start + anchor offset`)
/// and keep the parsed element list alive across same-file chapters so the
/// 2nd..nth anchored chapter in a file resolves too (upstream saw an empty
/// list there and fell back to end-of-file).
///
/// Safe without any data migration: chapter start indexes are never
/// persisted — positions/highlights store CFI + absolute paragraph index
/// from the scroll position, and the chapter list is rebuilt on every open.
/// `paragraphCount` (which *does* drive persisted progress mapping) is
/// computed exactly as upstream.
EpubParseResult computeEpubParseResult(EpubBook epubBook) {
  final parsedChapters = flattenEpubChapters(epubBook);

  String? filename = '';
  final List<int> chapterIndexes = [];
  int paragraphCount = 0;
  int currentFileStart = 0;
  List<dom.Element> currentFileElements = const <dom.Element>[];

  for (final chapter in parsedChapters) {
    if (filename != chapter.ContentFileName) {
      filename = chapter.ContentFileName;
      currentFileStart = paragraphCount;
      final document = _chapterDocument(chapter);
      currentFileElements = document == null
          ? const <dom.Element>[]
          : _removeAllDiv(_convertDocumentToElements(document));
      paragraphCount += currentFileElements.length;
    }

    if (chapter.Anchor == null) {
      chapterIndexes.add(currentFileStart);
      continue;
    }

    final anchorNeedle = 'id="${chapter.Anchor}"';
    final index = currentFileElements.indexWhere(
      (elm) => elm.outerHtml.contains(anchorNeedle),
    );
    chapterIndexes.add(index == -1 ? currentFileStart : currentFileStart + index);
  }

  final chapterMeta = parsedChapters
      .map((c) => EpubChapterMeta(title: c.Title))
      .toList(growable: false);

  return EpubParseResult(
    paragraphCount: paragraphCount,
    chapterStartIndexes: chapterIndexes,
    chapters: chapterMeta,
  );
}

class _TolerantOpenResult {
  _TolerantOpenResult({
    required this.book,
    required this.missingPaths,
  });

  final EpubBook book;
  final List<String> missingPaths;
}

Future<_TolerantOpenResult> _openEpubWithMissingResourceTolerance(
  Uint8List sourceBytes, {
  int maxAutoFixes = 8,
}) async {
  var candidate = sourceBytes;
  final repairedPaths = <String>[];

  for (var attempt = 0; attempt <= maxAutoFixes; attempt++) {
    try {
      final book = await EpubDocument.openData(candidate);
      return _TolerantOpenResult(
        book: book,
        missingPaths: List<String>.unmodifiable(repairedPaths),
      );
    } catch (e) {
      final missingPath = _extractMissingArchivePath(e.toString());
      if (missingPath == null || repairedPaths.contains(missingPath)) {
        rethrow;
      }
      repairedPaths.add(missingPath);
      candidate = applyMissingResourceStubs(candidate, repairedPaths);
    }
  }

  throw FormatException(
    'EPUB parsing failed after $maxAutoFixes missing-resource auto-fixes.',
  );
}

String? _extractMissingArchivePath(String error) {
  final match =
      RegExp(r'file (.+?) not found in archive', caseSensitive: false)
          .firstMatch(error);
  if (match == null) {
    return null;
  }
  final path = match.group(1);
  if (path == null || path.isEmpty) {
    return null;
  }
  return path;
}

Uint8List applyMissingResourceStubs(
  Uint8List sourceBytes,
  List<String> missingPaths,
) {
  if (missingPaths.isEmpty) {
    return sourceBytes;
  }

  final archive = ZipDecoder().decodeBytes(sourceBytes);
  for (final path in missingPaths) {
    final alreadyExists = archive.files.any((entry) => entry.name == path);
    if (!alreadyExists) {
      archive.addFile(ArchiveFile(path, 0, <int>[]));
    }
  }
  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    return sourceBytes;
  }
  return Uint8List.fromList(encoded);
}

/// Top-level isolate entry — [compute] demands a top-level or static
/// function reference.  Opens the bytes as an EpubBook and runs the full
/// parse pipeline, returning only the lightweight DTO so nothing else has
/// to cross the isolate boundary.
Future<EpubParseResult> parseEpubBytesInIsolate(Uint8List bytes) async {
  final tolerantOpen = await _openEpubWithMissingResourceTolerance(bytes);
  final parseResult = computeEpubParseResult(tolerantOpen.book);
  return EpubParseResult(
    paragraphCount: parseResult.paragraphCount,
    chapterStartIndexes: parseResult.chapterStartIndexes,
    chapters: parseResult.chapters,
    missingResourcePaths: tolerantOpen.missingPaths,
  );
}
