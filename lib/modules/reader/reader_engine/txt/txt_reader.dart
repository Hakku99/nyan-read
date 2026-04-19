import 'dart:convert';
import 'dart:typed_data';

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
});

class TxtReaderEngine
    implements
        ReaderEngine,
        TextReaderCapability,
        TextExtractionCapability,
        PageMetricsCapability {
  static const ReaderCapabilities _capabilities = ReaderCapabilities(
    supportsTypography: true,
    supportsTheme: true,
    supportsHighlights: true,
    supportsAnnotations: true,
    supportsPageAnimation: false,
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

  String _fullContent = '';
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
      final content = await compute(_decodeBytes, bytes);
      _fullContent = content;
      _lines = content.split('\n');

      _paragraphOffsets = List<int>.filled(_lines.length, 0);
      int currentOffset = 0;
      for (int i = 0; i < _lines.length; i++) {
        _paragraphOffsets[i] = currentOffset;
        currentOffset += _lines[i].length + 1;
      }

      _chapters = await getChapters();
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

  static String _decodeBytes(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      debugPrint('TXT Reader: UTF-8 decoding failed, trying GBK...');
      try {
        return gbk.decode(bytes);
      } catch (_) {
        debugPrint('TXT Reader: GBK decoding failed, trying Latin1...');
        return latin1.decode(bytes);
      }
    }
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
    debugPrint(
      'DEBUG: TxtReader.buildReader called - isLoading=$_isLoading, lines=${_lines.length}',
    );

    if (_isLoading) {
      debugPrint('DEBUG: Returning loading indicator');
      return const Center(child: CircularProgressIndicator());
    }

    if (_lines.isEmpty) {
      debugPrint('DEBUG: Lines is empty! Returning error message');
      return const Center(child: Text('No content loaded'));
    }

    debugPrint(
      'DEBUG: Building ValueListenableBuilder with ${_lines.length} lines',
    );

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
                      debugPrint(
                        'DEBUG: ValueListenableBuilder building with config: fontSize=${config.fontSize}, bg=${config.backgroundColor}, highlights=${_renderHighlights.length}',
                      );
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
                                      color: config.textColor.withOpacity(0.6),
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
                                      color: config.textColor.withOpacity(0.6),
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '$page / $total',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: config.textColor.withOpacity(0.6),
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
    debugPrint(
      'DEBUG: _buildList called - initialIndex=$_initialIndex, hasRestored=$_hasRestoredPosition',
    );

    if (_initialIndex > 0 && !_hasRestoredPosition) {
      _hasRestoredPosition = true;
      debugPrint(
          'DEBUG: Scheduling position restoration to index $_initialIndex');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint(
          'DEBUG: PostFrameCallback executing - isAttached=${_itemScrollController.isAttached}',
        );
        if (_itemScrollController.isAttached) {
          _itemScrollController.jumpTo(index: _initialIndex);
          debugPrint('DEBUG: Jumped to index $_initialIndex');
        }
      });
    }

    debugPrint(
      'DEBUG: Creating ScrollablePositionedList with ${_lines.length} items',
    );

    return ScrollablePositionedList.builder(
      itemCount: _lines.length,
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      initialScrollIndex: _initialIndex,
      itemBuilder: (context, index) {
        if (index < 5) {
          debugPrint('DEBUG: itemBuilder called for index $index');
        }

        final line = _lines[index].trim();
        EdgeInsets itemPadding = const EdgeInsets.symmetric(horizontal: 24.0);

        if (index == 0) {
          itemPadding = itemPadding.copyWith(top: 16.0);
          debugPrint(
            "DEBUG: First item - line='${line.length > 20 ? line.substring(0, 20) : line}...', textColor=${config.textColor}, bgColor=${config.backgroundColor}",
          );
        }

        if (index == _lines.length - 1) {
          itemPadding = itemPadding.copyWith(bottom: 120.0);
        }

        final bottomMargin = config.fontSize * 0.6;
        itemPadding =
            itemPadding.copyWith(bottom: itemPadding.bottom + bottomMargin);

        if (line.isEmpty) {
          if (index < 5) debugPrint('DEBUG: Item $index is empty line');
          return SizedBox(height: bottomMargin);
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

  bool _looksLikeNarrativeLine(String line) {
    if (line.length > 72 && RegExp(r'[\u3002\uff01\uff1f!?\uff1b;]').hasMatch(line)) {
      return true;
    }
    return false;
  }

  Iterable<String> _chapterHeadingCandidates(String line) sync* {
    final normalized = line.trim().replaceAll('\u3000', ' ');
    if (normalized.isEmpty) {
      return;
    }

    final collapsedWhitespace = normalized.replaceAll(RegExp(r'\s+'), ' ');
    yield collapsedWhitespace;

    final strippedLeadingTag = collapsedWhitespace
        .replaceFirst(
          RegExp(r'^[\[\(\uff08\u3010\u300a\u300c\u300e\u3014\u3008].{1,20}[\]\)\uff09\u3011\u300b\u300d\u300f\u3015\u3009]\s*'),
          '',
        )
        .trim();
    if (strippedLeadingTag.isNotEmpty &&
        strippedLeadingTag != collapsedWhitespace) {
      yield strippedLeadingTag;
    }

    final unwrapped = collapsedWhitespace
        .replaceFirst(RegExp(r'^[\[\(\uff08\u3010\u300a\u300c\u300e\u3014\u3008]'), '')
        .replaceFirst(RegExp(r'[\]\)\uff09\u3011\u300b\u300d\u300f\u3015\u3009]$'), '')
        .trim();
    if (unwrapped.isNotEmpty && unwrapped != collapsedWhitespace) {
      yield unwrapped;
    }
  }

  bool _looksLikeChapterHeading(String line) {
    for (final candidate in _chapterHeadingCandidates(line)) {
      if (candidate.isEmpty || candidate.length > 80) {
        continue;
      }
      if (_looksLikeNarrativeLine(candidate)) {
        continue;
      }

      for (final pattern in _chapterHeadingPatterns) {
        if (pattern.hasMatch(candidate)) {
          return true;
        }
      }

      for (final pattern in _specialHeadingPatterns) {
        if (pattern.hasMatch(candidate)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isStandaloneNumericHeading(String line) {
    return RegExp(
      r'^\s*(?:\d{1,4}|[IVXLCDMivxlcdm]{1,8}|[\u96f6\u3007\u4e00\u4e8c\u4e09\u56db\u4e94\u516d\u4e03\u516b\u4e5d\u5341\u767e\u5343\u4e07\u4e24]{1,8})\s*$',
    ).hasMatch(line);
  }

  String? _nextNonEmptyLine(int startIndex) {
    for (int i = startIndex; i < _lines.length; i++) {
      final candidate = _lines[i].trim();
      if (candidate.isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  bool _looksLikeChapterSubtitle(String line) {
    final normalized = line.trim();
    if (normalized.isEmpty || normalized.length > 40) {
      return false;
    }
    return !_looksLikeNarrativeLine(normalized);
  }

  @override
  Future<List<ReaderChapter>> getChapters() async {
    if (_lines.isEmpty) return [];

    final chapters = <ReaderChapter>[];
    int chapterIndex = 0;
    for (int i = 0; i < _lines.length; i++) {
      final line = _lines[i].trim();
      if (line.isEmpty) continue;

      var isChapter = _looksLikeChapterHeading(line);
      if (!isChapter && _isStandaloneNumericHeading(line)) {
        final nextLine = _nextNonEmptyLine(i + 1);
        isChapter = nextLine == null ||
            (_looksLikeChapterSubtitle(nextLine) &&
                !_looksLikeChapterHeading(nextLine));
      }

      if (isChapter) {
        chapters.add(
          ReaderChapter(
            title: line,
            index: chapterIndex,
            // TXT chapter navigation jumps to the chapter's starting paragraph.
            locator: ChapterLocator(chapterIndex: i),
          ),
        );
        chapterIndex++;
      }
    }

    return chapters;
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
    if (_fullContent.isEmpty) return;

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
    if (_inFlightPaginationKeys.contains(paginationKey)) {
      debugPrint(
        'Skipping duplicate pagination request for in-flight key: '
        '$paginationKey',
      );
      return;
    }

    _lastPaginationKey = paginationKey;
    _inFlightPaginationKeys.add(paginationKey);
    _isPaginationCalculated = false;
    debugPrint('Recalculating pagination for key: $paginationKey');

    final style = TextStyle(
      fontSize: _config.fontSize,
      height: _config.lineHeight,
      fontFamily: 'Roboto',
    );

    try {
      final result = await _paginationCalculator(
        text: _fullContent,
        style: style,
        maxWidth: size.width,
        maxHeight: size.height,
        padding: _paginationPadding,
      );

      if (_lastPaginationKey != paginationKey) {
        debugPrint(
          'Pagination calculation discarded: layout changed from '
          '$paginationKey to $_lastPaginationKey',
        );
        _inFlightPaginationKeys.remove(paginationKey);
        return;
      }

      _totalPages = result[0];
      _charsPerPage = result[1];
      _isPaginationCalculated = true;
      _inFlightPaginationKeys.remove(paginationKey);
      _pageInfoNotifier.value++;
      debugPrint(
        'Pagination calculated: $_totalPages pages, $_charsPerPage chars/page',
      );
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
