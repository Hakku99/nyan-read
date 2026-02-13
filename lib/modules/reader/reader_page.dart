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
import 'widgets/brightness_manager.dart';

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
  double get currentProgress => _currentProgress;
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

    if (position is TxtReadingPosition && book.format == 'txt') {
      final currentPara = position.paragraphIndex;
      // Find the last chapter with paragraphIndex <= current
      for (int i = 0; i < _chapters.length; i++) {
        final chapterPara = _chapters[i]['paragraphIndex'] as int? ?? -1;
        if (chapterPara <= currentPara) {
          newIndex = i;
        } else {
          break;
        }
      }
    } else if (position is PdfReadingPosition && book.format == 'pdf') {
      final currentPage = position.pageNumber;
      for (int i = 0; i < _chapters.length; i++) {
        final chapterPage = _chapters[i]['pageNumber'] as int? ?? -1;
        if (chapterPage <= currentPage) {
          newIndex = i;
        } else {
          break;
        }
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
    _brightness = b;
    // Side effect removed: ScreenBrightness().setScreenBrightness(b);
    // The BrightnessManager widget now listens to this value and applies it.
    notifyListeners();
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
    _layoutDebouncer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    engine.dispose();
    super.dispose();
  }
}

const double kSectionSpacing = 16.0;
const double kRowHeight = 56.0;

// ... (existing imports)

class ReaderPage extends StatelessWidget {
  final Book book;

  const ReaderPage({Key? key, required this.book}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final controller = ReaderController(book)..init();
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
                  backgroundColor: bgColor,
                  resizeToAvoidBottomInset: false,
                  body: Consumer<ReaderController>(
                    builder: (context, controller, child) {
                      return BrightnessManager(
                        brightness: controller.brightness,
                        onBrightnessChanged: (val) =>
                            controller.setBrightness(val),
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
                                        ? SystemUiOverlayStyle.light
                                        : SystemUiOverlayStyle.dark;

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

                            // 3. UI Overlays (AppBar, Status Bar, Bottom Panel) - Rebuilds on showControls notify
                            Positioned.fill(child: Consumer<ReaderController>(
                              builder: (context, controller, child) {
                                // Check if we should show controls (engine is always present)
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
                                            color: theme.colorScheme.primary
                                                .withOpacity(0.95)),
                                      ),
                                    ),

                                    // Top Toolbar
                                    AnimatedPositioned(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      top: controller.showControls ? 0 : -100,
                                      left: 0,
                                      right: 0,
                                      height: kToolbarHeight +
                                          topPadding, // Explicit height to prevent layout errors
                                      child: AppBar(
                                        backgroundColor: theme
                                            .colorScheme.primary
                                            .withOpacity(0.95),
                                        elevation: 0,
                                        primary: true, // Use internal padding
                                        bottom: PreferredSize(
                                          preferredSize:
                                              const Size.fromHeight(1),
                                          child: Divider(
                                              height: 1,
                                              thickness: 1,
                                              color: theme.dividerColor
                                                  .withOpacity(0.2)),
                                        ),
                                        title: Text(book.title,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: theme.colorScheme.onPrimary
                                                  .withOpacity(0.9),
                                            )),
                                        iconTheme: IconThemeData(
                                            color: theme.colorScheme.onPrimary),
                                        actions: const [],
                                      ),
                                    ),

                                    // Bottom Toolbar replaced with ReaderMenu
                                    AnimatedPositioned(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      bottom:
                                          controller.showControls ? 0 : -600,
                                      left: 0,
                                      right: 0,
                                      child: const ReaderMenu(),
                                    ),
                                  ],
                                );
                              },
                            )),
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
      c.toggleControls();
    }
  }
}
