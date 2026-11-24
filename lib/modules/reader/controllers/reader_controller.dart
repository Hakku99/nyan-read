import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/models/book.dart';
import '../../../core/models/highlight.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/reader_preferences_service.dart';
import '../../../core/utils/book_source_access.dart';
import '../../../core/utils/lifecycle_registry.dart';
import 'brightness_controller.dart';
import '../reader_engine/epub/epub_reader.dart';
import '../reader_engine/pdf/pdf_reader.dart';
import '../reader_engine/reader_engine.dart';
import '../reader_engine/page_turn_request.dart';
import '../reader_engine/reader_factory.dart';
import '../reader_error.dart';
import 'content_meta_manager.dart';
import 'reader_settings_manager.dart';
import 'reading_progress_manager.dart';

class ReaderController extends ChangeNotifier with WidgetsBindingObserver {
  final Book book;
  late ReaderEngine engine;
  final ReaderPreferencesService _readerPreferencesService;
  final DatabaseService _databaseService;

  ReaderErrorState? _errorState;

  final LifecycleRegistry _lifecycle = LifecycleRegistry();
  late final ReadingProgressManager progressManager;
  late final ReaderSettingsManager settingsManager;
  late final ContentMetaManager metaManager;

  BrightnessController? _brightnessControllerRef;
  bool _isDisposed = false;
  int _renderEpoch = 0;
  Future<void> _pageTurnQueue = Future<void>.value();

  ReaderController(
    this.book, {
    required ReaderPreferencesService readerPreferencesService,
    required DatabaseService databaseService,
    Brightness appBrightness = Brightness.light,
  })  : _readerPreferencesService = readerPreferencesService,
        _databaseService = databaseService {
    engine = ReaderEngineFactory.create(book);
    WidgetsBinding.instance.addObserver(this);

    settingsManager = ReaderSettingsManager(
      engine: engine,
      lifecycle: _lifecycle,
      onSettingsChanged: _safeNotifyListeners,
      preferences: _readerPreferencesService,
      appBrightness: appBrightness,
    );

    metaManager = ContentMetaManager(
      engine: engine,
      book: book,
      onMetaChanged: _safeNotifyListeners,
      databaseService: _databaseService,
    );

    final reader = engine;
    progressManager = ReadingProgressManager(
      engine: engine,
      book: book,
      lifecycle: _lifecycle,
      databaseService: _databaseService,
      onProgressUpdated: _safeNotifyListeners,
      canSavePosition:
          reader is PdfReaderEngine ? () => reader.canSaveReadingPosition : null,
    );
  }

  void _safeNotifyListeners() {
    if (_isDisposed) return;
    notifyListeners();
  }

  double get fontSize => settingsManager.fontSize;
  double get lineHeight => settingsManager.lineHeight;
  double get warmth => _brightnessControllerRef?.warmth ?? 0.0;
  double get brightness =>
      _brightnessControllerRef?.uiBrightnessValue.value ?? 0.5;
  Color get backgroundColor => settingsManager.backgroundColor;
  Color get textColor => settingsManager.textColor;
  bool get backgroundFollowsTheme => settingsManager.backgroundFollowsTheme;
  bool get followSystem => _brightnessControllerRef?.followSystem ?? true;
  double get currentProgress => progressManager.currentProgress;
  ValueListenable<double> get progressListenable =>
      progressManager.progressListenable;
  ReaderCapabilities get capabilities => engine.capabilities;

  void attachBrightnessController(BrightnessController bc) {
    _brightnessControllerRef = bc;
    _safeNotifyListeners();
  }

