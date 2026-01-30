import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epub_view/epub_view.dart';
import '../../../../core/models/book.dart';
import '../reader_engine.dart';
import 'epub_position.dart';

class EpubReaderEngine implements ReaderEngine {
  final Book book;
  late EpubController _epubController;
  bool _isInit = false;

  EpubReaderEngine(this.book);

  void _init() {
    if (_isInit) return;
    _epubController = EpubController(
      document: EpubDocument.openFile(File(book.filePath)),
    );
    _isInit = true;
  }

  @override
  Widget buildReader(BuildContext context) {
    _init();
    return EpubView(
      controller: _epubController,
      onDocumentLoaded: (document) {
         // handle loaded
      },
      onExternalLinkPressed: (link) {},
    );
  }

  @override
  Future<void> goToPosition(ReadingPosition position) async {
    if (position is EpubReadingPosition) {
       _epubController.gotoEpubCfi(position.cfi);
    }
  }

  @override
  ReadingPosition? getCurrentPosition() {
    final cfi = _epubController.generateEpubCfi();
    if (cfi != null) {
      return EpubReadingPosition(cfi: cfi);
    }
    return null;
  }

  @override
  void dispose() {
    if (_isInit) {
      _epubController.dispose();
    }
  }
}
