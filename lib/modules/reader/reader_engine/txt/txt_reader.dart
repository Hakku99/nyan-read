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

  TxtReaderEngine(this.book);

  Future<void> _loadContent() async {
    try {
      final file = File(book.filePath);
      if (!await file.exists()) {
        _error = "File not found: ${book.filePath}";
        _isLoading = false;
        return;
      }
      
      final content = await compute(_readAsString, file);
      // Simple split. Future improvement: Paragraph analysis.
      _lines = content.split('\n'); 
      _isLoading = false;
    } catch (e) {
      _error = "Error loading TXT: $e";
      _isLoading = false;
    }
  }

  static Future<String> _readAsString(File file) async {
    return await file.readAsString();
  }

  @override
  Widget buildReader(BuildContext context) {
    // We use a FutureBuilder wrapper internally if loading state isn't managed by parent
    // However, since buildReader is called once, we can use a StatefulWidget wrapper 
    // or just a FutureBuilder here.
    return FutureBuilder(
        future: _isLoading ? _loadContent() : null,
        builder: (context, snapshot) {
          if (_isLoading && snapshot.connectionState != ConnectionState.done) {
             return const Center(child: CircularProgressIndicator());
          }
          
          if (_error != null) {
            return Center(child: Text(_error!));
          }

          return _buildList(context);
        },
      );
  }

  Widget _buildList(BuildContext context) {
    // In a real app, this should consume the settings from ReaderController/Provider
    // For now we use the context's theme which should be set by ThemeManager
    final theme = Theme.of(context);
    
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
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 18, 
              height: 1.6,
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
       }
    }
  }

  @override
  ReadingPosition? getCurrentPosition() {
    if (!_itemPositionsListener.itemPositions.value.isNotEmpty) return null;
    // Get the first item that is visible
    final firstVisible = _itemPositionsListener.itemPositions.value
        .where((item) => item.itemLeadingEdge < 1)
        .reduce((a, b) => a.itemLeadingEdge > b.itemLeadingEdge ? a : b)
        .index;

    return TxtReadingPosition(paragraphIndex: firstVisible);
  }

  @override
  void dispose() {}
}
