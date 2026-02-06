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

  @override
  Future<void> initialize() async {
    if (_isInit) return;

    final file = File(book.filePath);
    if (!await file.exists()) {
      throw const FileSystemException("File not found");
    }

    try {
      _pdfController = PdfController(
        document: PdfDocument.openFile(book.filePath),
      );
      _isInit = true;
    } catch (e) {
      throw FormatException("Failed to open PDF: $e");
    }
  }

  @override
  void setConfig(ReaderConfig config) {
    // PDF doesn't support reflow text styling.
  }

  @override
  double? getProgress() {
    // Check if initialized to avoid error
    if (!_isInit) return 0.0;
    final count = _pdfController.pagesCount;
    if (count == null || count == 0) return 0.0;
    return _pdfController.page / count;
  }

  @override
  Widget buildReader(BuildContext context) {
    if (!_isInit) return const Center(child: CircularProgressIndicator());
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
  Future<void> seekToProgress(double progress) async {
    final count = _pdfController.pagesCount;
    if (count == null || count == 0) return;
    final page = (progress * (count - 1)).round() + 1; // 1-based
    _pdfController.jumpToPage(page);
  }

  @override
  ReadingPosition? getCurrentPosition() {
    return PdfReadingPosition(pageNumber: _pdfController.page);
  }

  @override
  Future<List<dynamic>> getChapters() async {
    if (!_isInit) return [];

    try {
      // PDF章节提取通常基于文档大纲/书签
      // pdfx包可能不直接支持大纲提取,这里返回基于页码的简单章节
      final count = _pdfController.pagesCount;
      if (count == null || count == 0) return [];

      // 为PDF创建基于页码的简单章节
      // 实际应用中可以使用PDF元数据或OCR来提取真实章节
      final chapters = <Map<String, dynamic>>[];

      // 每10页创建一个章节标记(可配置)
      const pagesPerChapter = 10;
      for (int i = 1; i <= count; i += pagesPerChapter) {
        chapters.add({
          'title': 'Page $i',
          'index': chapters.length,
          'pageNumber': i,
        });
      }

      return chapters;
    } catch (e) {
      debugPrint('Error extracting PDF chapters: $e');
      return [];
    }
  }

  @override
  void dispose() {
    if (_isInit) {
      _pdfController.dispose();
    }
  }
}
