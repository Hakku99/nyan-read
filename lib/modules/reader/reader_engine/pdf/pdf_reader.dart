import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/models/book.dart';
import '../../../../core/utils/book_source_access.dart';
import '../reader_engine.dart';
import 'pdf_position.dart';

class PdfReaderEngine implements ReaderEngine, PageMetricsCapability {
  static const ReaderCapabilities _capabilities = ReaderCapabilities(
    supportsTypography: false,
    supportsTheme: false,
    supportsHighlights: false,
    supportsAnnotations: false,
    supportsPageAnimation: false,
    chapterNavigation: ReaderChapterNavigation.synthetic,
  );

  final Book book;
  late PdfController _pdfController;
  bool _isInit = false;
  String? _temporaryPdfPath;

  PdfReaderEngine(this.book);

  @override
  ReaderCapabilities get capabilities => _capabilities;

  @override
  Future<void> initialize() async {
    if (_isInit) return;

    try {
      final source = await BookSourceAccess.preparePdfCompatibleSource(book);
      _temporaryPdfPath = source.isTemporary ? source.path : null;
      _pdfController = PdfController(
        document: PdfDocument.openFile(source.path),
      );
      _isInit = true;
    } catch (e) {
      throw FormatException('Failed to open PDF: $e');
    }
  }

  @override
  void setConfig(ReaderConfig config) {}

  @override
  double? getProgress() {
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
    final pageNumber = position.pageNumber;
    if (pageNumber != null) {
      _pdfController.jumpToPage(pageNumber);
    }
  }

  @override
  Future<void> seekToProgress(double progress) async {
    final count = _pdfController.pagesCount;
    if (count == null || count == 0) return;
    final page = (progress * (count - 1)).round() + 1;
    _pdfController.jumpToPage(page);
  }

  @override
  ReadingPosition? getCurrentPosition() {
    return PdfReadingPosition(pageNumber: _pdfController.page);
  }

  @override
  Future<void> goToChapter(ChapterLocator locator) async {
    if (locator.pageNumber != null) {
      await goToPosition(
        PdfReadingPosition(pageNumber: locator.pageNumber!),
      );
    }
  }

  @override
  Future<List<ReaderChapter>> getChapters() async {
    if (!_isInit) return [];

    try {
      final count = _pdfController.pagesCount;
      if (count == null || count == 0) return [];

      final chapters = <ReaderChapter>[];
      const pagesPerChapter = 10;
      for (int i = 1; i <= count; i += pagesPerChapter) {
        chapters.add(
          ReaderChapter(
            title: 'Page $i',
            index: chapters.length,
            locator: ChapterLocator(pageNumber: i),
            isSynthetic: true,
          ),
        );
      }

      return chapters;
    } catch (e) {
      debugPrint('Error extracting PDF chapters: $e');
      return [];
    }
  }

  @override
  Future<void> nextPage() async {
    await _pdfController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  @override
  Future<void> previousPage() async {
    await _pdfController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  @override
  int getPageCount() => _isInit ? (_pdfController.pagesCount ?? 0) : 0;

  @override
  int getCurrentPageIndex() => _isInit ? (_pdfController.page - 1) : 0;

  @override
  bool get hasBottomBar => false;


  @override
  void dispose() {
    if (_isInit) {
      _pdfController.dispose();
    }

    final tempPath = _temporaryPdfPath;
    if (tempPath != null) {
      unawaited(_deleteTemporaryPdf(tempPath));
      _temporaryPdfPath = null;
    }
  }

  Future<void> _deleteTemporaryPdf(String tempPath) async {
    try {
      final file = File(tempPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete temporary PDF source $tempPath: $e');
    }
  }
}
