import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/book.dart';
import '../../core/models/highlight.dart';
import '../../core/services/database_service.dart';
import '../../core/services/reader_preferences_service.dart';
import '../../core/services/service_locator.dart';
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
import '../../core/utils/lifecycle_registry.dart';
import 'controllers/reading_progress_manager.dart';
import 'brightness/brightness_orchestrator.dart';
import 'brightness/brightness_repository.dart';
import 'brightness/system_brightness_adapter.dart';
import 'controllers/brightness_controller.dart';
import 'brightness/overlay_widget.dart';
import 'widgets/brightness_hud_widget.dart';
import 'widgets/chapter_list_widget.dart';
import 'controllers/reader_settings_manager.dart';
import 'controllers/content_meta_manager.dart';

class ReaderController extends ChangeNotifier with WidgetsBindingObserver {
  final Book book;
  late ReaderEngine engine;

  bool _showControls = false;
  ReaderErrorState? _errorState;

  // Managers & Lifecycle
  final LifecycleRegistry _lifecycle = LifecycleRegistry();
  late final ReadingProgressManager progressManager;
  late final ReaderSettingsManager settingsManager;
  late final ContentMetaManager metaManager;

  final Debouncer _layoutDebouncer =
      Debouncer(delay: const Duration(milliseconds: 300));
  Size? _lastLayoutSize;
  BrightnessController? _brightnessControllerRef;
  VoidCallback? _brightnessControllerListener;

  Function(Highlight)? onShowNoteDialog;
  Function(Offset)? onContentTapDelegate;
  Offset? _tapDownPosition;
  Offset? _panStartPosition;
  bool _isPanning = false;
  static const double _swipeThreshold = 10.0; // Pixels to consider it a swipe

  ReaderController(this.book) {
    engine = ReaderEngineFactory.create(book);

    WidgetsBinding.instance.addObserver(this);

    // Initialize Managers
    settingsManager = ReaderSettingsManager(
      engine: engine,
      lifecycle: _lifecycle,
      onSettingsChanged: notifyListeners,
    );

    metaManager = ContentMetaManager(
      engine: engine,
      book: book,
      onMetaChanged: notifyListeners,
    );

    progressManager = ReadingProgressManager(
      engine: engine,
      book: book,
      lifecycle: _lifecycle,
      onProgressUpdated: notifyListeners,
    );
  }

  double get fontSize => settingsManager.fontSize;
  double get lineHeight => settingsManager.lineHeight;
  double get brightness => _brightnessControllerRef?.uiBrightnessValue.value ??
      getIt<ReaderPreferencesService>().brightness ??
      0.5;
  Color get backgroundColor => settingsManager.backgroundColor;
  Color get textColor => settingsManager.textColor;
  bool get showControls => _showControls;
  bool get followSystem =>
      _brightnessControllerRef?.followSystem ??
      (getIt<ReaderPreferencesService>().brightness == null);
  double get currentProgress => progressManager.currentProgress;

  void attachBrightnessController(BrightnessController bc) {
    if (_brightnessControllerRef != null &&
        _brightnessControllerListener != null) {
      _brightnessControllerRef!.removeListener(_brightnessControllerListener!);
    }

    _brightnessControllerRef = bc;
    _brightnessControllerListener = notifyListeners;
    bc.addListener(_brightnessControllerListener!);
    notifyListeners();
  }

