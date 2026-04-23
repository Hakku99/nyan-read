import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/models/book.dart';
import '../../../core/models/highlight.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/reader_preferences_service.dart';
import '../../../core/theme/nyan_colors.dart';
import '../../../core/utils/book_source_access.dart';
import '../../../core/utils/layout_debouncer.dart';
import '../../../core/utils/lifecycle_registry.dart';
import 'brightness_controller.dart';
import '../reader_engine/reader_engine.dart';
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

  final Debouncer _layoutDebouncer =
      Debouncer(delay: const Duration(milliseconds: 300));
  Size? _lastLayoutSize;
  BrightnessController? _brightnessControllerRef;
  bool _isDisposed = false;
  int _renderEpoch = 0;

  ReaderController(
    this.book, {
    required ReaderPreferencesService readerPreferencesService,
    required DatabaseService databaseService,
  })  : _readerPreferencesService = readerPreferencesService,
        _databaseService = databaseService {
    engine = ReaderEngineFactory.create(book);
    WidgetsBinding.instance.addObserver(this);

    settingsManager = ReaderSettingsManager(
      engine: engine,
      lifecycle: _lifecycle,
      onSettingsChanged: _safeNotifyListeners,
      preferences: _readerPreferencesService,
    );

    metaManager = ContentMetaManager(
      engine: engine,
      book: book,
      onMetaChanged: _safeNotifyListeners,
      databaseService: _databaseService,
    );

    progressManager = ReadingProgressManager(
      engine: engine,
      book: book,
      lifecycle: _lifecycle,
      databaseService: _databaseService,
      onProgressUpdated: _safeNotifyListeners,
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

      await metaManager.loadChapters();
      await progressManager.restoreLastPosition();
      await metaManager.syncCurrentChapterFromPosition(
        progressManager.currentPosition,
      );
      await metaManager.loadHighlights();

      unawaited(metaManager.backfillBookmarkSnippets());
      _renderEpoch++;
      notifyListeners();
    } catch (e, stack) {
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

  void retry() {
    _loadBook();
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
  }

  Future<void> previousPage() async {
    await engine.previousPage();
    progressManager.refreshFromEngine();
    await metaManager.syncCurrentChapterFromPosition(
      progressManager.currentPosition,
    );
  }

  Future<void> nextPage() async {
    await engine.nextPage();
    progressManager.refreshFromEngine();
    await metaManager.syncCurrentChapterFromPosition(
      progressManager.currentPosition,
    );
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
    settingsManager.setBackground(NyanColors.readerPaperDefault);
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
    setBackground(NyanColors.readerPaperDefault);
  }

  Future<void> jumpToPreviousChapter() async {
    await metaManager.jumpToPreviousChapter(
      () async => await progressManager.saveCurrentPosition(),
    );
    progressManager.refreshFromEngine();
  }

  Future<void> jumpToNextChapter() async {
    await metaManager.jumpToNextChapter(
      () async => await progressManager.saveCurrentPosition(),
    );
    progressManager.refreshFromEngine();
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

  void handleLayoutChange(Size newSize) {
    settingsManager.handleLayoutChange(
        newSize, _lastLayoutSize, notifyListeners);
    _lastLayoutSize = newSize;
  }

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
    _layoutDebouncer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    engine.dispose();
    progressManager.dispose();
    super.dispose();
  }
}
