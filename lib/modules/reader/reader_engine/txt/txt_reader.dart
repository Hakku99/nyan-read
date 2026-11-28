import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../core/models/book.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/chapter_heading_display.dart';
import '../../../../core/models/highlight.dart';
import '../../../../core/services/reader_preferences_service.dart';
import '../../../../core/theme/nyan_typography.dart';
import '../../../../core/utils/book_source_access.dart';
import '../../widgets/highlightable_text.dart';
import '../reader_engine.dart';
import '../text_layout_anchor.dart';
import 'pagination_helper.dart';
import 'txt_position.dart';

typedef PaginationEstimateCalculator = Future<List<int>> Function({
  required String text,
  required TextStyle style,
  required double maxWidth,
  required double maxHeight,
  required EdgeInsets padding,
  // Nullable optional so existing closures / mocks can omit them safely.
  TextScaler? textScaler,
  double? paragraphBottomMargin,
  int? totalTextLength,
});

/// Size of the contiguous head-of-book sample kept on the main isolate for
/// TextPainter-driven page-count estimation.  A few kB is enough to fill a
/// screen or two, which is all that is ever inspected for pagination.
const int _kPaginationSampleSize = 4000;

/// Parses raw TXT bytes completely off the UI thread: byte decoding, line
/// splitting, paragraph offset table AND chapter heading detection all
/// happen inside this single [compute] call, because each of these steps
/// scales linearly with book size and used to freeze the UI during book
/// open on multi-MB novels.
///
/// Returns only sendable primitives so it is safe across isolate
/// boundaries.  The caller reconstructs [ReaderChapter] objects on the
/// main isolate.
class _TxtParseResult {
  _TxtParseResult({
    required this.rawUtf8,
    required this.lineRanges,
    required this.lineCount,
    required this.paragraphOffsets,
    required this.totalTextLength,
    required this.paginationSample,
    required this.chapterTitles,
    required this.chapterParagraphIndexes,
  });

  // Raw UTF-8 bytes of the book content (re-encoded from whatever the source
  // encoding was).  Storing UTF-8 rather than decoded Dart strings cuts
  // session memory roughly in half for ASCII/Latin content (UTF-16 in Dart is
  // 2 bytes/char; UTF-8 is 1 byte/char for ASCII).  CJK content is comparable
  // in size.  Lines are decoded on-demand in itemBuilder.
  final Uint8List rawUtf8;
  // Interleaved (start, end) byte offsets into rawUtf8, one pair per line.
  // Length == lineCount * 2.
  final List<int> lineRanges;
  final int lineCount;
  final List<int> paragraphOffsets;
  final int totalTextLength;
  final String paginationSample;
  final List<String> chapterTitles;
  final List<int> chapterParagraphIndexes;
}

_TxtParseResult _parseTxtInIsolate(Uint8List bytes) {
  final content = decodeTxtBytesForParse(bytes);
  final lines = content.split('\n');
  final totalLength = content.length;
  final paginationSample = totalLength > _kPaginationSampleSize
      ? content.substring(0, _kPaginationSampleSize)
      : content;

  final offsets = List<int>.filled(lines.length, 0);
  int cursor = 0;
  for (int i = 0; i < lines.length; i++) {
    offsets[i] = cursor;
    cursor += lines[i].length + 1;
  }

  final titles = <String>[];
  final indexes = <int>[];
  const int maxChapterLineLength = 500;
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    // Skip pathological lines to prevent regex backtracking.  Chapter headings
    // are never this long.
    if (line.length > maxChapterLineLength) continue;

    var isChapter = _looksLikeChapterHeadingStatic(line);
    if (!isChapter && _isStandaloneNumericHeadingStatic(line)) {
      final nextLine = _nextNonEmptyLineStatic(lines, i + 1);
      isChapter = nextLine == null ||
          (_looksLikeChapterSubtitleStatic(nextLine) &&
              !_looksLikeChapterHeadingStatic(nextLine));
    }

    if (isChapter) {
      titles.add(line);
      indexes.add(i);
    }
  }

  // Re-encode the decoded content as UTF-8 and build a byte-range index so
  // the engine can store 1× the file size in memory rather than 2× (Dart
  // strings are UTF-16 internally; for ASCII-heavy content this halves the
  // steady-state heap cost while the parse isolate is active only briefly).
  final builder = BytesBuilder(copy: false);
  final lineRanges = List<int>.filled(lines.length * 2, 0);
  for (int i = 0; i < lines.length; i++) {
    final encoded = utf8.encode(lines[i]);
    final start = builder.length;
    builder.add(encoded);
    lineRanges[i * 2] = start;
    lineRanges[i * 2 + 1] = builder.length;
  }
  final rawUtf8 = builder.takeBytes();

  return _TxtParseResult(
    rawUtf8: rawUtf8,
    lineRanges: lineRanges,
    lineCount: lines.length,
    paragraphOffsets: offsets,
    totalTextLength: totalLength,
    paginationSample: paginationSample,
    chapterTitles: titles,
    chapterParagraphIndexes: indexes,
  );
}

/// Decodes raw TXT bytes into text (analysis item #2).
///
/// Order matters — this feeds line splitting, and line indexes are the
/// anchor for reading positions and highlights (§3.5 protected surface):
///  1. BOM (unambiguous): UTF-8 / UTF-16 LE / UTF-16 BE. Windows Notepad's
///     "Unicode" save is UTF-16 LE with BOM — a common Chinese TXT format
///     that the old utf8→gbk→latin1 chain always rendered as mojibake.
///  2. BOM-less UTF-16 heuristic (must run before utf8: ASCII-heavy UTF-16
///     LE bytes are *valid* UTF-8 with interleaved NULs, so strict utf8
///     would pseudo-succeed).
///  3. Legacy chain utf8 → gbk, byte-for-byte identical results for every
///     valid UTF-8 / GBK book — existing anchors must not move.
///  4. latin1 as last resort only for plausible Latin text; a high-byte-heavy
///     payload (CJK in some unsupported encoding) throws instead of silently
///     rendering mojibake that would pollute highlight/progress anchors.
@visibleForTesting
String decodeTxtBytesForParse(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    // BOM declared UTF-8: tolerate stray malformed sequences rather than
    // bailing out to a wrong codec.
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _decodeUtf16(bytes, 2, Endian.little);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _decodeUtf16(bytes, 2, Endian.big);
  }

  final bomlessUtf16 = _sniffBomlessUtf16(bytes);
  if (bomlessUtf16 != null) {
    return _decodeUtf16(bytes, 0, bomlessUtf16);
  }

  try {
    return utf8.decode(bytes);
  } catch (_) {
    // fall through
  }
  try {
    return gbk.decode(bytes);
  } catch (_) {
    // fall through
  }

  // ponytail: Big5 (and other DBCS) bytes usually pseudo-succeed inside
  // gbk.decode above, so they never reach this guard — detecting them needs
  // a real charset sniffer; add one if Big5 mojibake reports come in.
  if (_highByteRatio(bytes) > 0.30) {
    throw const FormatException(
        'Unsupported text encoding (not UTF-8/UTF-16/GBK, too much non-ASCII '
        'content for Latin-1)');
  }
  return latin1.decode(bytes);
}

