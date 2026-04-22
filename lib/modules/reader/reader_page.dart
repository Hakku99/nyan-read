import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/book.dart';
import '../../core/models/highlight.dart';
import '../../core/services/database_service.dart';
import '../../core/services/reader_preferences_service.dart';
import '../../core/services/service_locator.dart';
import '../../core/theme/nyan_colors.dart';
import '../../core/theme/nyan_radius.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/utils/layout_debouncer.dart';
import '../../core/utils/snackbar_utils.dart';
import '../bookmark/bookmark_list_page.dart';
import '../notes/notes_list_page.dart';
import 'reader_engine/reader_engine.dart';
import 'reader_engine/reader_factory.dart';
import 'reader_error.dart';
import 'widgets/reader_error_view.dart';
import 'widgets/highlight_note_dialog.dart';
import 'widgets/reader_menu.dart';
import 'dart:async';
import '../../core/utils/lifecycle_registry.dart';
import '../../core/utils/book_source_access.dart';
import '../../core/ui/components/nyan_overlay_style.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/reader_chapter_summary.dart';
import 'widgets/reader_settings/reader_settings_progress_card.dart';
import 'controllers/reading_progress_manager.dart';
import 'brightness/brightness_orchestrator.dart';
import 'brightness/brightness_repository.dart';
import 'brightness/system_brightness_adapter.dart';
import 'controllers/brightness_controller.dart';
import 'brightness/overlay_widget.dart';
import 'widgets/brightness_hud_widget.dart';
import 'widgets/chapter_list_widget.dart';
import 'widgets/reader_overlay_tool_button.dart';
import 'widgets/reader_settings/reader_settings_common.dart';
import 'controllers/reader_settings_manager.dart';
import 'controllers/content_meta_manager.dart';

class ReaderController extends ChangeNotifier with WidgetsBindingObserver {
  final Book book;
  late ReaderEngine engine;
  final ReaderPreferencesService _readerPreferencesService;
  final DatabaseService _databaseService;

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

    // All manager-side "something changed" notifications funnel through
    // [_safeNotifyListeners] so a late async callback that fires after the
    // widget has been popped never hits a disposed ChangeNotifier.
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

  /// Reactive handle for the 0..1 reading progress.  Leaf widgets (bottom-left
  /// "42%" label, overlay scrubber) subscribe to this directly so that the 1s
  /// reading heartbeat never pulls the whole reader tree through
  /// [ChangeNotifier.notifyListeners].
  ValueListenable<double> get progressListenable =>
      progressManager.progressListenable;
  ReaderCapabilities get capabilities => engine.capabilities;

