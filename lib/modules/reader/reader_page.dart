import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../../core/models/book.dart';
import '../../core/models/highlight.dart';
import '../../core/services/database_service.dart';
import '../../core/services/reader_preferences_service.dart';
import '../../core/utils/layout_debouncer.dart';
import '../../core/utils/snackbar_utils.dart';
import 'reader_engine/reader_engine.dart';
import 'reader_engine/reader_factory.dart';
import 'reader_engine/epub/epub_position.dart';
import 'reader_engine/txt/txt_position.dart';
import 'reader_engine/txt/txt_reader.dart';

import 'reader_engine/pdf/pdf_position.dart';
import 'reader_error.dart';
import 'widgets/reader_error_view.dart';
import 'widgets/highlight_note_dialog.dart';
import 'widgets/reader_menu.dart';
import 'dart:async';
import 'dart:io';
import 'controllers/brightness_controller.dart';
import 'widgets/sub_zero_brightness_wrapper.dart';
import 'widgets/brightness_hud_widget.dart';
import 'widgets/chapter_list_widget.dart';

class ReaderController extends ChangeNotifier with WidgetsBindingObserver {
  final Book book;
  late ReaderEngine engine;

  double _fontSize = 18.0;
  double _lineHeight = 1.5;
  double _brightness = 1.0;
  Color _backgroundColor = const Color(0xFFFDFCF8); // Default Cream Paper
  Color _textColor = const Color(0xFF4A453E); // Default Sumi Ink
  Timer? _reminderTimer;
  Timer? _progressTimer;
  Timer? _autoSaveTimer;
  int _readSeconds = 0;
  bool _showControls = false;
  double _currentProgress = 0.0;
  ReaderErrorState? _errorState;
  bool _followSystem = false;
  StreamSubscription<double>? _brightnessSubscription;
  BrightnessController? _brightnessControllerRef;
  List<dynamic> _chapters = [];
  int? _currentChapterIndex;
  final Debouncer _layoutDebouncer =
      Debouncer(delay: const Duration(milliseconds: 300));
  Size? _lastLayoutSize;
  List<Highlight> _highlights = [];
  Function(Highlight)? onShowNoteDialog;
  Function(Offset)? onContentTapDelegate;
  Offset? _tapDownPosition;
  Offset? _panStartPosition;
  bool _isPanning = false;
  static const double _swipeThreshold = 10.0; // Pixels to consider it a swipe

  ReaderController(this.book) {
    engine = ReaderEngineFactory.create(book);
    // Load saved preferences
    final prefs = ReaderPreferencesService.instance;
    _fontSize = prefs.fontSize;
    _lineHeight = prefs.lineHeight;
    _backgroundColor = prefs.backgroundColor;

    // Load or sync brightness
    _brightness = prefs.brightness ?? 0.5;
    if (prefs.brightness == null) {
      // Fetch system brightness if no pref is saved
      ScreenBrightness().current.then((b) {
        _brightness = b;
        notifyListeners();
      });
    }

    _updateEngineConfig();
    WidgetsBinding.instance.addObserver(this);
  }

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  double get brightness => _brightness;
  Color get backgroundColor => _backgroundColor;
  Color get textColor => _textColor;
  bool get showControls => _showControls;
  bool get followSystem => _followSystem;
  double get currentProgress => _currentProgress;

  /// Call once from _ReaderPageState.initState() to bridge the two brightness systems.
  void attachBrightnessController(BrightnessController bc) {
    _brightnessControllerRef = bc;
    // Sync initial brightness silently into BrightnessController so the overlay is correct.
    // DANGER: Do not call `bc.setFromSlider(_brightness)` here, as it calls `_showHud()`
    // and causes the HUD to permanently stick on screen on initial load.
    bc.uiBrightnessValue.value = _brightness;
  }

  ReaderErrorState? get errorState => _errorState;
  List<dynamic> get chapters => _chapters;
  int? get currentChapterIndex => _currentChapterIndex;
  Offset? get tapDownPosition => _tapDownPosition;
  bool get isPanning => _isPanning;

