import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/models/book.dart';
import '../../../../core/services/reader_preferences_service.dart';
import '../../../../core/theme/theme_presets.dart';
import '../../../../core/utils/book_source_access.dart';
import '../reader_engine.dart';
import '../page_turn_request.dart';
import '../page_presentation.dart';
import 'pdf_position.dart';

class PdfReaderEngine
    implements ReaderEngine, PageMetricsCapability, PagePresentationCapability {
  final _presentations = <int, ImageProvider>{};
  static const ReaderCapabilities _capabilities = ReaderCapabilities(
    typography: CapabilityLevel.none,
    theme: CapabilityLevel.none,
    highlights: CapabilityLevel.none,
    annotations: CapabilityLevel.none,
    pageAnimation: CapabilityLevel.none,
    chapterNavigation: ReaderChapterNavigation.synthetic,
  );

  final Book book;
  late PdfController _pdfController;
  bool _isInit = false;
  bool _disposed = false;
  String? _temporaryPdfPath;
  // PdfController does not own native document closure. Keep a successful
  // settlement signal so cleanup never re-awaits an already reported open error.
  Future<void>? _documentLoadComplete;
  PdfDocument? _document;
  final Set<Future<void>> _pageWork = {};
  // Tracks whether the underlying PdfDocument future has resolved; used to
  // gate [getProgress] / [getCurrentPosition] so we don't hit the controller
  // before it has real page numbers.
  bool _isDocumentReady = false;
  bool _isViewportReady = false;
  bool _initialRestoreResolved = false;
  bool _initialPageConfirmed = false;
  int? _initialNavigationTarget;
  int? _pendingPage;
  double? _pendingProgress;
  int _pendingPageOffset = 0;
  Completer<void>? _pendingNavigation;
  Object? _documentError;
  ReaderConfig _config = const ReaderConfig(
    backgroundColor: Colors.white,
    textColor: Colors.black,
    fontSize: 18,
    lineHeight: 1.5,
  );

  PdfReaderEngine(this.book);

  @override
  ReaderCapabilities get capabilities => _capabilities;

  // Keep the last confirmed page saveable after the viewport has detached.
  bool get canSaveReadingPosition => _initialPageConfirmed && !_disposed;

  /// The stored position has been read and any restore request has completed.
  void markInitialRestoreResolved() {
    _initialRestoreResolved = true;
    _confirmInitialPage();
  }

  void _confirmInitialPage() {
    if (_initialPageConfirmed ||
        !_initialRestoreResolved ||
        !_isViewportReady ||
        (_document?.pagesCount ?? 0) <= 0 ||
        _pendingNavigation != null) {
      return;
    }
    final target = _initialNavigationTarget;
    if (target == null || _pdfController.page == target) {
      _initialPageConfirmed = true;
      _initialNavigationTarget = null;
    }
  }

  @override
  Future<void> initialize() async {
    if (_isInit || _disposed) return;

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
    _documentLoadComplete = documentFuture.then<void>(
      (document) {
        _document = document;
        _isDocumentReady = !_disposed;
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('PDF document open failed: $error');
        _documentError = error;
        _finishNavigation(error, stack);
      },
    );
  }

  Future<PdfDocument> _preparePdfDocument() async {
    final source = await BookSourceAccess.preparePdfCompatibleSource(book);
    _temporaryPdfPath = source.isTemporary ? source.path : null;
    return PdfDocument.openFile(source.path);
  }

  @override
  void setConfig(ReaderConfig config) {
    _config = config;
  }

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
    return _PdfReaderViewport(engine: this);
  }

  Widget _buildPdfView(VoidCallback onLoaded) {
    return PdfView(
      controller: _pdfController,
      onDocumentLoaded: (_) => onLoaded(),
      onPageChanged: (_) => _confirmInitialPage(),
      scrollDirection: Axis.vertical,
      // Phase 2 · P0-6: themed placeholder while the PdfDocument future
      // resolves.  pdfx 2.9.2 exposes placeholders via the `builders` slot;
      // we deliberately set [documentLoaderBuilder] (full-surface spinner)
      // AND [errorBuilder] (inline failure text) because the default builder
      // in pdfx relies on Material's default blue spinner, which violates
      // AGENTS.md §4.4 ("CircularProgressIndicator 的默认蓝色必须显式指定").
      builders: PdfViewBuilders<DefaultBuilderOptions>(
        pageBuilder: _buildPage,
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

  PhotoViewGalleryPageOptions _buildPage(BuildContext context,
      Future<PdfPageImage> image, int index, PdfDocument document) {
    // pdfx completes this future after its finally block closes the page.
    // Observing only renderer completion would close the document too early.
    final work =
        image.then<void>((_) {}, onError: (Object error, StackTrace stack) {
      // The original image future still surfaces the error through PdfView.
      debugPrint('PDF page rendering failed (${error.runtimeType}).');
    });
    _pageWork.add(work);
    // Disposal must include every submitted page, including queued renders.
    unawaited(work.whenComplete(() => _pageWork.remove(work)));
    final provider = PdfPageImageProvider(image, index, document.id);
    _presentations[index] = provider;
    // Only nearby page handles are needed; never retain a second book cache.
    _presentations.removeWhere((key, _) => (key - index).abs() > 2);
    return PhotoViewGalleryPageOptions(
      imageProvider: provider,
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.contained * 3.0,
      initialScale: PhotoViewComputedScale.contained,
      heroAttributes: PhotoViewHeroAttributes(tag: '${document.id}-$index'),
    );
  }

  @override
  Future<bool> waitForPagePresentation(PageTurnRequest request) async {
    await request.wait(WidgetsBinding.instance.endOfFrame);
    if (_disposed || !_isDocumentReady) return false;
    final page = _pdfController.page;
    final provider = _presentations[page - 1];
    if (provider == null || !await waitForImageFrame(provider, request)) {
      return false;
    }
    await request.wait(WidgetsBinding.instance.endOfFrame);
    return _isDocumentReady && _pdfController.page == page;
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
    final pageNumber = position.pageNumber;
    if (pageNumber == null) return;
    await _navigate(page: pageNumber);
  }

  @override
  Future<void> seekToProgress(double progress) async {
    if (!progress.isFinite) return;
    await _navigate(progress: progress.clamp(0.0, 1.0));
  }

  Future<void> _navigate({int? page, double? progress, int pageOffset = 0}) {
    if (_disposed || !_isInit) return Future<void>.value();
    final error = _documentError;
    if (error != null) return Future<void>.error(error);
    // A newer explicit navigation owns the target; an old restore must never
    // replay after it. Completion also releases callers waiting on disposal.
    _finishNavigation();
    _pendingPage = page;
    _pendingProgress = progress;
    _pendingPageOffset = pageOffset;
    final completion = Completer<void>();
    _pendingNavigation = completion;
    _applyNavigation();
    return completion.future;
  }

  void _finishNavigation([Object? error, StackTrace? stack]) {
    final completion = _pendingNavigation;
    _pendingNavigation = null;
    _pendingPage = null;
    _pendingProgress = null;
    _pendingPageOffset = 0;
    if (completion == null) return;
    if (error == null) {
      completion.complete();
    } else {
      completion.completeError(error, stack);
    }
  }

  Future<void> _stepPendingNavigation(int delta) {
    final progress = _pendingProgress;
    if (progress != null) {
      return _navigate(
        progress: progress,
        pageOffset: _pendingPageOffset + delta,
      );
    }
    return _navigate(page: (_pendingPage ?? _pdfController.page) + delta);
  }

  void _applyNavigation() {
    if (_disposed ||
        !_isDocumentReady ||
        !_isViewportReady ||
        _pendingNavigation == null) {
      return;
    }
    final count = _pdfController.pagesCount;
    if (count == null || count == 0) return;
    final page =
        (_pendingPage ?? ((_pendingProgress! * (count - 1)).round() + 1)) +
            _pendingPageOffset;
    final target = page.clamp(1, count);
    if (!_initialPageConfirmed) _initialNavigationTarget = target;
    try {
      _pdfController.jumpToPage(target);
      _finishNavigation();
      _confirmInitialPage();
    } catch (error, stack) {
      _finishNavigation(error, stack);
    }
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
    if (!_isInit || _disposed) return const [];

    try {
      // The document has a page count before pdfx attaches its viewport.
      await _documentLoadComplete;
      final count = _document?.pagesCount;
      if (_disposed || count == null || count <= 0) return const [];

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
      return const [];
    }
  }

  @override
  Future<void> nextPage() async {
    if (_disposed || !_isInit) return;
    if (!_isDocumentReady || !_isViewportReady) {
      await _stepPendingNavigation(1);
      return;
    }
    if (_config.pageTurnMode == PageTurnMode.tap) {
      final pageCount = _pdfController.pagesCount;
      if (pageCount == null || pageCount == 0) return;
      final target = (_pdfController.page + 1).clamp(1, pageCount);
      _pdfController.jumpToPage(target);
      return;
    }
    await _pdfController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  @override
  Future<void> previousPage() async {
    if (_disposed || !_isInit) return;
    if (!_isDocumentReady || !_isViewportReady) {
      await _stepPendingNavigation(-1);
      return;
    }
    if (_config.pageTurnMode == PageTurnMode.tap) {
      final pageCount = _pdfController.pagesCount;
      if (pageCount == null || pageCount == 0) return;
      final target = (_pdfController.page - 1).clamp(1, pageCount);
      _pdfController.jumpToPage(target);
      return;
    }
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
    if (_disposed) return;
    _disposed = true;
    _isDocumentReady = false;
    _isViewportReady = false;
    _finishNavigation();
    _presentations.clear();
    if (_isInit) {
      _pdfController.dispose();
    }

    // ReaderEngine.dispose is synchronous; native work finishes independently
    // after the view detaches, without blocking the UI or delaying by a timer.
    unawaited(_closeDocumentAndSource());
  }

  Future<void> _closeDocumentAndSource() async {
    try {
      await _documentLoadComplete;
      while (_pageWork.isNotEmpty) {
        await Future.wait(_pageWork);
      }
      final document = _document;
      if (document != null && !document.isClosed) {
        await document.close();
      }
    } catch (error, stack) {
      // The reader has exited; route cleanup failures to the application error
      // handler and retain the temporary source when native closure fails.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'PDF reader',
        context: ErrorDescription('while closing a PDF document'),
      ));
      return;
    } finally {
      _documentLoadComplete = null;
      _document = null;
    }
    final tempPath = _temporaryPdfPath;
    if (tempPath != null) {
      await _deleteTemporaryPdf(tempPath);
      _temporaryPdfPath = null;
    }
  }

  Future<void> _deleteTemporaryPdf(String tempPath) async {
    try {
      final file = File(tempPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: FlutterError(
            'Temporary PDF source deletion failed (${e.runtimeType}).'),
        stack: stack,
        library: 'PDF reader',
        context: ErrorDescription('while deleting a temporary PDF source'),
      ));
    }
  }
}

// pdfx reports document success before its PageView is attached. The viewport
// owns this frame boundary so a detached/replaced view cannot replay a restore.
class _PdfReaderViewport extends StatefulWidget {
  const _PdfReaderViewport({required this.engine});

  final PdfReaderEngine engine;

  @override
  State<_PdfReaderViewport> createState() => _PdfReaderViewportState();
}

class _PdfReaderViewportState extends State<_PdfReaderViewport> {
  @override
  void initState() {
    super.initState();
    _scheduleReady();
  }

  void _scheduleReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.engine._disposed ||
          widget.engine._pdfController.loadingState.value !=
              PdfLoadingState.success) {
        return;
      }
      widget.engine._isViewportReady = true;
      widget.engine._applyNavigation();
      widget.engine._confirmInitialPage();
    });
  }

  @override
  Widget build(BuildContext context) =>
      widget.engine._buildPdfView(_scheduleReady);

  @override
  void dispose() {
    widget.engine._isViewportReady = false;
    super.dispose();
  }
}
