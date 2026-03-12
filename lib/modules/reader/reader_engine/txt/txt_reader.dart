import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../core/models/book.dart';
import '../../../../core/models/highlight.dart';
import '../../../../core/utils/book_source_access.dart';
import '../../widgets/highlightable_text.dart';
import '../reader_engine.dart';
import 'pagination_helper.dart';
import 'txt_position.dart';

class TxtReaderEngine implements ReaderEngine {
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
  final ValueNotifier<int> _pageInfoNotifier = ValueNotifier(0);

  List<Map<String, dynamic>> _chapters = [];

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

  int _initialIndex = 0;
  bool _hasRestoredPosition = false;

  TxtReaderEngine(this.book) {
    _itemPositionsListener.itemPositions.addListener(_updateCurrentPosition);
  }

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

      final rawChapters = await getChapters();
      _chapters = rawChapters.cast<Map<String, dynamic>>();
      _isLoading = false;
    } catch (e) {
      throw FormatException('Failed to parse TXT file: $e');
    }
  }

  void setHighlights(List<Highlight> highlights) {
    _renderHighlights = List<Highlight>.unmodifiable(highlights);
    _highlightRenderVersion.value++;
  }

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
    if (pos is TxtReadingPosition) {
      return pos.paragraphIndex / _lines.length;
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
                          String chapterTitle = _getCurrentChapterTitle();
                          if (chapterTitle.isEmpty && _chapters.isNotEmpty) {
                            chapterTitle = _chapters.first['title'] as String;
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
    if (position is TxtReadingPosition) {
      if (_itemScrollController.isAttached) {
        _itemScrollController.jumpTo(
          index: position.paragraphIndex,
          alignment: 0.0,
        );
      } else {
        _initialIndex = position.paragraphIndex;
        _hasRestoredPosition = false;
      }
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
    if (!_itemPositionsListener.itemPositions.value.isNotEmpty) {
      return TxtReadingPosition(paragraphIndex: _initialIndex);
    }

    final positions = _itemPositionsListener.itemPositions.value.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    if (positions.isEmpty) {
      return TxtReadingPosition(paragraphIndex: _initialIndex);
    }

    ItemPosition? candidate = positions.first;
    for (final pos in positions) {
      if (pos.itemLeadingEdge >= -0.05) {
        candidate = pos;
        break;
      }
    }

    return TxtReadingPosition(paragraphIndex: candidate!.index);
  }

  @override
  Future<String?> getSnippet() async {
    final pos = getCurrentPosition();
    if (pos is TxtReadingPosition && pos.paragraphIndex < _lines.length) {
      return _lines[pos.paragraphIndex].trim();
    }
    return null;
  }

  @override
  Future<String?> getTextAtPosition(ReadingPosition position) async {
    if (position is TxtReadingPosition) {
      if (position.paragraphIndex < _lines.length) {
        return _lines[position.paragraphIndex].trim();
      }
    }
    return null;
  }

  @override
  Future<List<dynamic>> getChapters() async {
    if (_lines.isEmpty) return [];

    final chapters = <Map<String, dynamic>>[];
    final chapterPatterns = [
      RegExp(r'^第[零一二三四五六七八九十百千万\d]+[章回节话]', multiLine: false),
      RegExp(r'^Chapter\s+\d+', caseSensitive: false),
      RegExp(r'^\d+[\.，,]\s*\S+', multiLine: false),
      RegExp(r'^\d+\s+\S+', multiLine: false),
      RegExp(r'^[零一二三四五六七八九十百千万]+、', multiLine: false),
      RegExp(
        r'^第[零一二三四五六七八九十百千万\dIVXLCDMivxlcdm]+卷[：:\s]*第[零一二三四五六七八九十百千万\d]+[章回节话]',
        caseSensitive: false,
      ),
      RegExp(
        r'^.+[：:]\s*第[零一二三四五六七八九十百千万\d]+[章回节话]',
        multiLine: false,
      ),
    ];
    final standaloneNumberPattern = RegExp(r'^\d+$', multiLine: false);

    int chapterIndex = 0;
    for (int i = 0; i < _lines.length; i++) {
      final line = _lines[i].trim();
      if (line.isEmpty) continue;

      bool isChapter = false;
      for (final pattern in chapterPatterns) {
        if (pattern.hasMatch(line)) {
          isChapter = true;
          break;
        }
      }

      if (!isChapter && standaloneNumberPattern.hasMatch(line)) {
        if (i + 1 >= _lines.length || _lines[i + 1].trim().isEmpty) {
          isChapter = true;
        }
      }

      if (isChapter) {
        chapters.add({
          'title': line,
          'index': chapterIndex,
          'paragraphIndex': i,
        });
        chapterIndex++;
      }
    }

    return chapters;
  }

  String _getCurrentChapterTitle() {
    if (_chapters.isEmpty) return '';

    int paraIndex = _initialIndex;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isNotEmpty) {
      final sorted = positions.toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      for (var p in sorted) {
        if (p.itemLeadingEdge > -0.5) {
          paraIndex = p.index;
          break;
        }
      }
    }

    for (int i = _chapters.length - 1; i >= 0; i--) {
      final chParaIndex = _chapters[i]['paragraphIndex'] as int;
      if (chParaIndex <= paraIndex) {
        return _chapters[i]['title'] as String;
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

    _lastPaginationKey = paginationKey;
    _isPaginationCalculated = false;
    debugPrint('Recalculating pagination for key: $paginationKey');

    final style = TextStyle(
      fontSize: _config.fontSize,
      height: _config.lineHeight,
      fontFamily: 'Roboto',
    );

    try {
      final result = await PaginationHelper.calculatePageEstimate(
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
        return;
      }

      _totalPages = result[0];
      _charsPerPage = result[1];
      _isPaginationCalculated = true;
      _pageInfoNotifier.value++;
      debugPrint(
        'Pagination calculated: $_totalPages pages, $_charsPerPage chars/page',
      );
    } catch (e) {
      debugPrint('Pagination error: $e');
    }
  }

  @override
  int getPageCount() => _totalPages;

  @override
  int getCurrentPageIndex() {
    if (_paragraphOffsets.isEmpty) return 0;

    int paraIndex = _initialIndex;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isNotEmpty) {
      final sorted = positions.toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      for (var p in sorted) {
        if (p.itemLeadingEdge > -0.5) {
          paraIndex = p.index;
          break;
        }
      }
    }

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