  void setTapDownPosition(Offset pos) {
    _tapDownPosition = pos;
    _panStartPosition = pos;
    _isPanning = false;
  }

  void updatePanPosition(Offset pos) {
    if (_panStartPosition != null) {
      final distance = (pos - _panStartPosition!).distance;
      if (distance > _swipeThreshold) {
        _isPanning = true;
      }
    }
  }

  void resetPanState() {
    _isPanning = false;
    _panStartPosition = null;
  }

  @override
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveCurrentPosition();
    }
  }

  void init() {
    _startTimer();
    _loadBook();
  }

  void _startTimer() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _readSeconds++;
      if (_readSeconds > 0 && _readSeconds % 3600 == 0) {
        notifyListeners();
      }
      // Always sync progress to show in bottom-left corner
      _syncProgress();
    });
  }

  Future<void> _loadBook() async {
    try {
      _errorState = null;
      notifyListeners();
      await engine.initialize();

      // 加载章节信息
      _chapters = await engine.getChapters();

      // 恢复上次阅读位置
      await _restoreLastPosition();

      // Update chapter index after restoring position
      await _updateCurrentChapterIndex();

      // Load highlights and wire up callbacks for TxtReaderEngine
      await loadHighlights();
      if (engine is TxtReaderEngine) {
        final txtEngine = engine as TxtReaderEngine;
        txtEngine.onTextHighlighted =
            (paragraphIndex, start, end, text, colorCode) {
          addHighlight(paragraphIndex, start, end, text, colorCode);
        };
        txtEngine.onHighlightTapped = (highlight) {
          onShowNoteDialog?.call(highlight);
        };
        txtEngine.onContentTap = (position) {
          onContentTapDelegate?.call(position);
        };
      }

      // 启动自动保存定时器 (每30秒保存一次,防抖)
      _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _saveCurrentPosition();
      });

      // Backfill bookmark snippets in background
      _backfillBookmarkSnippets();

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
        technicalMessage: "$e\n$stack",
      );
      notifyListeners();
    }
  }

  Future<void> _restoreLastPosition() async {
    try {
      debugPrint("DEBUG: _restoreLastPosition called for book ${book.id}");
      final positionData = await DatabaseService().getBookPosition(book.id);
      if (positionData == null) {
        debugPrint("DEBUG: No saved position found in DB");
        return;
      }

      final type = positionData['position_type'] as String;
      final payload = positionData['position_payload'] as String;
      debugPrint("DEBUG: RESTORING position: type=$type, payload=$payload");

      ReadingPosition? position;
      if (type == 'epub') {
        position = EpubReadingPosition.fromJson(payload);
      } else if (type == 'pdf') {
        position = PdfReadingPosition.fromJson(payload);
      } else if (type == 'txt') {
        position = TxtReadingPosition.fromJson(payload);
      }

      if (position != null) {
        await engine.goToPosition(position);
        debugPrint("DEBUG: Position restored to engine successfully");
      }
    } catch (e) {
      debugPrint('Error restoring position: $e');
    }
  }

  Future<void> _saveCurrentPosition() async {
    try {
      final position = engine.getCurrentPosition();
      final progress = engine.getProgress() ?? _currentProgress;
      debugPrint(
          "DEBUG: _saveCurrentPosition called. Engine returned: ${position?.toJson()}, progress: $progress");

      if (position != null) {
        await DatabaseService().updateBookPosition(
          book.id,
          book.format,
          position.toJson(),
          progress: progress,
        );
        debugPrint("DEBUG: Position and progress saved to DB");
      } else {
        debugPrint("DEBUG: Engine returned null position, NOT saving.");
      }
    } catch (e) {
      debugPrint('Error saving position: $e');
    }
  }

  void retry() {
    _loadBook();
  }

  void _updateEngineConfig() {
    // Determine text color based on background luminance
    // Japanese Cream constraints: No pure black on large surfaces if possible, but for text strict contrast is needed.
    // However, we can use the sumi ink color for light backgrounds.

    final bg = _backgroundColor;
    // Check for Dark Mode backgrounds
    bool isDark = bg.computeLuminance() < 0.5;

    if (isDark) {
      _textColor = const Color(0xFFE6E2D8); // Cream White
    } else {
      _textColor = const Color(0xFF4A453E); // Sumi Ink
    }

    final prefs = ReaderPreferencesService.instance;
    engine.setConfig(ReaderConfig(
      backgroundColor: _backgroundColor,
      textColor: _textColor,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      pageTurnMode: prefs.pageTurnMode,
      pageAnimation: prefs.pageAnimation,
    ));
  }

  bool get shouldShowReminder => _readSeconds > 0 && _readSeconds % 3600 == 0;

  void toggleControls() {
    _showControls = !_showControls;
    if (_showControls) {
      _updateCurrentChapterIndex();
    }
    notifyListeners();
  }

  Future<void> _updateCurrentChapterIndex() async {
    if (_chapters.isEmpty) return;

    final position = engine.getCurrentPosition();
    if (position == null) return;

    int newIndex = 0;

    // Robust search for current chapter
    // We want the chapter with the largest start-point that is still <= current-point.

    if ((position is TxtReadingPosition && book.format == 'txt') ||
        (book.format == 'txt')) {
      // Fallback for format check
      final currentPara =
          (position is TxtReadingPosition) ? position.paragraphIndex : -1;

      int maxStartPara = -1;

      for (int i = 0; i < _chapters.length; i++) {
        final chapterPara = _chapters[i]['paragraphIndex'] as int? ?? -1;
        // Check if this chapter starts before or at current position
        if (chapterPara != -1 && chapterPara <= currentPara) {
          // If this chapter starts LATER than the previous candidate, it's a better candidate
          // (i.e. we want the Closest chapter that is <= current)
          if (chapterPara > maxStartPara) {
            maxStartPara = chapterPara;
            newIndex = i;
          } else if (chapterPara == maxStartPara) {
            // Tie-breaker: prefer higher index if starts are same (rare)
            newIndex = i;
          }
        }
      }
    } else if (position is PdfReadingPosition && book.format == 'pdf') {
      final currentPage = position.pageNumber;
      int maxStartPage = -1;

      for (int i = 0; i < _chapters.length; i++) {
        final chapterPage = _chapters[i]['pageNumber'] as int? ?? -1;
        if (chapterPage != -1 && chapterPage <= currentPage) {
          if (chapterPage > maxStartPage) {
            maxStartPage = chapterPage;
            newIndex = i;
          }
        }
      }
    } else {
      // Fallback for other formats (e.g. EPUB) if possible
      // If we can't determine, keep current or default to 0.
      // For EPUB, we might need Cfi comparison which is complex.
      // Leaving as 0 if unknown prevents crashing, but navigation won't sync.
      if (_currentChapterIndex != null) {
        newIndex = _currentChapterIndex!;
      }
    }

    if (_currentChapterIndex != newIndex) {
      _currentChapterIndex = newIndex;
      // No need to notify here if called within toggleControls which notifies at end,
      // but safe to do so if called independently.
    }
  }

  void _syncProgress() {
    final p = engine.getProgress() ?? 0.0;
    if (p != _currentProgress) {
      _currentProgress = p;
      notifyListeners();
    }
  }

  Future<void> seekTo(double val) async {
    _currentProgress = val;
    notifyListeners(); // Optimistic update
    await engine.seekToProgress(val);
    await _saveCurrentPosition(); // 保存进度
  }

  Future<void> jumpToChapter(int index, dynamic chapterData) async {
    try {
      _currentChapterIndex = index;

      // 根据不同格式跳转
      if (book.format == 'epub' && chapterData['anchor'] != null) {
        final cfi = chapterData['anchor'] as String;
        await engine.goToPosition(EpubReadingPosition(cfi: cfi));
      } else if (book.format == 'txt' &&
          chapterData['paragraphIndex'] != null) {
        final paragraphIndex = chapterData['paragraphIndex'] as int;
        await engine
            .goToPosition(TxtReadingPosition(paragraphIndex: paragraphIndex));
      } else if (book.format == 'pdf' && chapterData['pageNumber'] != null) {
        final pageNumber = chapterData['pageNumber'] as int;
        await engine.goToPosition(PdfReadingPosition(pageNumber: pageNumber));
      }

      await _saveCurrentPosition(); // 保存进度
      notifyListeners();
    } catch (e) {
      debugPrint('Error jumping to chapter: $e');
    }
  }

  Future<void> previousPage() async {
    await engine.previousPage();
  }

  Future<void> nextPage() async {
    await engine.nextPage();
  }

  Future<void> addBookmark(BuildContext context) async {
    final position = engine.getCurrentPosition();
    if (position == null) return;

    final snippet = await engine.getSnippet();

    final bookmark = {
      'id': const Uuid().v4(),
      'book_id': book.id,
      'page_index': 0,
      'position_type': book.format,
      'position_payload': position.toJson(),
      'content_snippet': snippet, // Save snippet
      'note': '',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };

    await DatabaseService().insertBookmark(bookmark);
    if (context.mounted) {
      SnackBarUtils.show(context, "Bookmark Added!");
    }
  }

  Future<void> restorePosition(Map<String, dynamic> bookmarkData) async {
    final type =
        (bookmarkData['position_type'] ?? book.format).toString().toLowerCase();
    final payload = bookmarkData['position_payload'];

    if (payload == null) return;

    ReadingPosition? pos;
    try {
      if (type == 'epub') {
        pos = EpubReadingPosition.fromJson(payload);
      } else if (type == 'pdf') {
        pos = PdfReadingPosition.fromJson(payload);
      } else if (type == 'txt') {
        pos = TxtReadingPosition.fromJson(payload);
      }

      if (pos != null) {
        await engine.goToPosition(pos);
      }
    } catch (e) {
      debugPrint("Error restoring position: $e");
    }
  }

  void setFontSize(double size) {
    _fontSize = size;
    _updateEngineConfig();
    ReaderPreferencesService.instance.setFontSize(size);
    notifyListeners();
  }

  void setLineHeight(double height) {
    _lineHeight = height;
    _updateEngineConfig();
    ReaderPreferencesService.instance.setLineHeight(height);
    notifyListeners();
  }

  void setBackground(Color color) {
    _backgroundColor = color;
    _updateEngineConfig();
    ReaderPreferencesService.instance.setBackgroundColor(color);
    notifyListeners();
  }

  Future<void> setBrightness(double b) async {
    if (_followSystem) {
      // Break "Follow System" link
      _followSystem = false;
      _brightnessSubscription?.cancel();
      _brightnessSubscription = null;
    }

    _brightness = b;
    // Drive native screen brightness + sub-zero overlay via BrightnessController
    _brightnessControllerRef?.setFromSlider(b);
    // Persist to prefs
    await ReaderPreferencesService.instance.setBrightness(b);
    notifyListeners();
  }

  Future<void> toggleFollowSystem() async {
    _followSystem = !_followSystem;
    if (_followSystem) {
      // Switch to system brightness: hand control back to the OS
      try {
        // 1. Release native brightness control (OS takes over)
        await _brightnessControllerRef?.resetToSystem();
        if (_brightnessControllerRef == null) {
          await ScreenBrightness().resetScreenBrightness();
        }

        // 2. Read what the system brightness currently is
        double systemBrightness = await ScreenBrightness().current;
        _brightness = systemBrightness;
        // Sync overlay but keep it in step with system
        _brightnessControllerRef?.uiBrightnessValue.value = systemBrightness;

        // 3. Clear saved pref so BrightnessManager (if present) also follows system
        await ReaderPreferencesService.instance.setBrightness(null);

        // 4. Stream: keep slider synced when user adjusts system brightness
        _brightnessSubscription?.cancel();
        _brightnessSubscription =
            ScreenBrightness().onCurrentBrightnessChanged.listen((double b) {
          if (_followSystem) {
            _brightness = b;
            _brightnessControllerRef?.uiBrightnessValue.value = b;
            notifyListeners();
          }
        });
      } catch (e) {
        debugPrint("Failed to get system brightness: $e");
        _followSystem = false; // Revert if failed
      }
    } else {
      // Stop listening
      _brightnessSubscription?.cancel();
      _brightnessSubscription = null;

      // Re-apply the current brightness value as a manual override
      await setBrightness(_brightness);
    }
    notifyListeners();
  }

  Future<void> jumpToPreviousChapter() async {
    if (_currentChapterIndex == null || _currentChapterIndex! <= 0) return;
    await jumpToChapter(
        _currentChapterIndex! - 1, _chapters[_currentChapterIndex! - 1]);
  }

  Future<void> jumpToNextChapter() async {
    if (_currentChapterIndex == null ||
        _currentChapterIndex! >= _chapters.length - 1) return;
    await jumpToChapter(
        _currentChapterIndex! + 1, _chapters[_currentChapterIndex! + 1]);
  }

  // --- Highlights ---

  List<Highlight> get highlights => _highlights;

  Future<void> loadHighlights() async {
    try {
      final data = await DatabaseService().getHighlights(book.id);
      _highlights = data.map((m) => Highlight.fromMap(m)).toList();

      // Update engine if it's a TxtReaderEngine
      if (engine is TxtReaderEngine) {
        (engine as TxtReaderEngine).setHighlights(_highlights);
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading highlights: $e");
    }
  }

  Future<void> addHighlight(int paragraphIndex, int start, int end, String text,
      String colorCode) async {
    final highlight = Highlight(
      id: const Uuid().v4(),
      bookId: book.id,
      paragraphIndex: paragraphIndex,
      startOffset: start,
      endOffset: end,
      selectedText: text,
      colorCode: colorCode,
      createdAt: DateTime.now(),
    );

    await DatabaseService().insertHighlight(highlight.toMap());
    await loadHighlights();
  }

  Future<void> updateHighlight(String highlightId,
      {String? note, String? colorCode}) async {
    await DatabaseService()
        .updateHighlight(highlightId, note: note, colorCode: colorCode);
    await loadHighlights();
  }

  Future<void> deleteHighlight(String highlightId) async {
    await DatabaseService().deleteHighlight(highlightId);
    await loadHighlights();
  }

  void showNoteDialog(BuildContext context, Highlight highlight) {
    showHighlightNoteDialog(
      context,
      highlight: highlight,
      onSave: (note, colorCode) =>
          updateHighlight(highlight.id, note: note, colorCode: colorCode),
      onDelete: () => deleteHighlight(highlight.id),
    );
  }

  void handleLayoutChange(Size newSize) {
    // Skip if size hasn't changed significantly
    if (_lastLayoutSize != null &&
        (newSize.width - _lastLayoutSize!.width).abs() < 10 &&
        (newSize.height - _lastLayoutSize!.height).abs() < 10) {
      return;
    }

    _lastLayoutSize = newSize;

    // Debounce layout recalculation to avoid excessive updates
    _layoutDebouncer.run(() {
      _recalculateLayout(newSize);
    });
  }

  void _recalculateLayout(Size size) {
    // Adjust font size based on screen width
    // Base width is 800px, scale font size proportionally
    final baseFontSize = 18.0;
    final scaleFactor = (size.width / 800).clamp(0.7, 1.5);
    final adjustedFontSize = (baseFontSize * scaleFactor).clamp(12.0, 32.0);

    if ((adjustedFontSize - _fontSize).abs() > 1.0) {
      _fontSize = adjustedFontSize;
      _updateEngineConfig();
      notifyListeners();
    }
  }

  Future<void> _backfillBookmarkSnippets() async {
    try {
      final bookmarks = await DatabaseService().getBookmarks(book.id);
      for (final bm in bookmarks) {
        if (bm['content_snippet'] == null ||
            (bm['content_snippet'] as String).isEmpty) {
          final payload = bm['position_payload'];
          final type = bm['position_type'] ?? book.format;

          if (payload != null) {
            ReadingPosition? pos;
            if (type == 'txt') {
              pos = TxtReadingPosition.fromJson(payload);
            } else if (type == 'epub') {
              pos = EpubReadingPosition.fromJson(payload);
            } else if (type == 'pdf') {
              pos = PdfReadingPosition.fromJson(payload);
            }

            if (pos != null) {
              final text = await engine.getTextAtPosition(pos);
              if (text != null && text.isNotEmpty) {
                await DatabaseService().updateBookmark(bm['id'], {
                  'content_snippet': text,
                });
                debugPrint("Backfilled snippet for bookmark ${bm['id']}");
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error backfilling snippets: $e");
    }
  }

  /// Public method to save progress before exiting - can be awaited
  Future<void> saveBeforeExit() async {
    await _saveCurrentPosition();
  }

  @override
  void dispose() {
    _saveCurrentPosition(); // 最后保存一次 (backup save, may not complete)
    _reminderTimer?.cancel();
    _progressTimer?.cancel();
    _autoSaveTimer?.cancel();
    _brightnessSubscription?.cancel();
    _layoutDebouncer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    engine.dispose();
    super.dispose();
  }
}

const double kSectionSpacing = 16.0;
const double kRowHeight = 56.0;

// ... (existing imports)

class ReaderPage extends StatefulWidget {
  final Book book;

  const ReaderPage({Key? key, required this.book}) : super(key: key);

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final BrightnessController _brightnessController;
  final GlobalKey<ScaffoldState> readerPageScaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // DI: Inject the global preferences singleton into the controller
    _brightnessController =
        BrightnessController(ReaderPreferencesService.instance);
  }

  @override
  void dispose() {
    _brightnessController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final controller = ReaderController(widget.book)..init();
        // Bridge the two brightness systems so the slider and gesture-drag
        // both drive the same BrightnessController (native API + overlay).
        controller.attachBrightnessController(_brightnessController);
        controller.onShowNoteDialog = ((h) {
          if (context.mounted) {
            controller.showNoteDialog(context, h);
          }
        });
        controller.onContentTapDelegate =
            (pos) => _handleContentTap(context, pos, controller);
        return controller;
      },
      child: Builder(
        builder: (context) {
          // Selector for background color prevents rebuilding Scaffold on progress changes
          return Selector<ReaderController, Color>(
            selector: (_, c) => c.backgroundColor,
            builder: (context, bgColor, _) {
              return PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) async {
                  if (didPop) return;
                  // Save progress before navigating away
                  final controller = context.read<ReaderController>();
                  await controller.saveBeforeExit();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Scaffold(
                  key: readerPageScaffoldKey,
                  backgroundColor: bgColor,
                  resizeToAvoidBottomInset: false,
                  drawer: Drawer(
                    backgroundColor: bgColor,
                    width: MediaQuery.of(context).size.width * 0.9,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                    child: SafeArea(
                      child: Consumer<ReaderController>(
                          builder: (context, controller, child) {
                        return ChapterListWidget(
                          chapters: controller.chapters,
                          currentChapterIndex: controller.currentChapterIndex,
                          currentProgress: controller.currentProgress,
                          onChapterTap: (index, chapterData) {
                            Navigator.pop(context);
                            controller.jumpToChapter(index, chapterData);
                          },
                        );
                      }),
                    ),
                  ),
                  body: Consumer<ReaderController>(
                    builder: (context, controller, child) {
                      return SubZeroBrightnessWrapper(
                        brightnessNotifier:
                            _brightnessController.uiBrightnessValue,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Reader Content - Rebuilds when controller notifies

                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) =>
                                    _handleTapDown(context, details),
                                onTapUp: (details) =>
                                    _handleTapUp(context, details),
                                onPanStart: (details) =>
                                    _handlePanStart(context, details),
                                onPanUpdate: (details) =>
                                    _handlePanUpdate(context, details),
                                onPanEnd: (details) =>
                                    _handlePanEnd(context, details),
                                child: Consumer<ReaderController>(
                                  builder: (context, controller, _) {
                                    // Determine status bar style based on background luminance
                                    // Dark background -> Light icons (light)
                                    // Light background -> Dark icons (dark)
                                    final isDark = controller.backgroundColor
                                            .computeLuminance() <
                                        0.5;
                                    final systemOverlayStyle = isDark
                                        ? SystemUiOverlayStyle.light.copyWith(
                                            statusBarColor: Colors.transparent,
                                            systemNavigationBarColor:
                                                Colors.transparent,
                                          )
                                        : SystemUiOverlayStyle.dark.copyWith(
                                            statusBarColor: Colors.transparent,
                                            systemNavigationBarColor:
                                                Colors.transparent,
                                          );

                                    return AnnotatedRegion<
                                        SystemUiOverlayStyle>(
                                      value: systemOverlayStyle,
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          // debugPrint(
                                          //     "DEBUG READER_PAGE: LayoutBuilder constraints: maxWidth=${constraints.maxWidth}, maxHeight=${constraints.maxHeight}");
                                          final padding =
                                              MediaQuery.of(context).padding;
                                          return Stack(
                                            children: [
                                              Padding(
                                                padding: EdgeInsets.only(
                                                  top: padding.top,
                                                  bottom: padding.bottom,
                                                ),
                                                child: controller.engine
                                                    .buildReader(context),
                                              ),
                                              // Reading Progress Indicator (Bottom Left)
                                              // Hide if controls are shown OR if engine has its own bottom bar
                                              Positioned(
                                                left: 16,
                                                bottom: padding.bottom > 0
                                                    ? padding.bottom + 4
                                                    : 16,
                                                child: Opacity(
                                                  opacity: (controller
                                                              .showControls ||
                                                          controller.engine
                                                              .hasBottomBar)
                                                      ? 0
                                                      : 1,
                                                  child: Text(
                                                    "${(controller.currentProgress * 100).toInt()}%",
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: isDark
                                                          ? Colors.black
                                                              .withOpacity(0.5)
                                                          : Colors.white
                                                              .withOpacity(0.5),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            // 2. Error View
                            Selector<ReaderController, ReaderErrorState?>(
                              selector: (_, c) => c.errorState,
                              builder: (context, errorState, _) {
                                if (errorState == null)
                                  return const SizedBox.shrink();
                                // Wrap in Positioned.fill to ensure it has size in the Stack
                                return Positioned.fill(
                                  child: Container(
                                    color: Theme.of(context)
                                        .scaffoldBackgroundColor,
                                    child: ReaderErrorView(
                                      errorState: errorState,
                                      onBack: () => Navigator.pop(context),
                                      onRetry: () => context
                                          .read<ReaderController>()
                                          .retry(),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // 3. UI Overlays (Status Bar Helper)
                            // Rebuilds on showControls notify, keeping status bar logic
                            Positioned.fill(child: Consumer<ReaderController>(
                              builder: (context, controller, child) {
                                final theme = Theme.of(context);
                                final topPadding =
                                    MediaQuery.of(context).padding.top;

                                return Stack(
                                  children: [
                                    // Status Bar Helper
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      height: topPadding,
                                      child: AnimatedOpacity(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        opacity:
                                            controller.showControls ? 1.0 : 0.0,
                                        child: Container(
                                            color: theme.colorScheme.surface
                                                .withOpacity(0.95)),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            )),

                            // 4. Edge Gesture Binding for Brightness
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: 50.0,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onVerticalDragUpdate: (details) {
                                  _brightnessController.handleDragUpdate(
                                    details.primaryDelta ?? 0.0,
                                    MediaQuery.of(context).size.height,
                                  );

                                  // Optionally sync slider in reader menu
                                  // This drives the slider to follow the finger synchronously
                                  context
                                      .read<ReaderController>()
                                      .setBrightness(_brightnessController
                                          .uiBrightnessValue.value);
                                },
                                onVerticalDragEnd: (details) {
                                  _brightnessController.handleInteractionEnd();
                                },
                                child: const SizedBox.expand(),
                              ),
                            ),

                            // 5. Brightness HUD Overlay
                            // Injected just below overlays and gesture catchers
                            BrightnessHudWidget(
                                controller: _brightnessController),
                          ],
                        ),
                      );
                    },
                  ),
                ), // end Scaffold
              ); // end PopScope
            },
          );
        },
      ),
    );
  }

  void _handleTapDown(BuildContext context, TapDownDetails details) {
    context.read<ReaderController>().setTapDownPosition(details.globalPosition);
  }

  void _handleTapUp(BuildContext context, TapUpDetails details) {
    final controller = context.read<ReaderController>();
    // Only process tap if we weren't panning
    if (!controller.isPanning) {
      final pos = controller.tapDownPosition;
      if (pos != null) {
        _handleTapLogic(context, pos.dy);
      }
    }
    controller.resetPanState();
  }

  void _handlePanStart(BuildContext context, DragStartDetails details) {
    context.read<ReaderController>().setTapDownPosition(details.globalPosition);
  }

  void _handlePanUpdate(BuildContext context, DragUpdateDetails details) {
    context.read<ReaderController>().updatePanPosition(details.globalPosition);
  }

  void _handlePanEnd(BuildContext context, DragEndDetails details) {
    final controller = context.read<ReaderController>();
    // Reset pan state - if user was panning, the gestures were handled by the scroll view
    controller.resetPanState();
  }

  void _handleContentTap(
      BuildContext context, Offset position, ReaderController controller) {
    // For content taps (like internal links or custom engine gestures),
    // only process if not panning
    if (!controller.isPanning) {
      _handleTapLogic(context, position.dy, controller: controller);
    }
  }

  void _handleTapLogic(BuildContext context, double tapY,
      {ReaderController? controller}) {
    final c = controller ?? context.read<ReaderController>();

    // If user was swiping, don't process as tap
    if (c.isPanning) return;

    if (c.showControls) {
      c.toggleControls();
      return;
    }

    final screenHeight = MediaQuery.of(context).size.height;

    // Middle 20% of screen triggers menu (40%-60% range)
    // Top 40% triggers previous page
    // Bottom 40% triggers next page
    if (tapY < screenHeight * 0.40) {
      c.previousPage();
    } else if (tapY > screenHeight * 0.60) {
      c.nextPage();
    } else {
      // Only middle 20% triggers menu
      _showSettingsBottomSheet(context, c);
    }
  }

  void _showSettingsBottomSheet(
      BuildContext context, ReaderController controller) {
    // Notify controller to toggle the status bar controls helper if needed.
    // In many reader apps tapping center shows status bar too.
    controller.toggleControls();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        // Retrieve current controller without listening to changes for background
        final surfaceColor = Theme.of(context).colorScheme.surface;

        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          // ReaderMenu will inject its own UI into this container as the settings.
          // Padding removed here to allow ReaderMenu to manage its own padding.
          child: ChangeNotifierProvider<ReaderController>.value(
            value: controller,
            child: ReaderMenu(scaffoldKey: readerPageScaffoldKey),
          ),
        );
      },
    ).whenComplete(() {
      // Hide the status bar controls helper when the bottom sheet closes
      if (controller.showControls) {
        controller.toggleControls();
      }
    });
  }
}