String _decodeUtf16(Uint8List bytes, int start, Endian endian) {
  // Odd trailing byte (truncated file): drop it rather than fail the book.
  final count = (bytes.length - start) ~/ 2;
  final codeUnits = Uint16List(count);
  for (var i = 0; i < count; i++) {
    final b0 = bytes[start + i * 2];
    final b1 = bytes[start + i * 2 + 1];
    codeUnits[i] = endian == Endian.little ? (b1 << 8) | b0 : (b0 << 8) | b1;
  }
  // Dart strings are UTF-16 code units, so surrogate pairs pass through.
  return String.fromCharCodes(codeUnits);
}

/// Detects BOM-less ASCII-heavy UTF-16 by NUL distribution: Latin text in
/// UTF-16 has a zero byte in nearly every code unit's high position, while
/// valid UTF-8/GBK text files contain essentially no NUL bytes at all — so
/// the 40%/5% thresholds cannot misfire on them. CJK-only BOM-less UTF-16
/// (few NULs) is not detected; in practice UTF-16 writers emit a BOM.
Endian? _sniffBomlessUtf16(Uint8List bytes) {
  if (bytes.length < 16 || bytes.length.isOdd) return null;
  final sampleBytes = bytes.length < 8192 ? bytes.length : 8192;
  final units = sampleBytes ~/ 2;
  var evenZeros = 0;
  var oddZeros = 0;
  for (var i = 0; i + 1 < sampleBytes; i += 2) {
    if (bytes[i] == 0) evenZeros++;
    if (bytes[i + 1] == 0) oddZeros++;
  }
  if (oddZeros > units * 0.40 && evenZeros < units * 0.05) {
    return Endian.little;
  }
  if (evenZeros > units * 0.40 && oddZeros < units * 0.05) {
    return Endian.big;
  }
  return null;
}

double _highByteRatio(Uint8List bytes) {
  if (bytes.isEmpty) return 0;
  final sampleBytes = bytes.length < 8192 ? bytes.length : 8192;
  var high = 0;
  for (var i = 0; i < sampleBytes; i++) {
    if (bytes[i] >= 0x80) high++;
  }
  return high / sampleBytes;
}

class TxtInlineImageTag {
  const TxtInlineImageTag({
    required this.src,
    this.alt,
  });

  final String src;
  final String? alt;
}

final RegExp _standaloneImgTagPattern = RegExp(
  r'^<img\b[^>]*>$',
  caseSensitive: false,
);
final RegExp _imgSrcPattern = RegExp(
  r'''src\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s>]+))''',
  caseSensitive: false,
);
final RegExp _imgAltPattern = RegExp(
  r'''alt\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s>]+))''',
  caseSensitive: false,
);

