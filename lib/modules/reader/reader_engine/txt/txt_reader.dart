import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../../core/models/book.dart';
import '../../../../core/models/highlight.dart';
import '../reader_engine.dart';
import 'txt_position.dart';
import '../../widgets/highlightable_text.dart';

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

  TxtReaderEngine(this.book);

  @override
  Future<void> initialize() async {
    final file = File(book.filePath);
    if (!await file.exists()) {
      throw const FileSystemException("File not found");
    }

    try {
      final content = await compute(_readAsString, file);
      _lines = content.split('\n');
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
    return await file.readAsString();
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
    return SizedBox.expand(
      child: ValueListenableBuilder<ReaderConfig>(
        valueListenable: _configNotifier,
        builder: (context, config, child) {
          debugPrint(
              "DEBUG: ValueListenableBuilder building with config: fontSize=${config.fontSize}, bg=${config.backgroundColor}");
          return _buildList(context, config);
        },
      ),
    );
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

    // Update _initialIndex to current position to prevent jumping on rebuild
    // This is critical when highlights change, as it triggers a rebuild.
    if (_itemPositionsListener.itemPositions.value.isNotEmpty) {
      final positions = _itemPositionsListener.itemPositions.value.toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      if (positions.isNotEmpty) {
        // Use the first visible item as the new initial index
        _initialIndex = positions.first.index;
        debugPrint(
            "DEBUG: Updated _initialIndex to $_initialIndex to preserve scroll position");
      }
    }

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

    return TxtReadingPosition(paragraphIndex: positions.first.index);
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

  @override
  void dispose() {
    _configNotifier.dispose();
  }
}
