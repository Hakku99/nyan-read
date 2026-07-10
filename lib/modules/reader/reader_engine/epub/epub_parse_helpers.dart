// EPUB parse pipeline for the self-hosted renderer (2026-07 "EPUB 自研").
//
// Fully owned end to end (P3c dropped epubx): the package structure comes
// from epub_package_parser.dart, paragraph enumeration is our own HTML
// linearization (see _linearizeChapterDocument), and chapter anchors resolve
// through a per-file id → paragraph map. The historical upstream-epub_view
// mirror was abandoned because its element-only walk dropped raw-text-node
// prose entirely (common in Chinese light-novel transcriptions) and
// mis-indexed anchored chapters.
//
// DETERMINISM (AGENTS.md §3.6): same book + same code MUST enumerate the
// same paragraphs — persisted positions address paragraphs by absolute flat
// index. Any change to the linearization rules shifts every persisted EPUB
// anchor; golden tests in test/epub_parse_helpers_test.dart lock the current
// behavior — keep them green, and treat linearization changes as protected-
// surface work (§3.5).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// archive_io re-exports archive.dart and adds InputFileStream (random-access
// zip reads from disk without loading the whole file).
import 'package:archive/archive_io.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'epub_package_parser.dart';

/// Paragraph block kinds emitted by [computeEpubParseResult].
/// Stored as one byte per paragraph in [EpubParseResult.paragraphKinds].
class EpubParagraphKind {
  EpubParagraphKind._();

  static const int text = 0;

  /// The paragraph content is an image resource href (raw `src` attribute),
  /// not display text.
  static const int image = 1;

  /// Text that lives inside an `<h1>`–`<h6>` element — rendered with the
  /// house heading style (larger, w600). Kind-only distinction: heading
  /// paragraphs occupy the same enumeration slots as text (§3.6 anchors
  /// unaffected).
  static const int heading = 2;
}

/// Lightweight DTO for the main isolate.  We intentionally avoid shipping
/// `Paragraph` objects (they hold `dom.Element` which drags the whole
/// Document graph and is expensive to deep-copy across isolates); the
/// engine gets the counts/offsets plus the paragraph *content* flattened
/// into UTF-8 bytes + range pairs (same memory trick as the TXT engine —
/// roughly halves steady-state heap vs a `List<String>`).
class EpubParseResult {
  EpubParseResult({
    required this.paragraphCount,
    required this.chapterStartIndexes,
    required this.chapters,
    this.missingResourcePaths = const <String>[],
    Uint8List? paragraphBytes,
    List<int>? paragraphRanges,
    Uint8List? paragraphKinds,
  })  : paragraphBytes = paragraphBytes ?? Uint8List(0),
        paragraphRanges = paragraphRanges ?? const <int>[],
        paragraphKinds = paragraphKinds ?? Uint8List(0);

  final int paragraphCount;
  final List<int> chapterStartIndexes;
  final List<EpubChapterMeta> chapters;
  final List<String> missingResourcePaths;

  /// UTF-8 of every paragraph's content concatenated; index with
  /// [paragraphRanges] (flat `[start, end]` pairs, 2 ints per paragraph).
  /// For [EpubParagraphKind.image] paragraphs the "content" is the raw
  /// image `src` attribute.
  final Uint8List paragraphBytes;
  final List<int> paragraphRanges;
  final Uint8List paragraphKinds;
}

class EpubChapterMeta {
  EpubChapterMeta({required this.title});

  final String? title;
}

