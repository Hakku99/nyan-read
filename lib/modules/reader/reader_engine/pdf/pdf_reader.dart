import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../../../../core/models/book.dart';
import '../reader_engine.dart';
import 'pdf_position.dart';

class PdfReaderEngine implements ReaderEngine {
  final Book book;
  late PdfController _pdfController;
  bool _isInit = false;

  PdfReaderEngine(this.book);

  void _init() {
    if (_isInit) return;
    _pdfController = PdfController(
      document: PdfDocument.openFile(book.filePath),
    );
    _isInit = true;
  }

  @override
  Widget buildReader(BuildContext context) {
    _init();
    return PdfView(
      controller: _pdfController,
      scrollDirection: Axis.vertical,
    );
  }

  @override
  Future<void> goToPosition(ReadingPosition position) async {
    if (position is PdfReadingPosition) {
       _pdfController.jumpToPage(position.pageNumber);
    }
  }

  @override
  ReadingPosition? getCurrentPosition() {
    return PdfReadingPosition(pageNumber: _pdfController.page);
  }

  @override
  void dispose() {
    if (_isInit) {
      _pdfController.dispose();
    }
  }
}