String? _firstNonNullGroup(RegExpMatch match) {
  for (int i = 1; i <= match.groupCount; i++) {
    final value = match.group(i);
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

@visibleForTesting
TxtInlineImageTag? tryParseTxtStandaloneImgTag(String line) {
  final normalized = line.trim();
  if (!_standaloneImgTagPattern.hasMatch(normalized)) {
    return null;
  }
  final srcMatch = _imgSrcPattern.firstMatch(normalized);
  final src = srcMatch == null ? null : _firstNonNullGroup(srcMatch);
  if (src == null || src.isEmpty) {
    return null;
  }
  final altMatch = _imgAltPattern.firstMatch(normalized);
  final alt = altMatch == null ? null : _firstNonNullGroup(altMatch);
  return TxtInlineImageTag(src: src, alt: alt);
}

bool _looksLikeWindowsAbsolutePath(String src) {
  return RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(src);
}

/// Maps an inline-image URI to an [ImageProvider], or null when the source
/// must not be loaded.
///
/// http/https deliberately return null: a downloaded TXT with an embedded
/// `<img src="https://...">` would otherwise fire a network request on open —
/// a tracking beacon that breaks the fully-offline promise (leaks IP +
/// reading time to an arbitrary third party). Only local files and inline
/// data: URIs render.
@visibleForTesting
ImageProvider<Object>? txtImageProviderFor(Uri sourceUri) {
  if (sourceUri.scheme == 'file' || sourceUri.scheme.isEmpty) {
    return FileImage(File.fromUri(sourceUri));
  }
  if (sourceUri.scheme == 'data') {
    try {
      final uriData = UriData.parse(sourceUri.toString());
      final bytes = uriData.contentAsBytes();
      if (bytes.isNotEmpty) {
        return MemoryImage(bytes);
      }
    } on FormatException {
      return null;
    }
  }
  return null;
}

@visibleForTesting
Uri? resolveTxtImageSourceUri({
  required Book book,
  required String rawSrc,
}) {
  final src = rawSrc.trim();
  if (src.isEmpty) return null;

  if (_looksLikeWindowsAbsolutePath(src)) {
    return File(src).uri;
  }

  Uri? parsed;
  try {
    parsed = Uri.parse(src);
  } catch (_) {
    parsed = null;
  }

  if (parsed != null && parsed.hasScheme) {
    return parsed;
  }

  if (book.sourceType != BookSourceType.filePath ||
      book.sourceLocator.isEmpty) {
    return null;
  }

  final baseFile = File(book.sourceLocator);
  final parentDir = baseFile.parent;
  return parentDir.uri.resolve(src);
}

// The following helpers are intentionally top-level statics so they can
// execute inside a [compute] isolate.  They MUST NOT touch any instance
// state.
bool _looksLikeNarrativeLineStatic(String line) {
  if (line.length > 72 &&
      RegExp(r'[\u3002\uff01\uff1f!?\uff1b;]').hasMatch(line)) {
    return true;
  }
  return false;
}

Iterable<String> _chapterHeadingCandidatesStatic(String line) sync* {
  final normalized = line.trim().replaceAll('\u3000', ' ');
  if (normalized.isEmpty) return;

  final collapsedWhitespace = normalized.replaceAll(RegExp(r'\s+'), ' ');
  yield collapsedWhitespace;

  final strippedLeadingTag = collapsedWhitespace
      .replaceFirst(
        RegExp(
            r'^[\[\(\uff08\u3010\u300a\u300c\u300e\u3014\u3008].{1,20}[\]\)\uff09\u3011\u300b\u300d\u300f\u3015\u3009]\s*'),
        '',
      )
      .trim();
  if (strippedLeadingTag.isNotEmpty &&
      strippedLeadingTag != collapsedWhitespace) {
    yield strippedLeadingTag;
  }

  final unwrapped = collapsedWhitespace
      .replaceFirst(
          RegExp(r'^[\[\(\uff08\u3010\u300a\u300c\u300e\u3014\u3008]'), '')
      .replaceFirst(
          RegExp(r'[\]\)\uff09\u3011\u300b\u300d\u300f\u3015\u3009]$'), '')
      .trim();
  if (unwrapped.isNotEmpty && unwrapped != collapsedWhitespace) {
    yield unwrapped;
  }
}

bool _looksLikeChapterHeadingStatic(String line) {
  final trimmed = line.trim();
  // Fast prefilter: reject obviously non-chapter lines before expensive work.
  if (trimmed.isEmpty || trimmed.length > 80) return false;
  if (!_hasChapterMarkerStatic(trimmed)) return false;

  for (final candidate in _chapterHeadingCandidatesStatic(line)) {
    if (candidate.isEmpty || candidate.length > 80) continue;
    if (_looksLikeNarrativeLineStatic(candidate)) continue;

    for (final pattern in TxtReaderEngine._chapterHeadingPatterns) {
      if (pattern.hasMatch(candidate)) return true;
    }
    for (final pattern in TxtReaderEngine._specialHeadingPatterns) {
      if (pattern.hasMatch(candidate)) return true;
    }
  }
  return false;
}

// Hoisted: building this per line slowed down opening large books.
final RegExp _chapterMarkerRegExp = RegExp(
  r'(?:\d+|'
  r'[IVXLCDMivxlcdm]+|'
  r'[一-鿿]|'
  r'(?:chapter|chap|volume|vol|book|part|prologue|epilogue|'
  r'interlude|side.?story|extra|appendix|preface|序|序言|前言|終章|'
  r'後記|番外|外伝|幕間|間章|短編|特典))',
  caseSensitive: false,
);

bool _hasChapterMarkerStatic(String line) {
  // Fast checks for lines that look like chapters: contain digits, CJK
  // characters, or English chapter keywords.  Helps skip obviously non-chapter
  // lines (narrative content) before running expensive regex patterns.
  return _chapterMarkerRegExp.hasMatch(line);
}

bool _isStandaloneNumericHeadingStatic(String line) {
  return RegExp(
    r'^\s*(?:\d{1,4}|[IVXLCDMivxlcdm]{1,8}|[\u96f6\u3007\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341\u767e\u5343\u4e07\u4e24]{1,8})\s*$',
  ).hasMatch(line);
}

String? _nextNonEmptyLineStatic(List<String> lines, int startIndex) {
  for (int i = startIndex; i < lines.length; i++) {
    final candidate = lines[i].trim();
    if (candidate.isNotEmpty) return candidate;
  }
  return null;
}

bool _looksLikeChapterSubtitleStatic(String line) {
  final normalized = line.trim();
  if (normalized.isEmpty || normalized.length > 40) return false;
  return !_looksLikeNarrativeLineStatic(normalized);
}

class TxtReaderEngine
    implements
        ReaderEngine,
        TextReaderCapability,
        TextExtractionCapability,
        PageMetricsCapability {
  static const ReaderCapabilities _capabilities = ReaderCapabilities(
    typography: CapabilityLevel.full,
    theme: CapabilityLevel.full,
    highlights: CapabilityLevel.full,
    annotations: CapabilityLevel.full,
    pageAnimation: CapabilityLevel.none,
    chapterNavigation: ReaderChapterNavigation.semantic,
  );

  final Book book;
  String _getLine(int index) {
    final start = _lineRanges[index * 2];
    final end = _lineRanges[index * 2 + 1];
    return utf8.decode(_rawUtf8.sublist(start, end), allowMalformed: true);
  }

  final ItemScrollController _itemScrollController = ItemScrollController();
  ScrollPosition? _scrollPosition;
  ReadingPosition? _pendingRestore;
  final _textLayouts = TextLayoutAnchors();
  Locale? _textLocale;
  TextDirection? _textDirection;
  String? get _layoutIdentity => _viewportSize == null
      ? null
      : jsonEncode([
          1,
          'txt',
          defaultTargetPlatform.name,
          _textLocale?.toLanguageTag(),
          _textDirection?.name,
          _viewportSize!.width,
          _viewportSize!.height,
          _config.fontSize,
          _config.lineHeight,
          _config.useSerif,
          _viewportTextScale?.scale(_config.fontSize),
          _viewportTextScale?.scale(_config.fontSize * 1.3),
        ]);
  ReadingPosition? _committedPosition;
  double? _committedPixels;
  ReadingPosition? _settledAnchor;
  double? _settledPixels;
  final ValueNotifier<bool> _restoreCover = ValueNotifier(false);
  int _navigationSerial = 0;
  int _viewportEpoch = 0;
  int? _applyingRestore;
  bool _disposed = false;
  Size? _viewportSize;
  TextScaler? _viewportTextScale;
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  // Raw UTF-8 bytes of the full book content, plus a byte-range index for
  // on-demand per-line decoding.  This replaces the old List<String> _lines
  // field and roughly halves steady-state heap usage for large ASCII books.
  Uint8List _rawUtf8 = Uint8List(0);
  List<int> _lineRanges = const [];
  int _lineCount = 0;
  bool _isLoading = true;

  ReaderConfig _config = const ReaderConfig(
    backgroundColor: Colors.white,
    textColor: Colors.black,
    fontSize: 18,
    lineHeight: 1.5,
  );

  List<Highlight> _renderHighlights = const [];

  Function(int paragraphIndex, int start, int end, String text,
      String colorCode)? onTextHighlighted;
  Function(Highlight highlight)? onHighlightTapped;
  Function(Offset position)? onContentTap;

  // Only the head-of-book slice needed by TextPainter for page-count
  // estimation is retained after parse; the full content string used to
  // pile up on top of [_lines] and was measured at ~2x the raw file size
  // on Dart's UTF-16 strings.
  String _paginationSample = '';
  int _totalTextLength = 0;
  List<int> _paragraphOffsets = [];
  int _totalPages = 1;
  int _charsPerPage = 1;
  _PaginationLayoutKey? _requestedPaginationKey;
  _PaginationLayoutKey? _estimatedPaginationKey;
  bool get _isPaginationCalculated =>
      _estimatedPaginationKey != null &&
      _estimatedPaginationKey == _requestedPaginationKey;
  final Set<_PaginationLayoutKey> _inFlightPaginationKeys =
      <_PaginationLayoutKey>{};
  final ValueNotifier<int> _pageInfoNotifier = ValueNotifier(0);
  // Only completed, contiguous turns are eligible for precise backtracking.
  final List<_TxtTurn> _turns = [];
  static const _historyLimit = 48;

  List<ReaderChapter> _chapters = const [];

  final ValueNotifier<ReaderConfig> _configNotifier =
      ValueNotifier(const ReaderConfig(
    backgroundColor: Colors.white,
    textColor: Colors.black,
    fontSize: 18,
    lineHeight: 1.5,
  ));
  final ValueNotifier<int> _highlightRenderVersion = ValueNotifier(0);
  static const EdgeInsets _paginationPadding =
      EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0);
  // Exposed to isolate-side helpers in this library file (see the
  // `_looksLikeChapterHeadingStatic` helper at the bottom of the file).
  static final List<RegExp> _chapterHeadingPatterns = [
    RegExp(
      r'^\s*.{1,40}?[\uff1a:]\s*\u7b2c\s*[\u96f6\u3007\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341\u767e\u5343\u4e07\u4e24\dIVXLCDMivxlcdm]+\s*[\u5377\u518c\u90e8\u7bc7\u96c6\u7ae0\u56de\u8282\u8bdd\u5e55](?:\s*(?:[\uff1a:._\-\uff0c\u3001 ]\s*)?.*)?$',
      caseSensitive: false,
    ),
    RegExp(
      r'^\s*\u7b2c\s*[\u96f6\u3007\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341\u767e\u5343\u4e07\u4e24\dIVXLCDMivxlcdm]+\s*[\u5377\u518c\u90e8\u7bc7\u96c6\u7ae0\u56de\u8282\u8bdd\u5e55](?:\s*(?:[\uff1a:._\-\uff0c\u3001 ]\s*)?.*)?$',
      caseSensitive: false,
    ),
    RegExp(
      r'^\s*[\u5377\u518c\u90e8\u7bc7\u96c6]\s*[\u96f6\u3007\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341\u767e\u5343\u4e07\u4e24\dIVXLCDMivxlcdm]+\s*(?:[\uff1a:._\-\u3001 ]\s*.*)?$',
      caseSensitive: false,
    ),
    RegExp(
      r'^\s*(?:chapter|chap\.)\s+(?:\d+|[ivxlcdm]+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b(?:[\uff1a:._\- ]\s*.*)?$',
      caseSensitive: false,
    ),
    RegExp(
      r'^\s*(?:volume|vol\.?|book|part)\s+(?:\d+|[ivxlcdm]+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b(?:[\uff1a:._\- ]\s*.*)?$',
      caseSensitive: false,
    ),
    RegExp(
      r'^\s*(?:volume|vol\.?|book|part)\s+(?:\d+|[ivxlcdm]+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b\s+(?:chapter|chap\.)\s+(?:\d+|[ivxlcdm]+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b(?:[\uff1a:._\- ]\s*.*)?$',
      caseSensitive: false,
    ),
    // "1.开局" / "1.2 Overview" yes; "5, he said" / "3.5 million people" no:
    // the text after the separator must not start with a lowercase word.
    RegExp(r'^\s*\d{1,4}[\u3001\uff0c.,:\uff1a\-]\s*(?![a-z]|\d+\s+[a-z])\S.+$'),
    // "12 终局" / "7 Rise, and Shine" yes; "3 days later, he left." no: the
    // title must not start with a lowercase ASCII letter and is capped at 30
    // chars. ponytail: a short capitalised sentence ("300 Spartans fought
    // bravely") is indistinguishable from a title by regex; add a
    // title-case check only if such lines show up in real books.
    RegExp(r'^\s*\d{1,4}\s+(?![a-z])\S.{0,29}$'),
  ];
  static final List<RegExp> _specialHeadingPatterns = [
    RegExp(
      r'^\s*(?:\u5e8f\u7ae0|\u5e8f\u8a00|\u524d\u8a00|\u7ec8\u7ae0|\u5c3e\u58f0|\u540e\u8bb0|\u9644\u5f55|\u756a\u5916(?:\u7bc7|\u7f16)?|\u5916\u4f20|\u95f4\u7ae0|\u5e55\u95f4|\u6954\u5b50|\u5f15\u5b50|\u7ec8\u5e55|\u7ec8\u66f2|\u540e\u65e5\u8c08|\u77ed\u7bc7|\u7279\u5178)(?:[\uff1a:._\-\u3001 ]\s*.*)?$',
    ),
    RegExp(
      r'^\s*(?:prologue|epilogue|afterword|interlude|side story|side-story|extra|extras|appendix|preface)(?:[\uff1a:._\- ]\s*.*)?$',
      caseSensitive: false,
    ),
  ];

  int _initialIndex = 0;
  final PaginationEstimateCalculator _paginationCalculator;

  TxtReaderEngine(
    this.book, {
    PaginationEstimateCalculator paginationCalculator =
        PaginationHelper.calculatePageEstimate,
  }) : _paginationCalculator = paginationCalculator {
    _itemPositionsListener.itemPositions.addListener(_updateCurrentPosition);
  }

  @override
  ReaderCapabilities get capabilities => _capabilities;

  void _updateCurrentPosition() {
    if (_disposed || _pendingRestore != null) return;
    if (_settledPixels != _scrollPosition?.pixels) _settledAnchor = null;
    _committedPosition = getCurrentPosition();
    _committedPixels = _scrollPosition?.pixels;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isNotEmpty) {
      int? minIndex;
      for (var pos in positions) {
        if (minIndex == null || pos.index < minIndex) {
          minIndex = pos.index;
        }
      }
      if (minIndex != null) {
        _initialIndex = minIndex;
      }
    }
  }

  _ViewportAnchor? _currentViewportAnchor() {
    if (_lineCount == 0) return null;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return null;

    final visible = positions
        .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1.0)
        .toList();
    final pool = visible.isNotEmpty
        ? visible
        : positions.where((p) => p.itemLeadingEdge > -0.5).toList();
    if (pool.isEmpty) return null;

    var topmost = pool.first;
    for (final p in pool) {
      if (p.itemLeadingEdge < topmost.itemLeadingEdge) {
        topmost = p;
      }
    }
    // At a scroll boundary the retained reading line can be below the top.
    // Keep that logical anchor while its restored scroll position is unchanged.
    if (_settledAnchor?.textOffset != null &&
        _settledPixels == _scrollPosition?.pixels) {
      for (final p in visible) {
        if (p.index == _settledAnchor!.paragraphIndex) {
          topmost = p;
          break;
        }
      }
    }
    return _ViewportAnchor(
      index: topmost.index.clamp(0, _lineCount - 1),
      leadingEdge: topmost.itemLeadingEdge,
      trailingEdge: topmost.itemTrailingEdge,
      scrollOffset: _scrollPosition?.pixels,
      viewportEpoch: _viewportEpoch,
    );
  }

  /// Paragraph index used for chapter title, page estimate, progress, and
  /// [getCurrentPosition] — must match the bottom bar (`_getCurrentChapterTitle`).
  ///
  /// Uses the **topmost** visible row: minimum [ItemPosition.itemLeadingEdge]
  /// among items that intersect the viewport. Sorting by paragraph index and
  /// taking the first match wrongly preferred a line from the **previous**
  /// chapter still visible near the bottom while the user was already reading
  /// headings at the top (off-by-one chapter in bar / TOC).
  int _viewportAnchorParagraphIndex() {
    if (_lineCount == 0) return 0;
    if (_pendingRestore != null) return _pendingRestore!.paragraphIndex!;
    return _currentViewportAnchor()?.index ??
        _initialIndex.clamp(0, _lineCount - 1);
  }

  @override
  Future<void> initialize() async {
    try {
      final bytes = await BookSourceAccess.readBytes(book);
      // Single compute hop does decode + line split + paragraph offsets +
      // chapter detection.  Previously only the byte decode was off-thread
      // and everything else ran on the UI isolate, which could lock the
      // main thread for seconds on 20MB+ novels.
      final parsed = await compute(_parseTxtInIsolate, bytes);
      _rawUtf8 = parsed.rawUtf8;
      _lineRanges = parsed.lineRanges;
      _lineCount = parsed.lineCount;
      _paragraphOffsets = parsed.paragraphOffsets;
      _totalTextLength = parsed.totalTextLength;
      _paginationSample = parsed.paginationSample;
      _chapters = List<ReaderChapter>.generate(
        parsed.chapterTitles.length,
        (i) => ReaderChapter(
          title: parsed.chapterTitles[i],
          index: i,
          // TXT chapter navigation jumps to the chapter's starting paragraph.
          locator:
              ChapterLocator(chapterIndex: parsed.chapterParagraphIndexes[i]),
        ),
        growable: false,
      );
      _isLoading = false;
    } catch (e) {
      throw FormatException('Failed to parse TXT file: $e');
    }
  }

  @override
  void setHighlights(List<Highlight> highlights) {
    _renderHighlights = List<Highlight>.unmodifiable(highlights);
    _highlightRenderVersion.value++;
  }

  @override
  String? getParagraphText(int paragraphIndex) {
    if (paragraphIndex < 0 || paragraphIndex >= _lineCount) return null;
    return _getLine(paragraphIndex).trim();
  }

  @override
  void setConfig(ReaderConfig config) {
    if (_config.fontSize != config.fontSize ||
        _config.lineHeight != config.lineHeight ||
        _config.useSerif != config.useSerif ||
        _config.pageTurnMode != config.pageTurnMode) {
      _invalidateViewportLayout(
          preservePaint: _config.fontSize == config.fontSize &&
              _config.lineHeight == config.lineHeight &&
              _config.useSerif == config.useSerif);
    }
    _config = config;
    final viewport = _viewportSize;
    final textScaler = _viewportTextScale;
    if (viewport != null && textScaler != null) {
      // A settings update can rebuild only the list and page bar, without
      // running the outer LayoutBuilder again at the same viewport size.
      unawaited(_recalculatePagination(viewport, textScaler));
    }
    _configNotifier.value = config;
  }

  @override
  double? getProgress() {
    if (_lineCount == 0 || _paragraphOffsets.length != _lineCount) return 0.0;
    final index = getCurrentPosition()?.paragraphIndex;
    if (index == null) return 0.0;
    // Offsets are strictly increasing, so a zero last offset means one line.
    final lastOffset = _paragraphOffsets[_lineCount - 1];
    if (lastOffset == 0) return 1.0;
    // Character-based so the percentage agrees with getCurrentPageIndex().
    // Divided by the last paragraph's start (not total length) so the scale
    // is exactly 0..1 and invertible. The anchor is the topmost visible
    // paragraph, so 1.0 is only reported when the last item is at the top.
    final clamped = index.clamp(0, _lineCount - 1);
    if (clamped == _lineCount - 1) return 1.0;
    // A short last paragraph can never reach the top, so also report the end
    // when scrolled to the bottom. The list can have a temporary scroll limit
    // before the tail is laid out, so confirm the last item is laid out and
    // visible. No upper bound on its trailing edge: at fractional DPRs it can
    // end slightly past the viewport (1.0004 at DPR 2.75) even at the true
    // end. Skipped during a restore: that viewport is temporary.
    final scroll = _scrollPosition;
    if (_pendingRestore == null &&
        scroll != null &&
        scroll.hasContentDimensions &&
        scroll.maxScrollExtent > scroll.minScrollExtent &&
        scroll.extentAfter == 0 &&
        _itemPositionsListener.itemPositions.value.any((item) =>
            item.index == _lineCount - 1 &&
            item.itemTrailingEdge > 0 &&
            item.itemLeadingEdge < 1)) {
      return 1.0;
    }
    // Labels round to whole percent; reserve 100% for the last paragraph so
    // "100%" never shows while text remains (same cap as EPUB).
    return (_paragraphOffsets[clamped] / lastOffset).clamp(0.0, .9949);
  }

  /// Greatest paragraph index whose start offset is <= [target].
  int _paragraphIndexForOffset(int target) {
    var lo = 0;
    var hi = _lineCount - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_paragraphOffsets[mid] <= target) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  @override
  void configureInteractions({
    ReaderTextHighlightCallback? onTextHighlighted,
    ReaderHighlightTapCallback? onHighlightTapped,
    ReaderContentTapCallback? onContentTap,
  }) {
    this.onTextHighlighted = onTextHighlighted;
    this.onHighlightTapped = onHighlightTapped;
    this.onContentTap = onContentTap;
  }

  @override
  Widget buildReader(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_lineCount == 0) {
      return Center(
        child: Text(AppLocalizations.of(context)!.readerNoContentLoaded),
      );
    }

    return _TxtViewport(
        key: ObjectKey(this),
        engine: this,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context);
            final locale = Localizations.maybeLocaleOf(context);
            final direction = Directionality.of(context);
            if (_viewportSize != constraints.biggest ||
                _viewportTextScale != scale ||
                _textLocale != locale ||
                _textDirection != direction) {
              _invalidateViewportLayout();
              _viewportSize = constraints.biggest;
              _viewportTextScale = scale;
              _textLocale = locale;
              _textDirection = direction;
            }
            // Not awaited: the estimate lands via _pageInfoNotifier when ready;
            // the helper defers its TextPainter work past this build frame and
            // re-validates the layout key on completion.
            unawaited(_recalculatePagination(constraints.biggest, scale));

            return Stack(
              children: [
                SizedBox.expand(
                  child: ValueListenableBuilder<ReaderConfig>(
                    valueListenable: _configNotifier,
                    builder: (context, config, child) {
                      return ValueListenableBuilder<int>(
                        valueListenable: _highlightRenderVersion,
                        builder: (context, _, __) {
                          return _buildList(context, config);
                        },
                      );
                    },
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder<ReaderConfig>(
                    valueListenable: _configNotifier,
                    builder: (context, config, child) {
                      return ValueListenableBuilder<int>(
                        valueListenable: _pageInfoNotifier,
                        builder: (context, _, __) {
                          return ValueListenableBuilder<Iterable<ItemPosition>>(
                            valueListenable:
                                _itemPositionsListener.itemPositions,
                            builder: (context, positions, _) {
                              if (!_isPaginationCalculated) {
                                return const SizedBox();
                              }
                              final progressPercent =
                                  (getProgress() ?? 0.0) * 100;
                              final page = getCurrentPageIndex() + 1;
                              final total = getPageCount();
                              String chapterTitle =
                                  normalizeChapterHeadingForDisplay(
                                _getCurrentChapterTitle(),
                              );
                              if (chapterTitle.isEmpty &&
                                  _chapters.isNotEmpty) {
                                chapterTitle =
                                    normalizeChapterHeadingForDisplay(
                                  _chapters.first.title,
                                );
                              }

                              return Container(
                                height: 20,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                color: config.backgroundColor,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${progressPercent.round()}%',
                                        textAlign: TextAlign.left,
                                        style: TextStyle(
                                          color: config.textColor
                                              .withValues(alpha: 0.6),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        chapterTitle,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: config.textColor
                                              .withValues(alpha: 0.6),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '$page / $total',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: config.textColor
                                              .withValues(alpha: 0.6),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ));
  }

  Widget _buildList(BuildContext context, ReaderConfig config) {
    return ScrollablePositionedList.builder(
      itemCount: _lineCount,
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      initialScrollIndex: _initialIndex,
      itemBuilder: (context, index) {
        final line = _getLine(index).trim();
        EdgeInsets itemPadding = const EdgeInsets.symmetric(horizontal: 24.0);

        if (index == 0) {
          itemPadding = itemPadding.copyWith(top: 16.0);
        }

        if (index == _lineCount - 1) {
          itemPadding = itemPadding.copyWith(bottom: 120.0);
        }

        final bottomMargin = config.fontSize * 0.6;
        itemPadding =
            itemPadding.copyWith(bottom: itemPadding.bottom + bottomMargin);

        if (line.isEmpty) {
          return SizedBox(height: bottomMargin);
        }

        final imageTag = tryParseTxtStandaloneImgTag(line);
        if (imageTag != null) {
          return _buildInlineImageBlock(
            context: context,
            imageTag: imageTag,
            config: config,
            padding: itemPadding,
            bottomMargin: bottomMargin,
          );
        }

        return HighlightableText(
          layoutAnchors: _textLayouts,
          text: line,
          paragraphIndex: index,
          highlights: _renderHighlights,
          style: TextStyle(
            fontSize: config.fontSize,
            height: config.lineHeight,
            color: config.textColor,
            // Use the user-selected font family rather than the hard-coded
            // 'Roboto' default; NyanTypography tokens resolve to registered
            // assets so the layout is deterministic across platforms.
            fontFamily: config.useSerif
                ? NyanTypography.readingSerifFontFamily
                : NyanTypography.uiFontFamily,
          ),
          backgroundColor: config.backgroundColor,
          padding: itemPadding,
          onTextSelected: (paragraphIdx, start, end, text, colorCode) {
            onTextHighlighted?.call(paragraphIdx, start, end, text, colorCode);
          },
          onHighlightTap: onHighlightTapped,
          onTap: onContentTap,
        );
      },
    );
  }

  Widget _buildInlineImageBlock({
    required BuildContext context,
    required TxtInlineImageTag imageTag,
    required ReaderConfig config,
    required EdgeInsets padding,
    required double bottomMargin,
  }) {
    final loc = AppLocalizations.of(context)!;
    final sourceUri =
        resolveTxtImageSourceUri(book: book, rawSrc: imageTag.src);
    final placeholderText =
        (imageTag.alt != null && imageTag.alt!.trim().isNotEmpty)
            ? imageTag.alt!.trim()
            : loc.readerImageDefaultAlt;

    Widget body;
    if (sourceUri == null) {
      body = _buildImageFallback(
        text: loc.readerImageUnavailable(placeholderText),
        config: config,
      );
    } else {
      body = _buildImageByUri(
        context: context,
        sourceUri: sourceUri,
        config: config,
        fallbackAlt: placeholderText,
      );
    }

    return Padding(
      padding: padding.copyWith(bottom: padding.bottom + bottomMargin),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => onContentTap?.call(details.globalPosition),
        child: body,
      ),
    );
  }

  Widget _buildImageByUri({
    required BuildContext context,
    required Uri sourceUri,
    required ReaderConfig config,
    required String fallbackAlt,
  }) {
    final loc = AppLocalizations.of(context)!;
    final provider = txtImageProviderFor(sourceUri);

    if (provider == null) {
      final isRemote =
          sourceUri.scheme == 'http' || sourceUri.scheme == 'https';
      return _buildImageFallback(
        text: isRemote
            ? loc.readerImageRemoteBlocked(fallbackAlt)
            : loc.readerImageUnsupportedSource(fallbackAlt),
        config: config,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 80,
          maxHeight: 360,
          minWidth: double.infinity,
        ),
        child: Image(
          image: provider,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildImageFallback(
              text: AppLocalizations.of(context)!
                  .readerImageLoadFailed(fallbackAlt),
              config: config,
            );
          },
        ),
      ),
    );
  }

  Widget _buildImageFallback({
    required String text,
    required ReaderConfig config,
  }) {
    return Container(
      alignment: Alignment.center,
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        border: Border.all(color: config.textColor.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: config.textColor.withValues(alpha: 0.7),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  @override
  Future<void> goToPosition(ReadingPosition position) async {
    final paragraphIndex = position.paragraphIndex;
    if (_disposed || paragraphIndex == null || _lineCount == 0) return;
    _clearTurnHistory();
    await _restorePosition(position);
  }

  @override
  Future<void> goToChapter(ChapterLocator locator) async {
    if (locator.chapterIndex != null) {
      await goToPosition(
        TxtReadingPosition(paragraphIndex: locator.chapterIndex!),
      );
    }
  }

  @override
  Future<void> seekToProgress(double progress) async {
    if (_lineCount == 0 || !progress.isFinite) return;
    // Inverse of getProgress(); both must use the same character scale or the
    // progress slider jumps after a drag.
    final target =
        (progress.clamp(0.0, 1.0) * _paragraphOffsets[_lineCount - 1]).round();
    var index = _paragraphIndexForOffset(target);
    // Nearest paragraph start, not floor: avoids the slider snapping back by
    // up to a whole paragraph when it is long.
    if (index + 1 < _lineCount &&
        _paragraphOffsets[index + 1] - target < target - _paragraphOffsets[index]) {
      index++;
    }
    await goToPosition(ReadingPosition(paragraphIndex: index));
  }

  @override
  ReadingPosition? getCurrentPosition() {
    // An accepted restore remains the logical position until its first layout
    // commits. Persistence must not observe the temporary paragraph start.
    if (_pendingRestore != null) return _pendingRestore;
    final anchor = _currentViewportAnchor();
    final position = TxtReadingPosition(
      paragraphIndex: anchor?.index ?? _viewportAnchorParagraphIndex(),
      paragraphLeadingEdge: anchor?.leadingEdge,
      paragraphTrailingEdge: anchor?.trailingEdge,
    );
    return TxtReadingPosition.fromPosition(_textLayouts.capture(
        position, _scrollPosition?.viewportDimension ?? 0,
        layoutIdentity: _layoutIdentity,
        preferredOffset: _settledPixels == _scrollPosition?.pixels &&
                _settledAnchor?.paragraphIndex == position.paragraphIndex
            ? _settledAnchor?.textOffset
            : null));
  }

  @override
  Future<String?> getSnippet() async {
    final pos = getCurrentPosition();
    final paragraphIndex = pos?.paragraphIndex;
    if (paragraphIndex != null && paragraphIndex < _lineCount) {
      return _getLine(paragraphIndex).trim();
    }
    return null;
  }

  @override
  Future<String?> getTextAtPosition(ReadingPosition position) async {
    final paragraphIndex = position.paragraphIndex;
    if (paragraphIndex != null && paragraphIndex < _lineCount) {
      return _getLine(paragraphIndex).trim();
    }
    return null;
  }

  @override
  Future<List<ReaderChapter>> getChapters() async {
    // Chapters are computed once in [_parseTxtInIsolate] during initialize()
    // and cached in [_chapters].  Returning them directly keeps the
    // TocManager from re-running the regex scan over every line.
    return _chapters;
  }

  String _getCurrentChapterTitle() {
    if (_chapters.isEmpty) return '';

    final paraIndex = _viewportAnchorParagraphIndex();

    for (int i = _chapters.length - 1; i >= 0; i--) {
      final chParaIndex = _chapters[i].locator.chapterIndex;
      if (chParaIndex != null && chParaIndex <= paraIndex) {
        return _chapters[i].title;
      }
    }
    return '';
  }

  @override
  Future<void> nextPage() => _turnPage(forward: true);

  @override
  Future<void> previousPage() => _turnPage(forward: false);

  Future<void> _turnPage({required bool forward}) async {
    final scroll = _scrollPosition;
    if (_disposed ||
        _pendingRestore != null ||
        scroll == null ||
        !scroll.hasContentDimensions ||
        !_itemScrollController.isAttached) {
      return;
    }
    // Even a boundary no-op supersedes an older in-flight turn.
    final serial = ++_navigationSerial;
    final before = _currentViewportAnchor();
    if (before == null) return;
    if (_turns.isNotEmpty &&
        !_turns.last.end.matches(before, scroll.viewportDimension)) {
      // Wheel input and external movement may not carry drag details.
      _clearTurnHistory();
    }
    final previous = !forward && _turns.isNotEmpty ? _turns.last : null;
    final positions = _itemPositionsListener.itemPositions.value.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    if (positions.isEmpty) return;
    final visible = positions
        .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1)
        .toList();
    final pool = visible.isNotEmpty ? visible : positions;
    final oversized = visible.length == 1 &&
        visible.single.itemTrailingEdge - visible.single.itemLeadingEdge >= 1;
    // Preserve the existing TXT distance policy: 92% inside oversized rows,
    // otherwise align the visible bottom/top row to the opposite viewport edge.
    final requested = previous?.start.scrollOffset ??
        (scroll.pixels +
            (oversized
                ? (forward ? .92 : -.92) * scroll.viewportDimension
                : ((forward ? pool.last : pool.first).itemLeadingEdge -
                        (forward ? 0 : 1)) *
                    scroll.viewportDimension));
    final target =
        requested.clamp(scroll.minScrollExtent, scroll.maxScrollExtent);
    if ((target - scroll.pixels).abs() < .01) {
      if (scroll.isScrollingNotifier.value) scroll.jumpTo(scroll.pixels);
      return;
    }
    if (_config.pageTurnMode == PageTurnMode.tap) {
      scroll.jumpTo(target);
    } else {
      await scroll.animateTo(target,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
    // ItemPositionsListener commits geometry after layout. Never record the
    // starting frame, nor a canceled animation that completed its Future.
    await WidgetsBinding.instance.endOfFrame;
    if (_disposed ||
        serial != _navigationSerial ||
        !identical(scroll, _scrollPosition)) {
      return;
    }
    final after = _currentViewportAnchor();
    if (after == null || (scroll.pixels - target).abs() > 2) {
      _clearTurnHistory();
      return;
    }
    if (previous != null) {
      _turns.removeLast();
    } else if (forward) {
      _turns.add(_TxtTurn(before, after));
      if (_turns.length > _historyLimit) _turns.removeAt(0);
    }
  }

  void _clearTurnHistory() => _turns.clear();

  void _interruptGesture() {
    _navigationSerial++;
    _settledAnchor = null;
    _clearTurnHistory();
    _pendingRestore = null;
    _applyingRestore = null;
    _restoreCover.value = false;
  }

  Future<void> _restorePosition(ReadingPosition position) async {
    if (_disposed || _lineCount == 0) return;
    final index = position.paragraphIndex!.clamp(0, _lineCount - 1);
    final leading = position.paragraphLeadingEdge;
    final trailing = position.paragraphTrailingEdge;
    final validEdges = index == position.paragraphIndex &&
        leading != null &&
        trailing != null &&
        leading.isFinite &&
        trailing.isFinite &&
        (trailing - leading).isFinite &&
        leading < 1 &&
        trailing > 0 &&
        trailing > leading;
    _navigationSerial++;
    _initialIndex = index;
    _pendingRestore = TxtReadingPosition(
        paragraphIndex: index,
        paragraphLeadingEdge: validEdges ? leading : null,
        textOffset:
            index == position.paragraphIndex ? position.textOffset : null,
        textViewportOffset: position.textViewportOffset,
        layoutIdentity: position.layoutIdentity,
        anchorVersion: position.anchorVersion,
        paragraphTrailingEdge: validEdges ? trailing : null);
    if (_scrollPosition == null || !_itemScrollController.isAttached) {
      _restoreCover.value = true;
      return;
    }
    await _applyPendingRestore();
  }

  Future<void> _applyPendingRestore() async {
    final target = _pendingRestore;
    final scroll = _scrollPosition;
    final serial = _navigationSerial;
    if (_disposed ||
        target == null ||
        scroll == null ||
        !_itemScrollController.isAttached ||
        _applyingRestore == serial) {
      return;
    }
    _applyingRestore = serial;
    _itemScrollController.jumpTo(index: target.paragraphIndex!);
    var offset = -(target.paragraphLeadingEdge ?? 0) * scroll.viewportDimension;
    if (target.anchorVersion == 1 &&
        target.textOffset != null &&
        target.layoutIdentity != _layoutIdentity) {
      await WidgetsBinding.instance.endOfFrame;
      if (_disposed || serial != _navigationSerial) return;
      offset =
          _textLayouts.restoreOffset(target, scroll.viewportDimension) ?? 0;
    }
    final destination = scroll.pixels + offset;
    if (destination.isFinite) scroll.jumpTo(destination);
    await WidgetsBinding.instance.endOfFrame;
    if (_disposed || serial != _navigationSerial) return;
    // jumpTo may start a boundary correction after the new extent is known.
    // Commit the anchor only after that correction has finished.
    while (scroll.isScrollingNotifier.value) {
      await WidgetsBinding.instance.endOfFrame;
      if (_disposed || serial != _navigationSerial) return;
    }
    _settledAnchor = target;
    _settledPixels = scroll.pixels;
    _pendingRestore = null;
    _applyingRestore = null;
    _restoreCover.value = false;
    _updateCurrentPosition();
  }

  void _attachScrollPosition(ScrollPosition position) {
    if (_disposed) return;
    if (_scrollPosition != null && !identical(_scrollPosition, position)) {
      _detachViewport();
    }
    _scrollPosition = position;
    if (_pendingRestore != null) {
      // Metrics arrive after layout; the pending target stays authoritative
      // until the restored viewport has committed its next frame.
      unawaited(_applyPendingRestore());
    }
  }

  void _detachViewport() {
    _clearTurnHistory();
    _scrollPosition = null;
    _navigationSerial++;
    _viewportEpoch++;
    _applyingRestore = null;
  }

  void _invalidateViewportLayout({bool preservePaint = false}) {
    if (_scrollPosition != null) {
      _pendingRestore ??= _committedPixels == _scrollPosition?.pixels
          ? (_committedPosition ?? getCurrentPosition())
          : getCurrentPosition();
      _initialIndex = _pendingRestore?.paragraphIndex ?? _initialIndex;
      if (!preservePaint && _pendingRestore?.textOffset != null) {
        _restoreCover.value = true;
      }
    }
    _clearTurnHistory();
    _viewportEpoch++;
    final serial = ++_navigationSerial;
    _applyingRestore = null;
    // Targets accepted before mounting remain authoritative until attachment.
    if (_scrollPosition == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || serial != _navigationSerial) return;
      final scroll = _scrollPosition;
      if (scroll == null) return;
      // Cancel an old driven scroll after the new layout, before it can keep
      // applying a pixel destination derived from the previous geometry.
      scroll.jumpTo(scroll.pixels);
      if (_pendingRestore != null) {
        // This callback owns completion of the accepted pending restore.
        unawaited(_applyPendingRestore());
      }
    });
  }

  Future<void> _recalculatePagination(Size size, TextScaler textScaler) async {
    if (_disposed || _paginationSample.isEmpty || _totalTextLength == 0) {
      return;
    }

    // Inter-paragraph spacing added by _buildList to every list item.
    final double paragraphBottomMargin = _config.fontSize * 0.6;

    final paginationKey = _PaginationLayoutKey(
      viewportSize: size,
      fontSize: _config.fontSize,
      fontFamily: _config.useSerif
          ? NyanTypography.readingSerifFontFamily
          : NyanTypography.uiFontFamily,
      lineHeight: _config.lineHeight,
      padding: _paginationPadding,
      orientation: size.width >= size.height
          ? Orientation.landscape
          : Orientation.portrait,
      scaledFontSize: textScaler.scale(_config.fontSize),
      paragraphBottomMargin: paragraphBottomMargin,
    );
    // A -> B -> A can reuse A's pending result only if A is recorded as the
    // requested layout before checking for work already in flight.
    _requestedPaginationKey = paginationKey;
    if (_isPaginationCalculated ||
        !_inFlightPaginationKeys.add(paginationKey)) {
      return;
    }

    // Pagination must use the same font family the reader will render with;
    // use the values from the key so estimation and deduplication agree.
    final style = TextStyle(
      fontSize: paginationKey.fontSize,
      height: paginationKey.lineHeight,
      fontFamily: paginationKey.fontFamily,
    );

    try {
      // The pagination estimator only needs: (a) a small sample of text
      // to run a single TextPainter layout on, and (b) the total length
      // of the book to extrapolate.  Previously the full content string
      // was handed in as `text` solely so that `text.length` matched the
      // book size - that pinned a second copy of the decoded file in
      // memory for the life of the reader session.
      final result = await _paginationCalculator(
        text: _paginationSample,
        style: style,
        maxWidth: size.width,
        maxHeight: size.height,
        padding: _paginationPadding,
        textScaler: textScaler,
        paragraphBottomMargin: paragraphBottomMargin,
        totalTextLength: _totalTextLength,
      );

      if (_disposed || _requestedPaginationKey != paginationKey) return;

      _totalPages = result[0];
      _charsPerPage = result[1];
      _estimatedPaginationKey = paginationKey;
      _pageInfoNotifier.value++;
    } catch (e) {
      debugPrint('Pagination error: $e');
    } finally {
      _inFlightPaginationKeys.remove(paginationKey);
    }
  }

  @override
  int getPageCount() => _totalPages;

  @override
  int getCurrentPageIndex() {
    if (_paragraphOffsets.isEmpty) return 0;

    final paraIndex = _viewportAnchorParagraphIndex();

    if (paraIndex >= _paragraphOffsets.length) return 0;

    final charIndex = _paragraphOffsets[paraIndex];
    int pageIndex = (charIndex / _charsPerPage).floor();

    if (pageIndex < 0) pageIndex = 0;
    if (pageIndex >= _totalPages) pageIndex = _totalPages - 1;

    return pageIndex;
  }

  @override
  bool get hasBottomBar => true;

  @override
  void dispose() {
    _disposed = true;
    _detachViewport();
    _restoreCover.dispose();
    _itemPositionsListener.itemPositions.removeListener(_updateCurrentPosition);
    _configNotifier.dispose();
    _highlightRenderVersion.dispose();
    _pageInfoNotifier.dispose();
  }
}

class _PaginationLayoutKey {
  const _PaginationLayoutKey({
    required this.viewportSize,
    required this.fontSize,
    required this.fontFamily,
    required this.lineHeight,
    required this.padding,
    required this.orientation,
    required this.scaledFontSize,
    required this.paragraphBottomMargin,
  });

  final Size viewportSize;
  final double fontSize;
  final String fontFamily;
  final double lineHeight;
  final EdgeInsets padding;
  final Orientation orientation;

  /// The estimator lays out one TextStyle at this effective font size.
  final double scaledFontSize;

  /// Inter-paragraph spacing used by the list renderer (`fontSize * 0.6`).
  final double paragraphBottomMargin;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _PaginationLayoutKey &&
        other.viewportSize == viewportSize &&
        other.fontSize == fontSize &&
        other.fontFamily == fontFamily &&
        other.lineHeight == lineHeight &&
        other.padding == padding &&
        other.orientation == orientation &&
        other.scaledFontSize == scaledFontSize &&
        other.paragraphBottomMargin == paragraphBottomMargin;
  }

  @override
  int get hashCode => Object.hash(
        viewportSize,
        fontSize,
        fontFamily,
        lineHeight,
        padding,
        orientation,
        scaledFontSize,
        paragraphBottomMargin,
      );

  @override
  String toString() {
    return '_PaginationLayoutKey('
        'viewportSize: $viewportSize, '
        'fontSize: $fontSize, '
        'fontFamily: $fontFamily, '
        'lineHeight: $lineHeight, '
        'padding: $padding, '
        'orientation: $orientation, '
        'scaledFontSize: $scaledFontSize, '
        'paragraphBottomMargin: $paragraphBottomMargin'
        ')';
  }
}

class _ViewportAnchor {
  const _ViewportAnchor({
    required this.index,
    required this.leadingEdge,
    required this.trailingEdge,
    this.scrollOffset,
    this.viewportEpoch,
  });

  final int index;
  final double leadingEdge;
  final double trailingEdge;
  final double? scrollOffset;
  final int? viewportEpoch;

  bool matches(_ViewportAnchor other, double height) =>
      index == other.index &&
      viewportEpoch == other.viewportEpoch &&
      scrollOffset != null &&
      other.scrollOffset != null &&
      (scrollOffset! - other.scrollOffset!).abs() <= 2 &&
      (leadingEdge - other.leadingEdge).abs() * height <= 2 &&
      (trailingEdge - other.trailingEdge).abs() * height <= 2;
}

class _TxtTurn {
  const _TxtTurn(this.start, this.end);
  final _ViewportAnchor start;
  final _ViewportAnchor end;
}

// Lifecycle and public Scrollable context belong to the rendered viewport;
// navigation targets and the authoritative reading position stay in the engine.
class _TxtViewport extends StatefulWidget {
  const _TxtViewport({super.key, required this.engine, required this.child});
  final TxtReaderEngine engine;
  final Widget child;

  @override
  State<_TxtViewport> createState() => _TxtViewportState();
}

class _TxtViewportState extends State<_TxtViewport> {
  @override
  void dispose() {
    widget.engine._detachViewport();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 &&
              ((notification is ScrollStartNotification &&
                      notification.dragDetails != null) ||
                  (notification is UserScrollNotification &&
                      notification.direction != ScrollDirection.idle))) {
            widget.engine._interruptGesture();
          }
          return false;
        },
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            final context = notification.context;
            if (notification.depth == 0) {
              final scrollable = Scrollable.maybeOf(context);
              if (scrollable != null) {
                widget.engine._attachScrollPosition(scrollable.position);
              }
            }
            return false;
          },
          child: RestoreVisibility(
              covered: widget.engine._restoreCover, child: widget.child),
        ),
      );
}
