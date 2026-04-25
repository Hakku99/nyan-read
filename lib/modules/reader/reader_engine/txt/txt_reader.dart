import 'dart:convert';
import 'dart:io';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../core/models/book.dart';
import '../../../../core/utils/chapter_heading_display.dart';
import '../../../../core/models/highlight.dart';
import '../../../../core/utils/book_source_access.dart';
import '../../widgets/highlightable_text.dart';
import '../reader_engine.dart';
import 'pagination_helper.dart';
import 'txt_position.dart';

typedef PaginationEstimateCalculator = Future<List<int>> Function({
  required String text,
  required TextStyle style,
  required double maxWidth,
  required double maxHeight,
  required EdgeInsets padding,
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
    required this.lines,
    required this.paragraphOffsets,
    required this.totalTextLength,
    required this.paginationSample,
    required this.chapterTitles,
    required this.chapterParagraphIndexes,
  });

  final List<String> lines;
  final List<int> paragraphOffsets;
  final int totalTextLength;
  final String paginationSample;
  final List<String> chapterTitles;
  final List<int> chapterParagraphIndexes;
}

_TxtParseResult _parseTxtInIsolate(Uint8List bytes) {
  final content = _decodeBytesForParse(bytes);
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
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

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

  return _TxtParseResult(
    lines: lines,
    paragraphOffsets: offsets,
    totalTextLength: totalLength,
    paginationSample: paginationSample,
    chapterTitles: titles,
    chapterParagraphIndexes: indexes,
  );
}

