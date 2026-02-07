import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../../core/models/book.dart';
import '../reader_engine.dart';
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

  @override
  Widget buildReader(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ValueListenableBuilder<ReaderConfig>(
      valueListenable: _configNotifier,
      builder: (context, config, child) {
        return _buildList(context, config);
      },
    );
  }

  Widget _buildList(BuildContext context, ReaderConfig config) {
    return ScrollablePositionedList.builder(
      initialScrollIndex: _initialIndex, // Use stored initial index
      itemCount: _lines.length,
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      itemBuilder: (context, index) {
        final line = _lines[index].trim();
        if (line.isEmpty) return const SizedBox(height: 10);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Text(
            line,
            style: TextStyle(
              fontSize: config.fontSize,
              height: config.lineHeight,
              color: config.textColor,
              fontFamily: 'Roboto',
            ),
          ),
        );
      },
    );
  }

  @override
  Future<void> goToPosition(ReadingPosition position) async {
    if (position is TxtReadingPosition) {
      if (_itemScrollController.isAttached) {
        _itemScrollController.jumpTo(index: position.paragraphIndex);
      } else {
        // Queue it for initial build
        _initialIndex = position.paragraphIndex;
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

    final firstVisible = _itemPositionsListener.itemPositions.value
        .where((item) => item.itemLeadingEdge < 1)
        .reduce((a, b) => a.itemLeadingEdge > b.itemLeadingEdge ? a : b)
        .index;

    return TxtReadingPosition(paragraphIndex: firstVisible);
  }

  @override
  Future<List<dynamic>> getChapters() async {
    if (_lines.isEmpty) return [];

    final chapters = <Map<String, dynamic>>[];

    // 智能章节检测正则表达式
    // 匹配常见的章节标题格式:
    // - "第X章"、"第X回"
    // - "Chapter X"、"CHAPTER X"
    // - "X. " 开头的标题
    final chapterPatterns = [
      RegExp(r'^第[零一二三四五六七八九十百千万\d]+[章回节]', multiLine: false),
      RegExp(r'^Chapter\s+\d+', caseSensitive: false),
      RegExp(r'^\d+\.\s+\S+', multiLine: false),
      RegExp(r'^[零一二三四五六七八九十百千万]+、', multiLine: false),
    ];

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