  void attachBrightnessController(BrightnessController bc) {
    // Deliberately do NOT bridge BrightnessController.addListener into
    // this.notifyListeners.  BrightnessController fires on every vertical
    // drag delta (60+Hz during a slide gesture) and bridging that into the
    // reader-wide ChangeNotifier used to trigger a full Consumer rebuild
    // storm across the reader surface.  All UI that actually cares about
    // brightness/warmth (overlay tint, HUD, settings display panel) already
    // subscribes to BrightnessController's own ValueListenables directly.
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
      // Settings drags coalesce through a 300ms Debouncer inside the prefs
      // service (Phase 2 / P0-8). When the OS tells us we are about to go
      // to background we must flush that pending write, otherwise a cold
      // kill eats whatever the last ~300ms of slider drag produced.
      unawaited(_readerPreferencesService.flushPendingWrites());
    }
  }

  void init() {
    // Defer loading to the next microtask so Provider dependents have
    // mounted listeners before the first notifyListeners() in _loadBook().
    scheduleMicrotask(_loadBook);
  }

  Future<void> _loadBook() async {
    try {
      _renderEpoch++;
      _errorState = null;
      notifyListeners();

      // [Safety Net]: Missing file fallback.
      // If the user manually deleted the file in Document map, intercept it before engine crash.
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

  /// Resets typography, page background, and warmth to app defaults (reading UI only).
  /// Does not change pagination, chapter position, or brightness follow-system mode.
  Future<void> resetReaderAppearanceDefaults() async {
    settingsManager.setFontSize(18);
    settingsManager.setLineHeight(1.5);
    settingsManager.setBackground(NyanColors.readerPaperDefault);
    await setWarmth(0);
  }

  /// Display tab: low warmth and follow-system brightness. Does not change read position.
  Future<void> resetReaderDisplayDefaults() async {
    await setWarmth(0);
    await _brightnessControllerRef?.resetToSystem();
  }

  /// Text tab: default font size and line height only.
  void resetReaderTextDefaults() {
    settingsManager.setFontSize(18);
    settingsManager.setLineHeight(1.5);
  }

  /// Theme tab: default paper background.
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

  /// Refreshes engine-derived position then syncs TOC chapter from scroll/idle.
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

  /// Public method to save progress before exiting - can be awaited
  Future<void> saveBeforeExit() async {
    await progressManager.prepareForExit();
    // Same rationale as [didChangeAppLifecycleState]: ensure any pending
    // debounced pref writes are on disk before the reader route pops.
    await _readerPreferencesService.flushPendingWrites();
  }

  @override
  void dispose() {
    // Order matters here.  (1) Flip the disposed flag first so any
    // straggling async manager callback (e.g. DB read continuation) turns
    // into a no-op instead of notifyListeners-on-disposed.  (2) Take an
    // engine-state snapshot for the fallback save WHILE the engine is
    // still alive; the save itself is fire-and-forget against the DB.
    // (3) Only then tear down lifecycle/timers and the engine itself.
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

class _ReaderOverlayToolBar extends StatelessWidget {
  const _ReaderOverlayToolBar({
    required this.showChapterNavigation,
    required this.showNotes,
    required this.onOpenChapters,
    required this.onAddBookmark,
    required this.onOpenBookmarks,
    required this.onOpenNotes,
    required this.onOpenSettings,
    required this.chromeWidth,
  });

  final bool showChapterNavigation;
  final bool showNotes;
  final VoidCallback onOpenChapters;
  final VoidCallback onAddBookmark;
  final VoidCallback onOpenBookmarks;
  final VoidCallback onOpenNotes;
  final VoidCallback onOpenSettings;
  final double chromeWidth;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (showChapterNavigation)
        ReaderOverlayToolButton(
          icon: Icons.toc_rounded,
          onTap: onOpenChapters,
        ),
      ReaderOverlayToolButton(
        icon: Icons.bookmark_add_outlined,
        onTap: onAddBookmark,
      ),
      ReaderOverlayToolButton(
        icon: Icons.bookmarks_rounded,
        onTap: onOpenBookmarks,
      ),
      if (showNotes)
        ReaderOverlayToolButton(
          icon: Icons.edit_note_rounded,
          onTap: onOpenNotes,
        ),
      ReaderOverlayToolButton(
        icon: Icons.tune_rounded,
        onTap: onOpenSettings,
        isAccent: true,
      ),
    ];

    final theme = Theme.of(context);

    return Center(
      child: Container(
        key: const Key('reader-overlay-toolbar'),
        width: chromeWidth,
        padding: kReaderOverlayChromePadding,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            theme.colorScheme.surface.withValues(alpha: 0.92),
            theme.scaffoldBackgroundColor,
          ),
          borderRadius: BorderRadius.circular(NyanRadius.panel),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.18),
            width: 0.72,
          ),
          boxShadow: NyanOverlayStyle.noticeShadow(context),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int index = 0; index < actions.length; index++) ...[
                if (index > 0) const SizedBox(width: NyanSpacing.space8),
                actions[index],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const double kSectionSpacing = 16.0;
const double kRowHeight = 56.0;

double _overlayChromeWidth({
  required bool showChapterNavigation,
  required bool showNotes,
  required double availableWidth,
  double horizontalSafeGutter = 4,
}) {
  final actionCount =
      2 + (showChapterNavigation ? 1 : 0) + (showNotes ? 1 : 0) + 1;
  final buttonWidth = NyanSpacing.minTapTarget;
  final innerSpacing = NyanSpacing.space8 * (actionCount - 1);
  final sidePadding = kReaderOverlayChromePadding.horizontal;
  final targetWidth = (actionCount * buttonWidth) + innerSpacing + sidePadding;
  final maxAllowed = math.max(0.0, availableWidth - horizontalSafeGutter);
  return math.min(targetWidth, maxAllowed);
}

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
  final GlobalKey _readerBodyKey = GlobalKey();
  bool _showControls = false;
  Offset? _tapDownPosition;
  Offset? _panStartPosition;
  bool _isPanning = false;
  static const double _swipeThreshold = 10.0;
  static const Duration _tapLogicDedupWindow = Duration(milliseconds: 350);
  DateTime? _lastTapLogicAt;
  Timer? _chapterSyncDebounce;

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
    _chapterSyncDebounce?.cancel();
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
            final controller = ReaderController(
              book,
              readerPreferencesService: getIt<ReaderPreferencesService>(),
              databaseService: getIt<DatabaseService>(),
            );
            // Attach the page-level brightness binding for menu and gesture input.
            controller.attachBrightnessController(_brightnessController);
            controller.engine.textCapability?.configureInteractions(
              onTextHighlighted:
                  (paragraphIndex, start, end, text, colorCode) {
                final paragraphText = controller
                        .engine.textCapability
                        ?.getParagraphText(paragraphIndex) ??
                    '';
                unawaited(
                  controller.addHighlight(
                    paragraphIndex,
                    start,
                    end,
                    text,
                    colorCode,
                    paragraphText,
                  ),
                );
              },
              onHighlightTapped: (highlight) {
                if (!mounted) return;
                _showHighlightNoteDialog(context, controller, highlight);
              },
              onContentTap: (globalPosition) {
                if (!mounted) return;
                _handleContentTap(context, globalPosition, controller);
              },
            );
            controller.init();
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
                      // The outer `Consumer<ReaderController>` that used to
                      // wrap BrightnessOverlayWidget here was pure
                      // rebuild-on-every-notify overhead: nothing at this
                      // depth actually reads the controller.  Inner Selectors
                      // below subscribe to exactly the slices they need.
                      body: BrightnessOverlayWidget(
                        stateListenable:
                            _brightnessController.stateListenable,
                        warmthListenable:
                            _brightnessController.warmthListenable,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Reader body + inline progress % label.
                            //    Selector on a record so it only rebuilds when
                            //    (backgroundColor, progress, hasBottomBar)
                            //    actually change - not on every paragraph
                            //    sync or manager notify.
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
                                child: Selector<
                                    ReaderController,
                                    ({
                                      Color backgroundColor,
                                      bool hasBottomBar,
                                      int renderEpoch
                                    })>(
                                  selector: (_, c) => (
                                    backgroundColor: c.backgroundColor,
                                    hasBottomBar: c.engine.hasBottomBar,
                                    renderEpoch: c.renderEpoch,
                                  ),
                                  builder: (context, vm, _) {
                                    // Controller engine reference itself is
                                    // stable; we only need it for
                                    // buildReader() + the scroll callback.
                                    // Read (not watch) to avoid adding
                                    // another subscription.
                                    final controller =
                                        context.read<ReaderController>();
                                    final isDark = vm.backgroundColor
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
                                          final padding =
                                              MediaQuery.of(context).padding;
                                          return Stack(
                                            children: [
                                              Padding(
                                                key: _readerBodyKey,
                                                padding: EdgeInsets.only(
                                                  top: padding.top,
                                                  bottom: padding.bottom,
                                                ),
                                                child: NotificationListener<
                                                    ScrollNotification>(
                                                  onNotification:
                                                      (ScrollNotification _) {
                                                    _scheduleDebouncedChapterSync(
                                                      controller,
                                                    );
                                                    return false;
                                                  },
                                                  // RepaintBoundary isolates
                                                  // the scrolling engine body
                                                  // from the overlay layers
                                                  // above it so a scroll
                                                  // repaint does not dirty
                                                  // the Scaffold.
                                                  child: RepaintBoundary(
                                                    child: controller.engine
                                                        .buildReader(context),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                left: 16,
                                                bottom: padding.bottom > 0
                                                    ? padding.bottom + 4
                                                    : 16,
                                                child: Opacity(
                                                  opacity: (_showControls ||
                                                          vm.hasBottomBar)
                                                      ? 0
                                                      : 1,
                                                  child: ValueListenableBuilder<
                                                      double>(
                                                    valueListenable: controller
                                                        .progressListenable,
                                                    builder: (context,
                                                            progress, _) =>
                                                        Text(
                                                      "${(progress * 100).toInt()}%",
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: isDark
                                                            ? Colors.black
                                                                .withValues(alpha: 0.5)
                                                            : Colors.white
                                                                .withValues(alpha: 0.5),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
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

                            // 3. UI Overlays - only ever visible when
                            //    _showControls is true, but the subtree used
                            //    to rebuild on every controller notify even
                            //    while hidden.  Selector on the actual inputs
                            //    (chapters list length, current chapter
                            //    index, progress, capabilities) keeps this
                            //    inert during reading.
                            Positioned.fill(
                                // P0-4: when the chrome is collapsed, bail out
                                // before building anything.  _showControls is
                                // captured from enclosing StatefulWidget state;
                                // setState will drive a rebuild when it flips.
                                child: !_showControls
                                    ? const SizedBox.shrink()
                                    : Selector<
                                    ReaderController,
                                    ({
                                      int chaptersCount,
                                      int? currentChapterIndex,
                                      ReaderCapabilities capabilities
                                    })>(
                              selector: (_, c) => (
                                chaptersCount: c.chapters.length,
                                currentChapterIndex: c.currentChapterIndex,
                                capabilities: c.capabilities,
                              ),
                              builder: (context, vm, child) {
                                final controller =
                                    context.read<ReaderController>();
                                final theme = Theme.of(context);
                                final bottomPadding =
                                    MediaQuery.of(context).padding.bottom;
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
                                            opacity: _showControls ? 1.0 : 0.0,
                                            child: Container(
                                                color: theme.colorScheme.surface
                                                    .withValues(alpha: 0.95)),
                                          ),
                                        ),
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: bottomPadding > 0
                                              ? bottomPadding + 12
                                              : 18,
                                          child: IgnorePointer(
                                            ignoring: !_showControls,
                                            child: AnimatedOpacity(
                                              duration: const Duration(
                                                  milliseconds: 180),
                                              opacity:
                                                  _showControls ? 1.0 : 0.0,
                                              child: Center(
                                                child: ConstrainedBox(
                                                  constraints:
                                                      const BoxConstraints(
                                                    maxWidth: 680,
                                                  ),
                                                  child: LayoutBuilder(
                                                    builder:
                                                        (context, constraints) {
                                                      final availableWidth =
                                                          constraints.maxWidth;
                                                      final overlayChromeWidth =
                                                          _overlayChromeWidth(
                                                        showChapterNavigation:
                                                            controller
                                                                .capabilities
                                                                .supportsChapterNavigation,
                                                        showNotes: controller
                                                                .capabilities
                                                                .supportsHighlights ||
                                                            controller
                                                                .capabilities
                                                                .supportsAnnotations,
                                                        availableWidth:
                                                            availableWidth,
                                                      );
                                                      return Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      ReaderSettingsProgressCard(
                                                        key: const Key(
                                                            'reader-overlay-progress'),
                                                        forOverlay: true,
                                                        overlayWidth:
                                                            overlayChromeWidth,
                                                        chapterLabel:
                                                            readerChapterSummaryLabel(
                                                          chapters: controller
                                                              .chapters,
                                                          currentChapterIndex:
                                                              controller
                                                                  .currentChapterIndex,
                                                          loc: AppLocalizations
                                                              .of(context)!,
                                                        ),
                                                        progressListenable:
                                                            controller
                                                                .progressListenable,
                                                        showChapterNavigation:
                                                            controller
                                                                .capabilities
                                                                .supportsChapterNavigation,
                                                        onSeek: controller
                                                            .seekTo,
                                                        onPreviousChapter:
                                                            controller
                                                                .jumpToPreviousChapter,
                                                        onNextChapter:
                                                            controller
                                                                .jumpToNextChapter,
                                                      ),
                                                      const SizedBox(
                                                          height: 10),
                                                      _ReaderOverlayToolBar(
                                                          showChapterNavigation:
                                                              controller
                                                                  .capabilities
                                                                  .supportsChapterNavigation,
                                                          chromeWidth:
                                                              overlayChromeWidth,
                                                          showNotes: controller
                                                                  .capabilities
                                                                  .supportsHighlights ||
                                                              controller
                                                                  .capabilities
                                                                  .supportsAnnotations,
                                                          onOpenChapters: () =>
                                                              unawaited(
                                                            _openChapterList(
                                                              context,
                                                              controller,
                                                            ),
                                                          ),
                                                          onAddBookmark: () =>
                                                              _addBookmarkFromOverlay(
                                                            context,
                                                            controller,
                                                          ),
                                                          onOpenBookmarks: () =>
                                                              _openBookmarksPage(
                                                            context,
                                                            controller,
                                                          ),
                                                          onOpenNotes: () =>
                                                              _openNotesPage(
                                                            context,
                                                            controller,
                                                          ),
                                                          onOpenSettings: () =>
                                                              _showSettingsBottomSheet(
                                                            context,
                                                            controller,
                                                          ),
                                                      ),
                                                    ],
                                                  );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                )),

                                // 4. Edge Gesture Binding for Brightness
                                // Keep gesture preview on the shared controller to avoid
                                // duplicate writes through multiple state owners.
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
    _tapDownPosition = details.globalPosition;
    _panStartPosition = details.globalPosition;
    _isPanning = false;
  }

  void _handleTapUp(BuildContext context, TapUpDetails details) {
    // Only process tap if we weren't panning
    if (!_isPanning && _tapDownPosition != null) {
      _handleTapLogic(context, details.globalPosition);
    }
    _resetPanState();
  }

  void _handlePanStart(BuildContext context, DragStartDetails details) {
    _tapDownPosition = details.globalPosition;
    _panStartPosition = details.globalPosition;
    _isPanning = false;
  }

  void _handlePanUpdate(BuildContext context, DragUpdateDetails details) {
    if (_panStartPosition != null) {
      final distance = (details.globalPosition - _panStartPosition!).distance;
      if (distance > _swipeThreshold) {
        _isPanning = true;
      }
    }
  }

  void _handlePanEnd(BuildContext context, DragEndDetails details) {
    _resetPanState();
  }

  void _handleContentTap(
    BuildContext context,
    Offset globalPosition,
    ReaderController controller,
  ) {
    if (!_isPanning) {
      _handleTapLogic(context, globalPosition, controller: controller);
    }
  }

  void _scheduleDebouncedChapterSync(ReaderController controller) {
    _chapterSyncDebounce?.cancel();
    _chapterSyncDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      unawaited(controller.syncChapterAfterScroll());
    });
  }

  void _handleTapLogic(
    BuildContext context,
    Offset globalPosition, {
    ReaderController? controller,
  }) {
    final c = controller ?? context.read<ReaderController>();

    if (_isPanning) return;

    final now = DateTime.now();
    if (_lastTapLogicAt != null &&
        now.difference(_lastTapLogicAt!) < _tapLogicDedupWindow) {
      return;
    }
    _lastTapLogicAt = now;

    if (_showControls) {
      _setControlsVisible(false);
      return;
    }

    final box =
        _readerBodyKey.currentContext?.findRenderObject() as RenderBox?;
    final double height;
    double localY;

    if (box != null && box.hasSize) {
      height = box.size.height;
      localY = box.globalToLocal(globalPosition).dy;
    } else {
      height = MediaQuery.sizeOf(context).height;
      localY = globalPosition.dy;
    }

    if (height <= 0) return;

    // Middle 20% of the reading pane opens chrome; top/bottom 40% turn pages.
    final ratio = localY / height;
    if (ratio < 0.40) {
      unawaited(c.previousPage());
    } else if (ratio > 0.60) {
      unawaited(c.nextPage());
    } else {
      _showReaderControls(c);
    }
  }

  void _showReaderControls(ReaderController controller) {
    _setControlsVisible(true);
    unawaited(controller.syncChapterAfterScroll());
  }

  void _showSettingsBottomSheet(
      BuildContext context, ReaderController controller) {
    _showReaderControls(controller);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: NyanOverlayStyle.modalBarrierColor(context),
      builder: (BuildContext sheetContext) {
        return Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
            ),
            child: ChangeNotifierProvider<ReaderController>.value(
              value: controller,
              // Modal routes sit above the reader body; replicate software dim here
              // so the sheet matches the dimmed reading surface.
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(NyanRadius.sheet),
                ),
                child: BrightnessOverlayWidget(
                  stackFit: StackFit.passthrough,
                  stateListenable: _brightnessController.stateListenable,
                  warmthListenable: _brightnessController.warmthListenable,
                  child: ReaderMenu(
                    scaffoldKey: readerPageScaffoldKey,
                    brightnessController: _brightnessController,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      // Hide the status bar controls helper when the bottom sheet closes
      if (_showControls) {
        _setControlsVisible(false);
      }
    });
  }

  Future<void> _openChapterList(
    BuildContext context,
    ReaderController controller,
  ) async {
    _setControlsVisible(false);
    await controller.syncChapterAfterScroll();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: NyanOverlayStyle.modalBarrierColor(context),
      builder: (sheetContext) {
        final maxSheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.92;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              // Clip the whole sheet (including software dim layers) so rounded
              // corners match Reading Settings and no square dimming leaks.
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(NyanRadius.sheet),
                ),
                child: BrightnessOverlayWidget(
                  stackFit: StackFit.passthrough,
                  stateListenable: _brightnessController.stateListenable,
                  warmthListenable: _brightnessController.warmthListenable,
                  child: Material(
                    color: Theme.of(sheetContext).colorScheme.surface,
                    elevation: 6,
                    shadowColor: Theme.of(sheetContext)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.14),
                    child: ChapterListWidget(
                      bookTitle: controller.book.title,
                      bookAuthor: controller.book.author,
                      chapters: controller.chapters,
                      currentChapterIndex: controller.currentChapterIndex,
                      currentProgress: controller.currentProgress,
                      maxSheetHeight: maxSheetHeight,
                      onChapterTap: (index, locator) {
                        Navigator.of(sheetContext).pop();
                        controller.jumpToChapter(index, locator);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addBookmarkFromOverlay(
    BuildContext context,
    ReaderController controller,
  ) async {
    final added = await controller.addBookmark();
    if (!added) {
      return;
    }

    if (!mounted) {
      return;
    }

    _setControlsVisible(false);
    SnackBarUtils.show(context, 'Bookmark Added!');
  }

  Future<void> _openBookmarksPage(
    BuildContext context,
    ReaderController controller,
  ) async {
    _setControlsVisible(false);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookmarkListPage(
          bookId: controller.book.id,
          bookTitle: controller.book.title,
        ),
      ),
    );
    if (result != null && result is Map<String, dynamic>) {
      await controller.handleBookmarkSelection(result);
    }
  }

  Future<void> _openNotesPage(
    BuildContext context,
    ReaderController controller,
  ) async {
    _setControlsVisible(false);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotesListPage(
          bookId: controller.book.id,
          bookTitle: controller.book.title,
          onJumpToHighlight: (_) {},
        ),
      ),
    );

    await controller.loadHighlights();

    if (result != null && result is Highlight) {
      final selectedHighlight =
          await controller.handleHighlightSelection(result);
      if (context.mounted && selectedHighlight != null) {
        _showHighlightNoteDialog(
          context,
          controller,
          selectedHighlight,
        );
      }
    }
  }

  void _setControlsVisible(bool visible) {
    if (_showControls == visible) return;
    setState(() {
      _showControls = visible;
    });
  }

  void _resetPanState() {
    _isPanning = false;
    _panStartPosition = null;
  }

  void _showHighlightNoteDialog(
    BuildContext context,
    ReaderController controller,
    Highlight highlight,
  ) {
    showHighlightNoteDialog(
      context,
      highlight: highlight,
      onSave: (note, colorCode) => controller.updateHighlight(
        highlight.id,
        note: note,
        colorCode: colorCode,
      ),
      onDelete: () => controller.deleteHighlight(highlight.id),
    );
  }
}
