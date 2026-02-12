import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../../core/models/book.dart';
import '../../../../core/models/highlight.dart';
import '../reader_engine.dart';
import 'txt_position.dart';
import 'dart:convert';
import 'package:fast_gbk/fast_gbk.dart';
import '../../widgets/highlightable_text.dart';
import 'pagination_helper.dart';

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

  // Highlights for this book
  List<Highlight> _highlights = [];

  // Callbacks for text selection
  Function(int paragraphIndex, int start, int end, String text,
      String colorCode)? onTextHighlighted;
  Function(Highlight highlight)? onHighlightTapped;
  Function(Offset position)? onContentTap;

  // Pagination Support
  String _fullContent = "";
  List<int> _paragraphOffsets = [];
  int _totalPages = 1;
  int _charsPerPage = 1;
  bool _isPaginationCalculated = false;
  Size? _lastSize;
  final ValueNotifier<int> _pageInfoNotifier = ValueNotifier(0);

  // Chapter Cache
  List<Map<String, dynamic>> _chapters = [];

  // We need a way to notify the widget to rebuild when config changes.
  // Since ReaderEngine is not a widget, we can use a ValueNotifier or Stream.
  // Or, we can let ReaderController handle the rebuild of the parent, and we just store the config.
  // But buildReader is called once. The widget returned by buildReader should listen to something.
  final ValueNotifier<ReaderConfig> _configNotifier =
      ValueNotifier(const ReaderConfig(
    backgroundColor: Colors.white,
    textColor: Colors.black,
    fontSize: 18,
    lineHeight: 1.5,
  ));

  TxtReaderEngine(this.book) {
    _itemPositionsListener.itemPositions.addListener(_updateCurrentPosition);
  }

  void _updateCurrentPosition() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isNotEmpty) {
      // Find the top-most visible item
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
    final file = File(book.filePath);
    if (!await file.exists()) {
      throw const FileSystemException("File not found");
    }

    try {
      final content = await compute(_readAsString, file);
      _fullContent = content;
      _lines = content.split('\n');

      // Build paragraph offsets
      _paragraphOffsets = List<int>.filled(_lines.length, 0);
      int currentOffset = 0;
      for (int i = 0; i < _lines.length; i++) {
        _paragraphOffsets[i] = currentOffset;
        currentOffset += _lines[i].length + 1; // +1 for newline
      }

      // Calculate chapters once
      final rawChapters = await getChapters();
      _chapters = rawChapters.cast<Map<String, dynamic>>();

      _isLoading = false;
    } catch (e) {
      throw FormatException("Failed to parse TXT file: $e");
    }
  }

  /// Set the highlights to display
  void setHighlights(List<Highlight> highlights) {
    _highlights = highlights;
    // Trigger rebuild by reassigning config value
    _configNotifier.value = _config;
  }

  /// Get current highlights
  List<Highlight> get highlights => _highlights;

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

  static Future<String> _readAsString(File file) async {
    try {
      // 1. Try UTF-8 (default)
      return await file.readAsString();
    } catch (e) {
      debugPrint("TXT Reader: UTF-8 decoding failed, trying GBK...");
      try {
        // 2. Try GBK
        final bytes = await file.readAsBytes();
        return gbk.decode(bytes);
      } catch (e) {
        debugPrint("TXT Reader: GBK decoding failed, trying Latin1...");
        // 3. Fallback to Latin1 (never fails to decode, but might show garbage)
        return await file.readAsString(encoding: latin1);
      }
    }
  }

  int _initialIndex = 0;
  bool _hasRestoredPosition = false;

  @override
  Widget buildReader(BuildContext context) {
    debugPrint(
        "DEBUG: TxtReader.buildReader called - isLoading=$_isLoading, lines=${_lines.length}");

    if (_isLoading) {
      debugPrint("DEBUG: Returning loading indicator");
      return const Center(child: CircularProgressIndicator());
    }

    if (_lines.isEmpty) {
      debugPrint("DEBUG: Lines is empty! Returning error message");
      return const Center(child: Text("No content loaded"));
    }

    debugPrint(
        "DEBUG: Building ValueListenableBuilder with ${_lines.length} lines");

    return LayoutBuilder(builder: (context, constraints) {
      // Trigger pagination calculation in background
      _recalculatePagination(constraints.biggest);

      return Stack(
        children: [
          SizedBox.expand(
            child: ValueListenableBuilder<ReaderConfig>(
              valueListenable: _configNotifier,
              builder: (context, config, child) {
                debugPrint(
                    "DEBUG: ValueListenableBuilder building with config: fontSize=${config.fontSize}, bg=${config.backgroundColor}");
                return _buildList(context, config);
              },
            ),
          ),
          // Page Info Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<int>(
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
                        final chapterTitle = _getCurrentChapterTitle();

                        return Container(
                          height: 20, // Height for footer
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          color: _config.backgroundColor
                              .withOpacity(0.9), // Match bg slightly
                          child: Row(
                            children: [
                              // Left: Progress Percentage
                              Expanded(
                                child: Text(
                                  "${progressPercent.toInt()}%",
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    color: _config.textColor.withOpacity(0.6),
                                    fontSize: 10,
                                  ),
                                ),
                              ),

                              // Middle: Chapter Title
                              Expanded(
                                flex: 2,
                                child: Text(
                                  chapterTitle,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _config.textColor.withOpacity(0.6),
                                    fontSize: 10,
                                  ),
                                ),
                              ),

                              // Right: Progress
                              Expanded(
                                child: Text(
                                  "$page / $total",
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: _config.textColor.withOpacity(0.6),
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      });
                }),
          ),
        ],
      );
    });
  }

  Widget _buildList(BuildContext context, ReaderConfig config) {
    debugPrint(
        "DEBUG: _buildList called - initialIndex=$_initialIndex, hasRestored=$_hasRestoredPosition");

    // Schedule position restoration after first frame if needed
    if (_initialIndex > 0 && !_hasRestoredPosition) {
      _hasRestoredPosition = true;
      debugPrint(
          "DEBUG: Scheduling position restoration to index $_initialIndex");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint(
            "DEBUG: PostFrameCallback executing - isAttached=${_itemScrollController.isAttached}");
        if (_itemScrollController.isAttached) {
          _itemScrollController.jumpTo(index: _initialIndex);
          debugPrint("DEBUG: Jumped to index $_initialIndex");
        }
      });
    }

    debugPrint(
        "DEBUG: Creating ScrollablePositionedList with ${_lines.length} items");

    // We do NOT update _initialIndex here because ScrollablePositionedList
    // should maintain its own state across rebuilds if the widget structure is stable.
    // Forcing _initialIndex to the current top item causes "snapping" during scrolls.

    return ScrollablePositionedList.builder(
      itemCount: _lines.length,
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      initialScrollIndex: _initialIndex,
      itemBuilder: (context, index) {
        // Debug only first few items to avoid spam
        if (index < 5) {
          debugPrint("DEBUG: itemBuilder called for index $index");
        }

        final line = _lines[index].trim();

        // Calculate padding based on position
        EdgeInsets itemPadding = const EdgeInsets.symmetric(horizontal: 24.0);

        // Add top padding to first item
        if (index == 0) {
          itemPadding = itemPadding.copyWith(top: 16.0);
          debugPrint(
              "DEBUG: First item - line='${line.length > 20 ? line.substring(0, 20) : line}...', textColor=${config.textColor}, bgColor=${config.backgroundColor}");
        }

        // Add bottom padding to last item (critical for clearing bottom bar)
        if (index == _lines.length - 1) {
          itemPadding = itemPadding.copyWith(bottom: 120.0);
        }

        // Paragraph spacing
        final bottomMargin = config.fontSize * 0.6;
        itemPadding =
            itemPadding.copyWith(bottom: itemPadding.bottom + bottomMargin);

        if (line.isEmpty) {
          if (index < 5) debugPrint("DEBUG: Item $index is empty line");
          return SizedBox(height: bottomMargin);
        }

        return HighlightableText(
          text: line,
          paragraphIndex: index,
          highlights: _highlights,
          style: TextStyle(
            fontSize: config.fontSize,
            height: config.lineHeight,
            color: config.textColor,
            fontFamily: 'Roboto',
          ),
          backgroundColor: config.backgroundColor,
          padding: itemPadding,
          onTextSelected: (paragraphIdx, start, end, text, colorCode) {
            // Forward to controller with the selected color
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
        // Use alignment: 0.0 to ensure the bookmarked line appears at the top of the screen
        _itemScrollController.jumpTo(
            index: position.paragraphIndex, alignment: 0.0);
      } else {
        // Queue it for initial build
        _initialIndex = position.paragraphIndex;
        _hasRestoredPosition = false; // Reset flag so restoration happens
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
    // If list not attached, return initial index as we haven't moved
    if (!_itemPositionsListener.itemPositions.value.isNotEmpty) {
      return TxtReadingPosition(paragraphIndex: _initialIndex);
    }

    final positions = _itemPositionsListener.itemPositions.value.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    if (positions.isEmpty) {
      return TxtReadingPosition(paragraphIndex: _initialIndex);
    }

    // Find the first item that is "mostly" visible at the top.
    // itemLeadingEdge is 0.0 when aligned to top.
    // If itemLeadingEdge is negative, it's partially scrolled off.
    // We want the first item where itemLeadingEdge > -0.1 (allow slight overlap)
    // OR if all are negative (shouldn't happen with correct usage), take the last one?
    // Actually, usually the first item is < 0 and second is > 0.
    // If the first item is 0.0, we take it.
    // If first item is -0.5, we consider it "read past" and want the next one?
    // User wants "first line in reading area". Ideally that's the one starting AT 0.
    // If line 1 is at -0.5 and line 2 is at 0.5 (big lines?), then line 1 takes up half screen.
    // But usually lines are small.
    // Use a threshold: if leading edge is < -0.1, it's "past".

    ItemPosition? candidate = positions.first;
    for (final pos in positions) {
      if (pos.itemLeadingEdge >= -0.05) {
        // Slightly lenient tolerance
        candidate = pos;
        break;
      }
    }

    return TxtReadingPosition(paragraphIndex: candidate!.index);
  }

  @override
  Future<List<dynamic>> getChapters() async {
    if (_lines.isEmpty) return [];

    final chapters = <Map<String, dynamic>>[];

    // 智能章节检测正则表达式
    // 匹配常见的章节标题格式:
    // - "第X章"、"第X回"
    // - "Chapter X"、"CHAPTER X"
    // - "X. " or "X.Title" 开头的标题
    // - Standalone numbers "1", "2" (verified by empty line after)
    final chapterPatterns = [
      RegExp(r'^第[零一二三四五六七八九十百千万\d]+[章回节]', multiLine: false),
      RegExp(r'^Chapter\s+\d+', caseSensitive: false),
      RegExp(r'^\d+\.\s*\S+', multiLine: false), // "1.Title" or "1. Title"
      RegExp(r'^[零一二三四五六七八九十百千万]+、', multiLine: false),
      // Improved regex for Volume + Chapter (e.g. 第I卷 第1章, 第3卷：第四章)
      // Supports Chinese numbers, Arabic numbers, and Roman numerals (IVX...) in Volume/Chapter parts
      RegExp(
          r'^第[零一二三四五六七八九十百千万\dIVXLCDMivxlcdm]+卷[：:\s]*第[零一二三四五六七八九十百千万\d]+[章回节]',
          caseSensitive: false),
    ];

    // Pattern for standalone numbers (needs empty line verification)
    final standaloneNumberPattern = RegExp(r'^\d+$', multiLine: false);

    int chapterIndex = 0;
    for (int i = 0; i < _lines.length; i++) {
      final line = _lines[i].trim();
      if (line.isEmpty) continue;

      // 检查是否匹配任何章节模式
      bool isChapter = false;
      for (final pattern in chapterPatterns) {
        if (pattern.hasMatch(line)) {
          isChapter = true;
          break;
        }
      }

      // Check for standalone numbers followed by empty line
      if (!isChapter && standaloneNumberPattern.hasMatch(line)) {
        // Verify next line is empty or this is the last line
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

    // 如果没有检测到章节,返回空列表
    return chapters;
  }

  String _getCurrentChapterTitle() {
    if (_chapters.isEmpty) return "";

    // Get current paragraph index
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

    // Find chapter with largest paragraphIndex <= paraIndex
    // Chapters are sorted by index/paragraphIndex usually.
    // Binary search or linear back scan.
    for (int i = _chapters.length - 1; i >= 0; i--) {
      final chParaIndex = _chapters[i]['paragraphIndex'] as int;
      if (chParaIndex <= paraIndex) {
        return _chapters[i]['title'] as String;
      }
    }
    return "";
  }

  /// Advance by approximately one screen height (estimated at 20 lines)
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

    // Handle huge item case (only one item visible and it's larger than viewport)
    if (first.index == last.index) {
      final leading = first.itemLeadingEdge;
      final trailing = first.itemTrailingEdge;
      final ratio = trailing - leading;

      // If item is larger than viewport (ratio > 1.0) and we are not at the end of it
      if (ratio > 1.0 && trailing > 1.0) {
        // Scroll down within the item
        // Calculate new alignment
        // Rel: Leading = A * (1 - R)  => A = Leading / (1 - R)
        // We want newLeading = leading - 0.9 (scroll down 90% of screen)
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

    // Normal case: Scroll to the last visible item, making it the new top (1 line overlap)
    // If last item is fully visible or mostly visible, we might want to target index + 1?
    // But targeting last item with align 0 guarantees it becomes top.

    var targetIndex = last.index;
    // Edge case: if we are stuck (target == first), force advance
    if (targetIndex == first.index && positions.length > 1) {
      targetIndex++;
    }

    if (_itemScrollController.isAttached) {
      await _itemScrollController.scrollTo(
        index: targetIndex.clamp(0, _lines.length - 1),
        alignment: 0.0, // Align to top
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Go back by approximately one screen height
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

    // Handle huge item case
    if (first.index == last.index) {
      final leading = first.itemLeadingEdge;
      final trailing = first.itemTrailingEdge;
      final ratio = trailing - leading;

      if (ratio > 1.0 && leading < 0.0) {
        // Scroll up within the item
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

    // Normal case: Scroll to first visible item, making it the new bottom (1 line overlap)
    var targetIndex = first.index;

    // If we are already at alignment 1.0 (bottom), we shouldn't just stay there?
    // But usually first item is at top (align 0) or partial.
    // Making it align 1.0 moves it to bottom. Correct.

    if (_itemScrollController.isAttached) {
      await _itemScrollController.scrollTo(
        index: targetIndex.clamp(0, _lines.length - 1),
        alignment: 1.0, // Align to bottom
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _recalculatePagination(Size size) async {
    if (_fullContent.isEmpty) return;
    if (_lastSize == size && _isPaginationCalculated) return;

    _lastSize = size;
    debugPrint("Recalculating pagination for size: $size"); // Log

    final style = TextStyle(
      fontSize: _config.fontSize,
      height: _config.lineHeight,
      fontFamily: 'Roboto',
    );

    // Approximate padding used in standard view
    final padding =
        const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0);

    // Capture the size we are calculating for
    final captureSize = size;

    try {
      final result = await PaginationHelper.calculatePageEstimate(
          text: _fullContent,
          style: style,
          maxWidth: size.width,
          maxHeight: size.height,
          padding: padding);

      // Check if the size has changed while we were calculating
      if (_lastSize != captureSize) {
        debugPrint(
            "Pagination calculation discarded: size changed from $captureSize to $_lastSize");
        return;
      }

      _totalPages = result[0];
      _charsPerPage = result[1];
      _isPaginationCalculated = true;
      _pageInfoNotifier.value++; // Notify UI
      debugPrint(
          "Pagination calculated: $_totalPages pages, $_charsPerPage chars/page");
    } catch (e) {
      debugPrint("Pagination error: $e");
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
      // Find the first item that is visible (top >= 0 or close to it)
      // Or simply the first item in the list reported by listener
      final sorted = positions.toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      for (var p in sorted) {
        // itemLeadingEdge is 0 at top.
        if (p.itemLeadingEdge > -0.5) {
          paraIndex = p.index;
          break;
        }
      }
    }

    if (paraIndex >= _paragraphOffsets.length) return 0;

    // Get char offset of start of current paragraph
    int charIndex = _paragraphOffsets[paraIndex];

    // Estimate page index
    int pageIndex = (charIndex / _charsPerPage).floor();

    // Clamp
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
    _pageInfoNotifier.dispose();
  }
}
