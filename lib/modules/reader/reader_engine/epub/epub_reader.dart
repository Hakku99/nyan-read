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
  void setConfig(ReaderConfig config) {
    // EpubView handles its own styling usually, or we need to rebuild it with builders.
    // For MVP, we might not support dynamic font change inside EpubView easily without rebuilding.
  }

  @override
  double? getProgress() {
    // Parsing CFI to percentage is complex without EpubController exposing it directly.
    return 0.0; 
  }

  @override
  Future<void> seekToProgress(double progress) async {
    // TODO: Implement EPUB seeking based on spine/progress mapping.
    debugPrint("EPUB seeking not yet supported.");
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