  ReaderErrorState? get errorState => _errorState;
  int get renderEpoch => _renderEpoch;
  List<ReaderChapter> get chapters => metaManager.chapters;
  int? get currentChapterIndex => metaManager.currentChapterIndex;
  List<Highlight> get highlights => metaManager.highlights;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(progressManager.saveForLifecyclePause());
      unawaited(_readerPreferencesService.flushPendingWrites());
    }
  }

  void init() {
    scheduleMicrotask(_loadBook);
  }

  Future<void> _loadBook() async {
    try {
      _renderEpoch++;
      _errorState = null;
      notifyListeners();

      if (!await BookSourceAccess.isAvailable(book)) {
        _errorState = ReaderErrorState(
          type: ReaderErrorType.fileNotFound,
          userMessage: BookSourceAccess.unavailableMessage,
          technicalMessage: BookSourceAccess.technicalMessage(book),
        );
        notifyListeners();
        return;
      }

      await engine.initialize();
      progressManager.startTracking();
      _renderEpoch++;
      notifyListeners();
      await WidgetsBinding.instance.endOfFrame;

      final reader = engine;
      if (reader is PdfReaderEngine) {
        // PDF chapter metadata waits for the document; restore can start now.
        unawaited(_loadPdfChapters());
        unawaited(_watchPdfOpen(reader));
      } else {
        await metaManager.loadChapters();
      }
      await progressManager.restoreLastPosition(
        onResolved:
            reader is PdfReaderEngine ? reader.markInitialRestoreResolved : null,
      );
      if (_isDisposed) return;
      await metaManager.syncCurrentChapterFromPosition(
        progressManager.currentPosition,
      );
      await metaManager.loadHighlights();

      unawaited(metaManager.backfillBookmarkSnippets());
      _renderEpoch++;
      notifyListeners();
    } catch (e, stack) {
      // A rejected restore navigation carries the PDF open error, but the
      // watcher's classification is the right one; without this the generic
      // path below reports it as `unknown`.
      final reader = engine;
      if (reader is PdfReaderEngine && reader.documentError != null) {
        await _setPdfOpenError(reader.documentError!);
        return;
      }
      ReaderErrorType type = ReaderErrorType.unknown;
      final errorStr = e.toString().toLowerCase();

      if (e is FileSystemException || errorStr.contains('file not found')) {
        type = ReaderErrorType.fileNotFound;
      } else if (e is FormatException || errorStr.contains('format')) {
        type = ReaderErrorType.parseFailed;
      } else if (errorStr.contains('unsupported')) {
        type = ReaderErrorType.unsupportedFormat;
      }

      _errorState = ReaderErrorState(
        type: type,
        userMessage: type == ReaderErrorType.fileNotFound
            ? BookSourceAccess.unavailableMessage
            : null,
        technicalMessage: "$e\n$stack",
      );
      _renderEpoch++;
      notifyListeners();
    }
  }

  // PdfReaderEngine.initialize() returns before the document is open, so an
  // open failure (corrupt / encrypted PDF, revoked SAF grant) never reaches
  // _loadBook's catch on a first open without a saved position.
  Future<void> _watchPdfOpen(PdfReaderEngine reader) async {
    await reader.documentLoadComplete;
    final error = reader.documentError;
    if (_isDisposed || error == null || _errorState != null) return;
    await _setPdfOpenError(error);
  }

  Future<void> _setPdfOpenError(Object error) async {
    // pdfx reports a vanished file or revoked grant as a PlatformException,
    // not a FileSystemException, so re-check the source instead of guessing
    // from the exception type.
    final isMissing =
        error is FileSystemException || !await BookSourceAccess.isAvailable(book);
    // The catch path and the watcher can both land here; first writer wins.
    if (_isDisposed || _errorState != null) return;
    _errorState = ReaderErrorState(
      type: isMissing
          ? ReaderErrorType.fileNotFound
          : ReaderErrorType.parseFailed,
      userMessage: isMissing ? BookSourceAccess.unavailableMessage : null,
      technicalMessage: describePdfOpenError(error),
    );
    _renderEpoch++;
    notifyListeners();
  }

  Future<void> _loadPdfChapters() async {
    await metaManager.loadChapters();
    if (_isDisposed) return;
    await metaManager.updateCurrentChapterIndex();
  }

  void retry() {
    // Fire-and-forget: _loadBook reports failures through the error state.
    unawaited(_loadBook());
  }

  Future<void> seekTo(double val) async {
    await progressManager.seekTo(val);
    await metaManager.syncCurrentChapterFromPosition(
      progressManager.currentPosition,
    );
  }

  Future<void> jumpToChapter(int index, ChapterLocator locator) async {
    await metaManager.jumpToChapter(
      index,
      locator,
      () async => await progressManager.saveCurrentPosition(),
    );
    progressManager.refreshFromEngine();

    // The reader body is intentionally gated by [renderEpoch] so unrelated
    // controller notifications do not rebuild the engine widget. A chapter
    // jump changes the engine's scroll position without changing that epoch;
    // explicitly publish one render pass so the positioned list commits the
    // new viewport after navigation (especially when a sheet is collapsing).
    _renderEpoch++;
    _safeNotifyListeners();
  }

  Future<void> previousPage({PageTurnRequest? request}) async {
    await _enqueuePageTurn(engine.previousPage, request);
  }

  Future<void> nextPage({PageTurnRequest? request}) async {
    await _enqueuePageTurn(engine.nextPage, request);
  }

  ReadingPosition? get currentPosition => engine.getCurrentPosition();

  /// EPUB and PDF readiness wait for paint after their visible images load.
  bool get pageReadinessIncludesPaint =>
      engine is EpubReaderEngine || engine is PdfReaderEngine;

  Future<bool> waitForPagePresentation(PageTurnRequest request) async {
    final reader = engine;
    if (reader is PagePresentationCapability) {
      return (reader as PagePresentationCapability)
          .waitForPagePresentation(request);
    }
    await WidgetsBinding.instance.endOfFrame;
    return !_isDisposed;
  }

  Future<void> _enqueuePageTurn(
      Future<void> Function() turnAction, PageTurnRequest? request) async {
    final operation = _pageTurnQueue.then((_) async {
      if (_isDisposed || request?.isActive == false) return;
      await turnAction();
      if (_isDisposed) return;
      await Future<void>.value();
      progressManager.refreshFromEngine();
      await metaManager.syncCurrentChapterFromPosition(
        progressManager.currentPosition,
      );
    });
    // Recover the queue for subsequent requests, but preserve the failure for
    // this caller so the reader can show feedback instead of a success animation.
    _pageTurnQueue = operation.catchError((Object error, StackTrace stack) {
      debugPrint('Page turn pipeline failed (${error.runtimeType}).');
    });
    await operation;
  }

  Future<bool> addBookmark() => metaManager.addBookmark();

  Future<void> handleBookmarkSelection(
    Map<String, dynamic> bookmarkData,
  ) async {
    await metaManager.restoreBookmarkPosition(bookmarkData);
    progressManager.refreshFromEngine();
    await metaManager.syncCurrentChapterFromPosition(
      progressManager.currentPosition,
    );
  }

  Future<Highlight?> handleHighlightSelection(Highlight highlight) async {
    await metaManager.loadHighlights();
    await metaManager.openHighlight(highlight);
    progressManager.refreshFromEngine();
    await metaManager.syncCurrentChapterFromPosition(
      progressManager.currentPosition,
    );
    return metaManager.findHighlightById(highlight.id) ?? highlight;
  }

  Future<void> restorePosition(Map<String, dynamic> bookmarkData) =>
      handleBookmarkSelection(bookmarkData);

  void setFontSize(double size) => settingsManager.setFontSize(size);
  void setLineHeight(double height) => settingsManager.setLineHeight(height);
  void setBackground(Color color) => settingsManager.setBackground(color);
  void setBackgroundFollowsTheme(bool value) =>
      settingsManager.setBackgroundFollowsTheme(value);
  void setAppBrightness(Brightness brightness) =>
      settingsManager.setAppBrightness(brightness);
  void setPageTurnMode(PageTurnMode mode) =>
      settingsManager.setPageTurnMode(mode);
  void setUseSerif(bool value) => settingsManager.setUseSerif(value);

  Future<void> setWarmth(double value) async {
    await _brightnessControllerRef?.setWarmth(value);
  }

  Future<void> setBrightness(double b) async {
    await _brightnessControllerRef?.setBrightness(b);
  }

  Future<void> toggleFollowSystem() async {
    final controller = _brightnessControllerRef;
    if (controller == null) return;
    if (controller.followSystem) {
      await controller.setBrightness(controller.uiBrightnessValue.value);
    } else {
      await controller.resetToSystem();
    }
  }

  Future<void> resetReaderAppearanceDefaults() async {
    settingsManager.setFontSize(18);
    settingsManager.setLineHeight(1.5);
    settingsManager.resetBackground();
    await setWarmth(0);
  }

  Future<void> resetReaderDisplayDefaults() async {
    await setWarmth(0);
    await _brightnessControllerRef?.resetToSystem();
  }

  void resetReaderTextDefaults() {
    settingsManager.setFontSize(18);
    settingsManager.setLineHeight(1.5);
  }

  void resetReaderThemeDefaults() {
    settingsManager.resetBackground();
  }

  Future<void> jumpToPreviousChapter() async {
    await metaManager.jumpToPreviousChapter(
      () async => await progressManager.saveCurrentPosition(),
    );
    progressManager.refreshFromEngine();
    _renderEpoch++;
    _safeNotifyListeners();
  }

  Future<void> jumpToNextChapter() async {
    await metaManager.jumpToNextChapter(
      () async => await progressManager.saveCurrentPosition(),
    );
    progressManager.refreshFromEngine();
    _renderEpoch++;
    _safeNotifyListeners();
  }

  Future<void> refreshCurrentChapterIndex() async =>
      await metaManager.updateCurrentChapterIndex();

  Future<void> syncChapterAfterScroll() async {
    progressManager.refreshFromEngine();
    await metaManager.syncCurrentChapterFromPosition(
      progressManager.currentPosition,
    );
  }

  Future<void> loadHighlights() => metaManager.loadHighlights();
  Future<void> addHighlight(int paragraphIndex, int start, int end, String text,
          String colorCode, String paragraphText) =>
      metaManager.addHighlight(
          paragraphIndex, start, end, text, colorCode, paragraphText);
  Future<void> updateHighlight(String highlightId,
          {String? note, String? colorCode}) =>
      metaManager.updateHighlight(highlightId,
          note: note, colorCode: colorCode);
  Future<void> deleteHighlight(String highlightId) =>
      metaManager.deleteHighlight(highlightId);
  Future<void> openHighlight(Highlight highlight) =>
      metaManager.openHighlight(highlight);

  Future<void> saveBeforeExit() async {
    await progressManager.prepareForExit();
    await _readerPreferencesService.flushPendingWrites();
  }

  @override
  void dispose() {
    _isDisposed = true;
    progressManager.scheduleDisposeFallbackSave();
    _brightnessControllerRef = null;
    settingsManager.dispose();
    _lifecycle.disposeAll();
    WidgetsBinding.instance.removeObserver(this);
    engine.dispose();
    progressManager.dispose();
    super.dispose();
  }
}
