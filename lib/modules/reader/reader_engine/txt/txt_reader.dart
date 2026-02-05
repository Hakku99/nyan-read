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
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  
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
  final ValueNotifier<ReaderConfig> _configNotifier = ValueNotifier(
     const ReaderConfig(
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 18,
        lineHeight: 1.5,
     )
  );

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
       // Wait for list to be attached if needed
       // For MVP we assume it's attached if content is loaded
       if (_itemScrollController.isAttached) {
         _itemScrollController.jumpTo(index: position.paragraphIndex);
       }
    }
  }

  @override
  Future<void> seekToProgress(double progress) async {
    if (_lines.isEmpty) return;
    if (_itemScrollController.isAttached) {
      final index = (progress * (_lines.length - 1)).round();
      _itemScrollController.jumpTo(index: index);
    }
  }

  @override
  ReadingPosition? getCurrentPosition() {
    if (!_itemPositionsListener.itemPositions.value.isNotEmpty) return null;
    final firstVisible = _itemPositionsListener.itemPositions.value
        .where((item) => item.itemLeadingEdge < 1)
        .reduce((a, b) => a.itemLeadingEdge > b.itemLeadingEdge ? a : b)
        .index;

    return TxtReadingPosition(paragraphIndex: firstVisible);
  }

  @override
  void dispose() {
    _configNotifier.dispose();
  }
}
