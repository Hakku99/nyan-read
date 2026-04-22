import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/models/book.dart';
import '../../../../core/theme/theme_presets.dart';
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
  // Tracks whether the underlying PdfDocument future has resolved; used to
  // gate [getProgress] / [getCurrentPosition] so we don't hit the controller
  // before it has real page numbers.
  bool _isDocumentReady = false;

  PdfReaderEngine(this.book);

  @override
  ReaderCapabilities get capabilities => _capabilities;

  @override
  Future<void> initialize() async {
    if (_isInit) return;

    // Phase 2 · P0-6: compose the whole "resolve source + open PDF" pipeline
    // into a single Future handed to PdfController so [initialize] itself
    // returns on the next microtask.  Previously this method awaited the
    // content-URI copy and opened the document synchronously, which held
    // the reader's load path (and the scaffold CircularProgressIndicator)
    // for the full duration of a multi-MB PDF parse on Android.
    final documentFuture = _preparePdfDocument();
    _pdfController = PdfController(document: documentFuture);
    _isInit = true;

    // The future is also consumed by PdfController internally, but we track
    // its resolution ourselves so that getProgress / getCurrentPosition /
    // getPageCount can bail out cleanly until the document is real.  Errors
    // are surfaced the next time a caller interacts with the controller.
    unawaited(documentFuture.then(
      (_) => _isDocumentReady = true,
      onError: (Object error, StackTrace stack) {
        debugPrint('PDF document open failed: $error');
      },
    ));
  }

  Future<PdfDocument> _preparePdfDocument() async {
    final source = await BookSourceAccess.preparePdfCompatibleSource(book);
    _temporaryPdfPath = source.isTemporary ? source.path : null;
    return PdfDocument.openFile(source.path);
  }

  @override
  void setConfig(ReaderConfig config) {}

  @override
  double? getProgress() {
    if (!_isInit || !_isDocumentReady) return 0.0;
    final count = _pdfController.pagesCount;
    if (count == null || count == 0) return 0.0;
    return _pdfController.page / count;
  }

  @override
  Widget buildReader(BuildContext context) {
    if (!_isInit) {
      return _buildPlaceholder(context);
    }
    return PdfView(
      controller: _pdfController,
      scrollDirection: Axis.vertical,
      // Phase 2 · P0-6: themed placeholder while the PdfDocument future
      // resolves.  pdfx 2.9.2 exposes placeholders via the `builders` slot;
      // we deliberately set [documentLoaderBuilder] (full-surface spinner)
      // AND [errorBuilder] (inline failure text) because the default builder
      // in pdfx relies on Material's default blue spinner, which violates
      // AGENTS.md §4.4 ("CircularProgressIndicator 的默认蓝色必须显式指定").
      builders: PdfViewBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: _buildPlaceholder,
        pageLoaderBuilder: _buildPlaceholder,
        errorBuilder: _buildErrorPlaceholder,
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final nyan = resolveNyanTheme(Theme.of(context));
    return Center(
      child: SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(nyan.primary),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(BuildContext context, Exception error) {
    final nyan = resolveNyanTheme(Theme.of(context));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Failed to open PDF: $error',
          textAlign: TextAlign.center,
          style: TextStyle(color: nyan.textSecondary, fontSize: 13),
        ),
      ),
    );
  }

  @override
  Future<void> goToPosition(ReadingPosition position) async {
    if (!_isDocumentReady) return;
    final pageNumber = position.pageNumber;
    if (pageNumber != null) {
      _pdfController.jumpToPage(pageNumber);
    }
  }

  @override
  Future<void> seekToProgress(double progress) async {
    if (!_isDocumentReady) return;
    final count = _pdfController.pagesCount;
    if (count == null || count == 0) return;
    final page = (progress * (count - 1)).round() + 1;
    _pdfController.jumpToPage(page);
  }

  @override
  ReadingPosition? getCurrentPosition() {
    if (!_isInit || !_isDocumentReady) return null;
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
    if (!_isInit || !_isDocumentReady) return [];

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
    if (!_isDocumentReady) return;
    await _pdfController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  @override
  Future<void> previousPage() async {
    if (!_isDocumentReady) return;
    await _pdfController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  @override
  int getPageCount() =>
      (_isInit && _isDocumentReady) ? (_pdfController.pagesCount ?? 0) : 0;

  @override
  int getCurrentPageIndex() =>
      (_isInit && _isDocumentReady) ? (_pdfController.page - 1) : 0;

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