String _decodeBytesForParse(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } catch (_) {
    try {
      return gbk.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }
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

  if (book.sourceType != BookSourceType.filePath || book.sourceLocator.isEmpty) {
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
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  List<String> _lines = [];
  bool _isLoading = true;
  String? _error;

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
  bool _isPaginationCalculated = false;
  _PaginationLayoutKey? _lastPaginationKey;
  final Set<_PaginationLayoutKey> _inFlightPaginationKeys =
      <_PaginationLayoutKey>{};
  final ValueNotifier<int> _pageInfoNotifier = ValueNotifier(0);

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
    RegExp(r'^\s*\d{1,4}[\u3001\uff0c.,:\uff1a\-]\s*\S.+$'),
    RegExp(r'^\s*\d{1,4}\s+\S.+$'),
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
  bool _hasRestoredPosition = false;
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

  /// Paragraph index used for chapter title, page estimate, progress, and
  /// [getCurrentPosition] — must match the bottom bar (`_getCurrentChapterTitle`).
  ///
  /// Uses the **topmost** visible row: minimum [ItemPosition.itemLeadingEdge]
  /// among items that intersect the viewport. Sorting by paragraph index and
  /// taking the first match wrongly preferred a line from the **previous**
  /// chapter still visible near the bottom while the user was already reading
  /// headings at the top (off-by-one chapter in bar / TOC).
  int _viewportAnchorParagraphIndex() {
    if (_lines.isEmpty) return 0;

    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) {
      return _initialIndex.clamp(0, _lines.length - 1);
    }

    final visible = positions
        .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1.0)
        .toList();
    final pool = visible.isNotEmpty
        ? visible
        : positions.where((p) => p.itemLeadingEdge > -0.5).toList();
    if (pool.isEmpty) {
      return _initialIndex.clamp(0, _lines.length - 1);
    }

    var topmost = pool.first;
    for (final p in pool) {
      if (p.itemLeadingEdge < topmost.itemLeadingEdge) {
        topmost = p;
      }
    }
    return topmost.index.clamp(0, _lines.length - 1);
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
      _lines = parsed.lines;
      _paragraphOffsets = parsed.paragraphOffsets;
      _totalTextLength = parsed.totalTextLength;
      _paginationSample = parsed.paginationSample;
      _chapters = List<ReaderChapter>.generate(
        parsed.chapterTitles.length,
        (i) => ReaderChapter(
          title: parsed.chapterTitles[i],
          index: i,
          // TXT chapter navigation jumps to the chapter's starting paragraph.
          locator: ChapterLocator(chapterIndex: parsed.chapterParagraphIndexes[i]),
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
    if (paragraphIndex < 0 || paragraphIndex >= _lines.length) return null;
    return _lines[paragraphIndex].trim();
  }

  @override
  void setConfig(ReaderConfig config) {
    _config = config;
    _configNotifier.value = config;
  }

  @override
  double? getProgress() {
    if (_lines.isEmpty) return 0.0;
    final pos = getCurrentPosition();
    if (pos?.paragraphIndex != null) {
      return pos!.paragraphIndex! / _lines.length;
    }
    return 0.0;
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

    if (_lines.isEmpty) {
      return const Center(child: Text('No content loaded'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _recalculatePagination(constraints.biggest);

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
                        valueListenable: _itemPositionsListener.itemPositions,
                        builder: (context, positions, _) {
                          if (!_isPaginationCalculated) {
                            return const SizedBox();
                          }
                          final progressPercent = (getProgress() ?? 0.0) * 100;
                          final page = getCurrentPageIndex() + 1;
                          final total = getPageCount();
                          String chapterTitle = normalizeChapterHeadingForDisplay(
                            _getCurrentChapterTitle(),
                          );
                          if (chapterTitle.isEmpty && _chapters.isNotEmpty) {
                            chapterTitle = normalizeChapterHeadingForDisplay(
                              _chapters.first.title,
                            );
                          }

                          return Container(
                            height: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            color: config.backgroundColor,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${progressPercent.toInt()}%',
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      color: config.textColor.withValues(alpha: 0.6),
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
                                      color: config.textColor.withValues(alpha: 0.6),
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '$page / $total',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: config.textColor.withValues(alpha: 0.6),
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
    );
  }

  Widget _buildList(BuildContext context, ReaderConfig config) {
    if (_initialIndex > 0 && !_hasRestoredPosition) {
      _hasRestoredPosition = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_itemScrollController.isAttached) {
          _itemScrollController.jumpTo(index: _initialIndex);
        }
      });
    }

    return ScrollablePositionedList.builder(
      itemCount: _lines.length,
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      initialScrollIndex: _initialIndex,
      itemBuilder: (context, index) {
        final line = _lines[index].trim();
        EdgeInsets itemPadding = const EdgeInsets.symmetric(horizontal: 24.0);

        if (index == 0) {
          itemPadding = itemPadding.copyWith(top: 16.0);
        }

        if (index == _lines.length - 1) {
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
          text: line,
          paragraphIndex: index,
          highlights: _renderHighlights,
          style: TextStyle(
            fontSize: config.fontSize,
            height: config.lineHeight,
            color: config.textColor,
            fontFamily: 'Roboto',
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
    final sourceUri = resolveTxtImageSourceUri(book: book, rawSrc: imageTag.src);
    final placeholderText =
        (imageTag.alt != null && imageTag.alt!.trim().isNotEmpty)
            ? imageTag.alt!.trim()
            : 'Image';

    Widget body;
    if (sourceUri == null) {
      body = _buildImageFallback(
        text: '[$placeholderText unavailable]',
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
    ImageProvider<Object>? provider;
    if (sourceUri.scheme == 'http' || sourceUri.scheme == 'https') {
      provider = NetworkImage(sourceUri.toString());
    } else if (sourceUri.scheme == 'file' || sourceUri.scheme.isEmpty) {
      provider = FileImage(File.fromUri(sourceUri));
    } else if (sourceUri.scheme == 'data') {
      try {
        final uriData = UriData.parse(sourceUri.toString());
        final bytes = uriData.contentAsBytes();
        if (bytes.isNotEmpty) {
          provider = MemoryImage(bytes);
        }
      } on FormatException {
        provider = null;
      }
    }

    if (provider == null) {
      return _buildImageFallback(
        text: '[$fallbackAlt unsupported source]',
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
              text: '[$fallbackAlt load failed]',
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
    if (paragraphIndex == null) {
      return;
    }

    if (_itemScrollController.isAttached) {
      _itemScrollController.jumpTo(
        index: paragraphIndex,
        alignment: 0.0,
      );
    } else {
      _initialIndex = paragraphIndex;
      _hasRestoredPosition = false;
    }
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
    if (_lines.isEmpty) return;
    final index = (progress * (_lines.length - 1)).round();

    if (_itemScrollController.isAttached) {
      _itemScrollController.jumpTo(index: index);
    } else {
      _initialIndex = index;
    }
  }

  @override
  ReadingPosition? getCurrentPosition() {
    return TxtReadingPosition(paragraphIndex: _viewportAnchorParagraphIndex());
  }

  @override
  Future<String?> getSnippet() async {
    final pos = getCurrentPosition();
    final paragraphIndex = pos?.paragraphIndex;
    if (paragraphIndex != null && paragraphIndex < _lines.length) {
      return _lines[paragraphIndex].trim();
    }
    return null;
  }

  @override
  Future<String?> getTextAtPosition(ReadingPosition position) async {
    final paragraphIndex = position.paragraphIndex;
    if (paragraphIndex != null && paragraphIndex < _lines.length) {
      return _lines[paragraphIndex].trim();
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
  Future<void> nextPage() async {
    final positions = _itemPositionsListener.itemPositions.value.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    if (positions.isEmpty) {
      _initialIndex = (_initialIndex + 20).clamp(0, _lines.length - 1);
      return;
    }

    final first = positions.first;
    final last = positions.last;

    if (first.index == last.index) {
      final leading = first.itemLeadingEdge;
      final trailing = first.itemTrailingEdge;
      final ratio = trailing - leading;

      if (ratio > 1.0 && trailing > 1.0) {
        final targetLeading = leading - 0.9;

        if (targetLeading > (1.0 - ratio)) {
          final align = targetLeading / (1.0 - ratio);
          if (_itemScrollController.isAttached) {
            await _itemScrollController.scrollTo(
              index: first.index,
              alignment: align,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
          return;
        }
      }
    }

    var targetIndex = last.index;
    if (targetIndex == first.index && positions.length > 1) {
      targetIndex++;
    }

    if (_itemScrollController.isAttached) {
      await _itemScrollController.scrollTo(
        index: targetIndex.clamp(0, _lines.length - 1),
        alignment: 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Future<void> previousPage() async {
    final positions = _itemPositionsListener.itemPositions.value.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    if (positions.isEmpty) {
      _initialIndex = (_initialIndex - 20).clamp(0, _lines.length - 1);
      return;
    }

    final first = positions.first;
    final last = positions.last;

    if (first.index == last.index) {
      final leading = first.itemLeadingEdge;
      final trailing = first.itemTrailingEdge;
      final ratio = trailing - leading;

      if (ratio > 1.0 && leading < 0.0) {
        final targetLeading = leading + 0.9;

        if (targetLeading < 0.0) {
          final align = targetLeading / (1.0 - ratio);
          if (_itemScrollController.isAttached) {
            await _itemScrollController.scrollTo(
              index: first.index,
              alignment: align,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
          return;
        }
      }
    }

    final targetIndex = first.index;

    if (_itemScrollController.isAttached) {
      await _itemScrollController.scrollTo(
        index: targetIndex.clamp(0, _lines.length - 1),
        alignment: 1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _recalculatePagination(Size size) async {
    if (_paginationSample.isEmpty || _totalTextLength == 0) return;

    final paginationKey = _PaginationLayoutKey(
      viewportSize: size,
      fontSize: _config.fontSize,
      lineHeight: _config.lineHeight,
      padding: _paginationPadding,
      orientation: size.width >= size.height
          ? Orientation.landscape
          : Orientation.portrait,
    );
    if (_lastPaginationKey == paginationKey && _isPaginationCalculated) return;
    if (_inFlightPaginationKeys.contains(paginationKey)) return;

    _lastPaginationKey = paginationKey;
    _inFlightPaginationKeys.add(paginationKey);
    _isPaginationCalculated = false;

    final style = TextStyle(
      fontSize: _config.fontSize,
      height: _config.lineHeight,
      fontFamily: 'Roboto',
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
        totalTextLength: _totalTextLength,
      );

      if (_lastPaginationKey != paginationKey) {
        _inFlightPaginationKeys.remove(paginationKey);
        return;
      }

      _totalPages = result[0];
      _charsPerPage = result[1];
      _isPaginationCalculated = true;
      _inFlightPaginationKeys.remove(paginationKey);
      _pageInfoNotifier.value++;
    } catch (e) {
      _inFlightPaginationKeys.remove(paginationKey);
      debugPrint('Pagination error: $e');
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
    required this.lineHeight,
    required this.padding,
    required this.orientation,
  });

  final Size viewportSize;
  final double fontSize;
  final double lineHeight;
  final EdgeInsets padding;
  final Orientation orientation;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _PaginationLayoutKey &&
        other.viewportSize == viewportSize &&
        other.fontSize == fontSize &&
        other.lineHeight == lineHeight &&
        other.padding == padding &&
        other.orientation == orientation;
  }

  @override
  int get hashCode => Object.hash(
        viewportSize,
        fontSize,
        lineHeight,
        padding,
        orientation,
      );

  @override
  String toString() {
    return '_PaginationLayoutKey('
        'viewportSize: $viewportSize, '
        'fontSize: $fontSize, '
        'lineHeight: $lineHeight, '
        'padding: $padding, '
        'orientation: $orientation'
        ')';
  }
}