  ReaderErrorState? get errorState => _errorState;
  List<dynamic> get chapters => metaManager.chapters;
  int? get currentChapterIndex => metaManager.currentChapterIndex;
  List<Highlight> get highlights => metaManager.highlights;
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      progressManager.saveCurrentPosition();
    }
  }

  void init() {
    progressManager.startTracking();
    _loadBook();
  }

  Future<void> _loadBook() async {
    try {
      _errorState = null;
      notifyListeners();

      // [Safety Net]: Missing file fallback.
      // If the user manually deleted the file in Document map, intercept it before engine crash.
      if (!File(book.filePath).existsSync()) {
        _errorState = ReaderErrorState(
          type: ReaderErrorType.fileNotFound,
          technicalMessage:
              "Source file [${book.filePath}] does not exist. The local book file may have been moved or deleted.\nPlease return to the bookshelf and remove this entry.",
        );
        notifyListeners();
        return;
      }

      await engine.initialize();

      await metaManager.loadChapters();
      await _restoreLastPosition();
      await metaManager.updateCurrentChapterIndex();
      await metaManager.loadHighlights();
      if (engine is TxtReaderEngine) {
        final txtEngine = engine as TxtReaderEngine;
        txtEngine.onTextHighlighted =
            (paragraphIndex, start, end, text, colorCode) {
          final paragraphText =
              txtEngine.getParagraphText(paragraphIndex) ?? '';
          metaManager.addHighlight(
            paragraphIndex,
            start,
            end,
            text,
            colorCode,
            paragraphText,
          );
        };
        txtEngine.onHighlightTapped = (highlight) {
          onShowNoteDialog?.call(highlight);
        };
        txtEngine.onContentTap = (position) {
          onContentTapDelegate?.call(position);
        };
      }

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

  void retry() {
    _loadBook();
  }

  void toggleControls() {
    _showControls = !_showControls;
    if (_showControls) {
      metaManager.updateCurrentChapterIndex();
    }
    notifyListeners();
  }

  Future<void> seekTo(double val) async {
    await progressManager.seekTo(val);
  }

  Future<void> jumpToChapter(int index, dynamic chapterData) async {
    await metaManager.jumpToChapter(
      index,
      chapterData,
      () async => await progressManager.saveCurrentPosition(),
    );
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
      'content_snippet': snippet,
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

  void setFontSize(double size) => settingsManager.setFontSize(size);
  void setLineHeight(double height) => settingsManager.setLineHeight(height);
  void setBackground(Color color) => settingsManager.setBackground(color);
  Future<void> setBrightness(double b) async {
    await _brightnessControllerRef?.setBrightness(b);
    notifyListeners();
  }

  Future<void> toggleFollowSystem() async {
    final controller = _brightnessControllerRef;
    if (controller == null) return;

    if (controller.followSystem) {
      await controller.setBrightness(controller.uiBrightnessValue.value);
    } else {
      await controller.resetToSystem();
    }

    notifyListeners();
  }

  Future<void> jumpToPreviousChapter() async =>
      await metaManager.jumpToPreviousChapter(
          () async => await progressManager.saveCurrentPosition());
  Future<void> jumpToNextChapter() async => await metaManager.jumpToNextChapter(
      () async => await progressManager.saveCurrentPosition());

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

  void showNoteDialog(BuildContext context, Highlight highlight) {
    showHighlightNoteDialog(
      context,
      highlight: highlight,
      onSave: (note, colorCode) => metaManager.updateHighlight(highlight.id,
          note: note, colorCode: colorCode),
      onDelete: () => metaManager.deleteHighlight(highlight.id),
    );
  }

  void handleLayoutChange(Size newSize) {
    settingsManager.handleLayoutChange(
        newSize, _lastLayoutSize, notifyListeners);
    _lastLayoutSize = newSize;
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
    await progressManager.saveCurrentPosition();
  }

  @override
  void dispose() {
    progressManager
        .saveCurrentPosition(); // Final backup save, may not complete.
    // Ensure the brightness listener bridge is always detached during dispose.
    if (_brightnessControllerRef != null && _brightnessControllerListener != null) {
      _brightnessControllerRef!.removeListener(_brightnessControllerListener!);
    }
    settingsManager.dispose();
    _lifecycle.disposeAll();
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
  final String bookId;

  const ReaderPage({Key? key, required this.bookId}) : super(key: key);

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late Future<Map<String, dynamic>?> _bookFuture;
  late final BrightnessController _brightnessController;
  final GlobalKey<ScaffoldState> readerPageScaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _bookFuture = getIt<DatabaseService>().getBookById(widget.bookId);
    final brightnessRepository =
        BrightnessRepository(getIt<ReaderPreferencesService>());
    final brightnessOrchestrator = BrightnessOrchestrator(
      repository: brightnessRepository,
      systemAdapter: SystemBrightnessAdapter(),
    );
    _brightnessController = BrightnessController(brightnessOrchestrator);
    unawaited(_brightnessController.initialize());
  }

  @override
  void dispose() {
    unawaited(_brightnessController.shutdown());
    _brightnessController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _bookFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(body: Center(child: Text("Book not found.")));
        }

        final book = Book.fromMap(snapshot.data!);

        return ChangeNotifierProvider(
          create: (_) {
            final controller = ReaderController(book)..init();
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
                      await _brightnessController.shutdown();
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
                              currentChapterIndex:
                                  controller.currentChapterIndex,
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
                          return BrightnessOverlayWidget(
                            stateListenable: _brightnessController.stateListenable,
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
                                        final isDark = controller
                                                .backgroundColor
                                                .computeLuminance() <
                                            0.5;
                                        final systemOverlayStyle = isDark
                                            ? SystemUiOverlayStyle.light
                                                .copyWith(
                                                statusBarColor:
                                                    Colors.transparent,
                                                systemNavigationBarColor:
                                                    Colors.transparent,
                                              )
                                            : SystemUiOverlayStyle.dark
                                                .copyWith(
                                                statusBarColor:
                                                    Colors.transparent,
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
                                                  MediaQuery.of(context)
                                                      .padding;
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
                                                                  .withOpacity(
                                                                      0.5)
                                                              : Colors.white
                                                                  .withOpacity(
                                                                      0.5),
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
                                Positioned.fill(
                                    child: Consumer<ReaderController>(
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
                                            duration: const Duration(
                                                milliseconds: 200),
                                            opacity: controller.showControls
                                                ? 1.0
                                                : 0.0,
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
                                // Avoid duplicate setBrightness calls here to prevent double writes.
                                // BrightnessController 内部已通过 uiBrightnessValue (ValueNotifier)
                                // HUD and slider state already come from uiBrightnessValue directly.
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: 50.0,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onVerticalDragStart: (_) =>
                                        _brightnessController.handleDragStart(),
                                    onVerticalDragUpdate: (details) {
                                      _brightnessController.handleDragUpdate(
                                        details.primaryDelta ?? 0.0,
                                        MediaQuery.of(context).size.height,
                                      );
                                    },
                                    onVerticalDragEnd: (details) {
                                      _brightnessController
                                          .handleInteractionEnd();
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
      },
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
            child: ReaderMenu(
              scaffoldKey: readerPageScaffoldKey,
              // Pass the BrightnessController directly so the slider binds to uiBrightnessValue.
              brightnessController: _brightnessController,
            ),
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