/// Chapter-document preparation:
///   1. Normalise XHTML self-closing tags (`<br/>` → `<br></br>`), because
///      `package:html`'s lenient parser handles them inconsistently.
///   2. Regex-extract the `<body>…</body>` slab.
///   3. Parse the slab with `package:html`.
///
/// Returns `null` for chapters with no HTML content or no body match — both
/// are legitimate for navigation-only TOC entries in real EPUBs.
dom.Document? _chapterDocument(String? htmlContent) {
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

/// Public seam between the package structure and the paragraph walk — also
/// what golden tests construct directly.
class EpubChapterSource {
  EpubChapterSource({
    required this.title,
    required this.contentFileName,
    required this.anchor,
    required this.readHtml,
  });

  final String? title;
  final String? contentFileName;
  final String? anchor;
  final Future<String?> Function() readHtml;
}

/// Walks an [EpubPackage] (own parser, P3c): flattens the TOC tree DFS
/// pre-order into chapter sources whose HTML reads lazily from the zip —
/// images/fonts are NEVER materialized during parse. Missing chapter files
/// resolve to null HTML (zero paragraphs) instead of throwing, so broken
/// books degrade instead of failing to open.
Future<EpubParseResult> computeEpubParseResultForPackage(EpubPackage package) {
  final flat = <EpubTocEntry>[];
  void flatten(List<EpubTocEntry> entries) {
    for (final entry in entries) {
      flat.add(entry);
      flatten(entry.children);
    }
  }

  flatten(package.toc);

  final sources = flat
      .map((entry) => EpubChapterSource(
            title: entry.title,
            contentFileName: entry.fileName,
            anchor: entry.anchor,
            readHtml: () async => entry.fileName == null
                ? null
                : readZipText(package.archive, entry.fileName!),
          ))
      .toList(growable: false);
  return computeEpubParseResultFromSources(sources);
}

/// Block-level tags that force a paragraph boundary when the linearizer
/// enters and leaves them. Everything else (span/a/em/ruby/…) is inline and
/// contributes its text to the current paragraph.
const Set<String> _blockTags = {
  'p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
  'li', 'ul', 'ol', 'blockquote', 'section', 'article', 'aside',
  'header', 'footer', 'figure', 'figcaption', 'table', 'tr', 'pre', 'hr',
  'body',
};

/// One parsed content file: emitted paragraphs plus the paragraph index each
/// `id=` attribute resolves to (for chapter-anchor lookup).
class _FileLinearization {
  final List<String> texts = [];
  final List<int> kinds = [];
  final Map<String, int> anchorToParagraph = {};
}

/// Linearizes a chapter document into paragraphs the way a renderer reads
/// it: text NODES accumulate into a buffer, `<br>` and block boundaries
/// flush it, `<img>` emits an image paragraph, empty runs are dropped.
///
/// This deliberately replaces the upstream epub_view enumeration, which
/// counted ELEMENTS only: books whose prose lives in raw text nodes
/// separated by `<br/>` (a common Chinese light-novel transcription layout)
/// enumerated thousands of empty `<br>` "paragraphs" and dropped every line
/// of actual prose.
const Set<String> _headingTags = {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'};

_FileLinearization _linearizeChapterDocument(dom.Document document) {
  final out = _FileLinearization();
  final buffer = StringBuffer();
  var headingDepth = 0;

  void flush() {
    final text = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    buffer.clear();
    if (text.isEmpty) return;
    out.texts.add(text);
    out.kinds.add(headingDepth > 0
        ? EpubParagraphKind.heading
        : EpubParagraphKind.text);
  }

  void walk(dom.Node node) {
    if (node is dom.Text) {
      buffer.write(node.text);
      return;
    }
    if (node is! dom.Element) return;

    final id = node.attributes['id'];
    if (id != null && id.isNotEmpty) {
      // The anchor resolves to wherever the NEXT paragraph lands. Pending
      // buffered text belongs to the paragraph *before* the anchor target,
      // so flush first.
      flush();
      out.anchorToParagraph.putIfAbsent(id, () => out.texts.length);
    }

    final tag = node.localName ?? '';
    if (tag == 'img') {
      flush();
      final src = node.attributes['src'] ?? '';
      if (src.isNotEmpty) {
        out.texts.add(src);
        out.kinds.add(EpubParagraphKind.image);
      }
      return;
    }
    if (tag == 'br') {
      flush();
      return;
    }
    if (tag == 'script' || tag == 'style') {
      return;
    }

    final isBlock = _blockTags.contains(tag);
    final isHeading = _headingTags.contains(tag);
    if (isBlock || isHeading) flush();
    if (isHeading) headingDepth++;
    for (final child in node.nodes) {
      walk(child);
    }
    // Flush BEFORE leaving the heading scope so the heading's own text is
    // still tagged with the heading kind.
    if (isBlock || isHeading) flush();
    if (isHeading) headingDepth--;
  }

  final bodies = document.getElementsByTagName('body');
  if (bodies.isNotEmpty) {
    walk(bodies.first);
  }
  flush();
  return out;
}

/// Core paragraph walk. Public so golden tests can drive it with
/// hand-constructed [EpubChapterSource]s.
Future<EpubParseResult> computeEpubParseResultFromSources(
    List<EpubChapterSource> parsedChapters) async {
  String? filename = '';
  final List<int> chapterIndexes = [];
  int paragraphCount = 0;
  int currentFileStart = 0;
  Map<String, int> currentFileAnchors = const {};

  // Paragraph content is emitted by the SAME traversal that counts the
  // paragraphs — index alignment between count and content is structural,
  // not something a second walk could drift away from (§3.6 determinism).
  final contentBytes = BytesBuilder(copy: false);
  final contentRanges = <int>[];
  final kinds = BytesBuilder(copy: false);
  var contentCursor = 0;

  for (final chapter in parsedChapters) {
    if (filename != chapter.contentFileName) {
      filename = chapter.contentFileName;
      currentFileStart = paragraphCount;
      final document = _chapterDocument(await chapter.readHtml());
      if (document == null) {
        currentFileAnchors = const {};
      } else {
        final linearized = _linearizeChapterDocument(document);
        currentFileAnchors = linearized.anchorToParagraph;
        paragraphCount += linearized.texts.length;
        for (var i = 0; i < linearized.texts.length; i++) {
          final encoded = utf8.encode(linearized.texts[i]);
          contentBytes.add(encoded);
          contentRanges
            ..add(contentCursor)
            ..add(contentCursor + encoded.length);
          contentCursor += encoded.length;
          kinds.addByte(linearized.kinds[i]);
        }
      }
    }

    if (chapter.anchor == null) {
      chapterIndexes.add(currentFileStart);
      continue;
    }

    final anchorOffset = currentFileAnchors[chapter.anchor];
    chapterIndexes.add(anchorOffset == null
        ? currentFileStart
        : (currentFileStart + anchorOffset)
            .clamp(currentFileStart, paragraphCount));
  }

  final chapterMeta = parsedChapters
      .map((c) => EpubChapterMeta(title: c.title))
      .toList(growable: false);

  return EpubParseResult(
    paragraphCount: paragraphCount,
    chapterStartIndexes: chapterIndexes,
    chapters: chapterMeta,
    paragraphBytes: contentBytes.takeBytes(),
    paragraphRanges: contentRanges,
    paragraphKinds: kinds.takeBytes(),
  );
}

/// Isolate worker: pulls ONE image resource out of the EPUB zip by matching
/// the raw `src` href against archive entry paths. Suffix matching tolerates
/// relative prefixes (`../images/x.png` vs `OEBPS/images/x.png`). Returns
/// null when the resource is missing or unreadable — callers render a
/// placeholder.
Uint8List? extractEpubImageBytes(Uint8List sourceBytes, String rawSrc) {
  try {
    final needle = _normalizeImageNeedle(rawSrc);
    if (needle == null) return null;
    final archive = ZipDecoder().decodeBytes(sourceBytes);
    return readZipBytes(archive, needle);
  } catch (_) {
    return null;
  }
}

/// Parses raw EPUB bytes into the paragraph DTO. The own package parser
/// (P3c) is tolerant by construction — missing chapter files, absent TOCs
/// and separator-mangled hrefs all degrade instead of throwing, so the old
/// zip-repair retry loop (write empty stubs, re-encode the whole archive)
/// is gone.
Future<EpubParseResult> parseEpubBytesInIsolate(Uint8List bytes) {
  final package = parseEpubPackage(bytes);
  return computeEpubParseResultForPackage(package);
}

/// Isolate entry that reads the EPUB from [path] *inside* the isolate — the
/// book bytes never exist on the main isolate. Feeding parse via a byte
/// array instead means the file is held on the main isolate AND copied
/// across the isolate boundary: 2× the book size of avoidable peak memory,
/// which is exactly what OOM'd large EPUBs on tight devices.
Future<EpubParseResult> parseEpubFileInIsolate(String path) async {
  final bytes = await File(path).readAsBytes();
  return parseEpubBytesInIsolate(bytes);
}

/// File-path variant of [extractEpubImageBytes]: streams the zip central
/// directory from disk ([InputFileStream]) and inflates ONLY the requested
/// entry — peak memory is the decoded image, not the whole book. Loading a
/// 184 MB illustrated EPUB into RAM per figure was an OOM face on tight
/// devices (and the reason the first field build showed "[Image load
/// failed]" placeholders).
Uint8List? extractEpubImageBytesFromFile(String path, String rawSrc) {
  InputFileStream? input;
  try {
    final needle = _normalizeImageNeedle(rawSrc);
    if (needle == null) return null;

    input = InputFileStream(path);
    final archive = ZipDecoder().decodeStream(input);
    return readZipBytes(archive, needle);
  } catch (_) {
    return null;
  } finally {
    input?.close();
  }
}

/// Strips query/fragment and leading `./`/`../` segments; lowercases for
/// case-insensitive matching. Returns null for unusable inputs.
String? _normalizeImageNeedle(String rawSrc) {
  var needle = rawSrc.trim();
  if (needle.isEmpty) return null;
  final cut = needle.indexOf(RegExp(r'[?#]'));
  if (cut != -1) needle = needle.substring(0, cut);
  needle = needle.replaceAll('\\', '/');
  while (needle.startsWith('./') || needle.startsWith('../')) {
    needle = needle.startsWith('./') ? needle.substring(2) : needle.substring(3);
  }
  if (needle.isEmpty) return null;
  return needle.toLowerCase();
}
