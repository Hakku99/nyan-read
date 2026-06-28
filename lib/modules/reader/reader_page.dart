import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/book.dart';
import '../../core/models/highlight.dart';
import '../../core/services/reader_preferences_service.dart';
import '../../core/services/riverpod_providers.dart';
import '../../core/theme/nyan_radius.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/theme/nyan_typography.dart';
import '../bookmark/bookmark_list_page.dart';
import '../notes/notes_list_page.dart';
import 'reader_engine/reader_engine.dart';
import 'widgets/reader_error_view.dart';
import 'widgets/highlight_note_dialog.dart';
import 'widgets/reader_menu.dart';
import 'dart:async';
import '../../l10n/app_localizations.dart';
import 'widgets/reader_chapter_summary.dart';
import 'brightness/brightness_orchestrator.dart';
import 'brightness/brightness_repository.dart';
import 'brightness/system_brightness_adapter.dart';
import 'controllers/brightness_controller.dart';
import 'controllers/reader_controller.dart';
import 'controllers/reader_controller_provider.dart';
import 'brightness/overlay_widget.dart';
import 'widgets/chapter_list_widget.dart';
import 'widgets/one_paper_dock.dart';
import 'widgets/reader_brightness_popover.dart';
import 'widgets/smooth_page_reader.dart';
import '../../core/services/reading_reminder_service.dart';
import '../../core/ui/nyan_icons.dart';
import '../../core/utils/snackbar_utils.dart';
import 'widgets/rest_reminder_overlay.dart';
import '../settings/settings_page.dart';
export 'controllers/reader_controller.dart';

part 'reader_page_overlay.dart';
part 'reader_page_gesture_handler.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final String bookId;

  const ReaderPage({super.key, required this.bookId});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with WidgetsBindingObserver {
  late Future<Map<String, dynamic>?> _bookFuture;
  late final BrightnessController _brightnessController;
  ReaderController? _boundController;
  final GlobalKey<ScaffoldState> readerPageScaffoldKey =
      GlobalKey<ScaffoldState>();
  final GlobalKey _readerBodyKey = GlobalKey();
  bool _showControls = false;

  /// One Paper: which sheet the dock has grown into (`chapters` / `settings`),
  /// or `null` when collapsed to a resting dock. `bookmarks` never sets this —
  /// it pushes a full destination page instead.
  DockAction? _openSheet;

  /// The sheet whose body is currently mounted. Lags [_openSheet] on close so
  /// the content stays visible through the collapse animation, then clears.
  DockAction? _displayedSheet;
  Timer? _sheetCloseTimer;

  /// Top-bar sun brightness popover (centered glass dialog). Mutually exclusive
  /// with [_openSheet].
  bool _brightnessPopoverOpen = false;
  Offset? _tapDownPosition;
  Offset? _panStartPosition;
  Offset? _panLastPosition;
  bool _isPanning = false;
  // Raised from 10 → 20 px: reduces false-positives from micro-jitter and
  // the first pixels of a text-selection drag.
  static const double _swipeThreshold = 20.0;
  // Minimum swipe velocity (px/s) OR delta (px) required to commit a page
  // turn from a pan gesture.  Slow drags that don't exceed either threshold
  // are suppressed so text-selection long-press-drags don't turn pages.
  static const double _swipeMinVelocity = 200.0;
  static const double _swipeMinDelta = 60.0;
  static const Duration _tapLogicDedupWindow = Duration(milliseconds: 350);
  static const Duration _pageTurnMinInterval = Duration(milliseconds: 220);
  DateTime? _lastTapLogicAt;
  DateTime? _lastPageTurnAt;
  bool _isPageTurning = false;
  Timer? _pageTurnLockTimer;
  static const Duration _pageTurnLockTimeout = Duration(seconds: 3);
  Timer? _chapterSyncDebounce;
  final GlobalKey<SmoothPageReaderState> _smoothPageReaderKey =
      GlobalKey<SmoothPageReaderState>();

  // ── Rest reminder ─────────────────────────────────────────────────────────
  late final ReadingReminderService _reminderService;
  Timer? _readingIntervalTimer;
  Timer? _countdownTimer;
  bool _showRestReminder = false;
  final ValueNotifier<int> _restSecondsRemaining = ValueNotifier(20);
  static const int _kRestCountdownSeconds = 20;

  @override
  void initState() {
    super.initState();
    final databaseService = ref.read(databaseServiceRpProvider);
    final readerPreferencesService = ref.read(readerPreferencesRpProvider);
    _bookFuture = databaseService.getBookById(widget.bookId);
    final brightnessRepository = BrightnessRepository(readerPreferencesService);
    final brightnessOrchestrator = BrightnessOrchestrator(
      repository: brightnessRepository,
      systemAdapter: SystemBrightnessAdapter(),
    );
    _brightnessController = BrightnessController(brightnessOrchestrator);
    unawaited(_brightnessController.initialize());
    // Left-edge drag reuses the same popover as the sun button — one UI for
    // brightness regardless of entry point.
    _brightnessController.isAdjusting.addListener(_onBrightnessAdjustingChanged);
    _reminderService = ref.read(readingReminderRpProvider);
    _reminderService.addListener(_onReminderSettingsChanged);
    WidgetsBinding.instance.addObserver(this);
    _setupReadingTimer();
  }

  @override
  void dispose() {
    _readingIntervalTimer?.cancel();
    _countdownTimer?.cancel();
    _restSecondsRemaining.dispose();
    _reminderService.removeListener(_onReminderSettingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    _pageTurnLockTimer?.cancel();
    _chapterSyncDebounce?.cancel();
    _sheetCloseTimer?.cancel();
    _boundController = null;
    _brightnessController.isAdjusting.removeListener(_onBrightnessAdjustingChanged);
    unawaited(_brightnessController.shutdown());
    _brightnessController.dispose();
    super.dispose();
  }

  void _onBrightnessAdjustingChanged() {
    if (!mounted) return;
    if (_brightnessController.isAdjusting.value) {
      if (_brightnessPopoverOpen) return;
      setState(() {
        _brightnessPopoverOpen = true;
        if (_openSheet != null) {
          _openSheet = null;
          _scheduleDisplayedSheetClear();
        }
      });
    } else {
      _closeBrightnessPopover();
    }
  }

  // ── Rest reminder logic ───────────────────────────────────────────────────

  void _setupReadingTimer() {
    _readingIntervalTimer?.cancel();
    if (!_reminderService.isEnabled || _showRestReminder) return;
    _readingIntervalTimer = Timer(
      Duration(minutes: _reminderService.intervalMinutes),
      _triggerRestReminder,
    );
  }

  void _onReminderSettingsChanged() => _setupReadingTimer();

  void _triggerRestReminder() {
    if (!mounted) return;
    _restSecondsRemaining.value = _kRestCountdownSeconds;
    setState(() => _showRestReminder = true);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final next = _restSecondsRemaining.value - 1;
      if (next <= 0) {
        t.cancel();
        _finishRestReminder();
      } else {
        _restSecondsRemaining.value = next;
      }
    });
  }

  void _finishRestReminder() {
    if (!mounted) return;
    _countdownTimer?.cancel();
    setState(() => _showRestReminder = false);
    _setupReadingTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _readingIntervalTimer?.cancel();
    } else if (state == AppLifecycleState.resumed && !_showRestReminder) {
      _setupReadingTimer();
    }
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

        final controllerArgs = ReaderControllerProviderArgs(
          book: book,
          brightnessController: _brightnessController,
        );
        final controller = ref.watch(
          readerControllerRpProvider(controllerArgs),
        );
        _boundController = controller;
        controller.engine.textCapability?.configureInteractions(
          onTextHighlighted: (paragraphIndex, start, end, text, colorCode) {
            final paragraphText = controller.engine.textCapability
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

        return Builder(
          builder: (context) {
            final readerPrefs = ref.watch(readerPreferencesRpProvider);
            return ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final bgColor = controller.backgroundColor;
                final loc = AppLocalizations.of(context)!;
                return PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, result) async {
                    if (didPop) return;
                    // Save progress before navigating away
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
                      stateListenable: _brightnessController.stateListenable,
                      warmthListenable: _brightnessController.warmthListenable,
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
                              child: ListenableBuilder(
                                listenable: controller,
                                builder: (context, _) {
                                  final backgroundColor =
                                      controller.backgroundColor;
                                  final hasBottomBar =
                                      controller.engine.hasBottomBar;
                                  // Controller engine reference itself is
                                  // stable; we only need it for
                                  // buildReader() + the scroll callback.
                                  // Read (not watch) to avoid adding
                                  // another subscription.
                                  final isDark =
                                      backgroundColor.computeLuminance() < 0.5;
                                  final transparentSystem = Theme.of(context)
                                      .colorScheme
                                      .surface
                                      .withValues(alpha: 0);
                                  final systemOverlayStyle = isDark
                                      ? SystemUiOverlayStyle.light.copyWith(
                                          statusBarColor: transparentSystem,
                                          systemNavigationBarColor:
                                              transparentSystem,
                                        )
                                      : SystemUiOverlayStyle.dark.copyWith(
                                          statusBarColor: transparentSystem,
                                          systemNavigationBarColor:
                                              transparentSystem,
                                        );

                                  return AnnotatedRegion<SystemUiOverlayStyle>(
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
                                                  child: readerPrefs.pageTurnMode ==
                                                          PageTurnMode.tap
                                                      ? SmoothPageReader(
                                                          key: _smoothPageReaderKey,
                                                          onPreviousTap: () {
                                                            _triggerPageTurn(
                                                              controller,
                                                              forward: false,
                                                              at: DateTime.now(),
                                                            );
                                                          },
                                                          onNextTap: () {
                                                            _triggerPageTurn(
                                                              controller,
                                                              forward: true,
                                                              at: DateTime.now(),
                                                            );
                                                          },
                                                          onCenterTap: () {
                                                            _showReaderControls(
                                                              context,
                                                              controller,
                                                            );
                                                          },
                                                          child: controller.engine
                                                              .buildReader(context),
                                                        )
                                                      : controller.engine
                                                          .buildReader(context),
                                                ),
                                              ),
                                            ),
                                            // T6: Chapter caption —
                                            // bottom-right counterpart to
                                            // the progress % label on the
                                            // left. Both fade when controls
                                            // are visible so the bottom
                                            // overlay's row takes over.
                                            Positioned(
                                              right: 16,
                                              bottom: padding.bottom > 0
                                                  ? padding.bottom + 4
                                                  : 16,
                                              child: Opacity(
                                                opacity: (_showControls ||
                                                        hasBottomBar)
                                                    ? 0
                                                    : 1,
                                                child: ConstrainedBox(
                                                  // Cap width at 45% of the
                                                  // viewport so a long chapter
                                                  // title cannot trample the
                                                  // progress % on the left.
                                                  constraints: BoxConstraints(
                                                    maxWidth:
                                                        constraints.maxWidth *
                                                            0.45,
                                                  ),
                                                  child: ListenableBuilder(
                                                    listenable: controller,
                                                    builder: (context, _) {
                                                      final loc =
                                                          AppLocalizations.of(
                                                              context)!;
                                                      final label =
                                                          readerChapterSummaryLabel(
                                                        chapters:
                                                            controller.chapters,
                                                        currentChapterIndex:
                                                            controller
                                                                .currentChapterIndex,
                                                        loc: loc,
                                                      );
                                                      return Text(
                                                        label,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        textAlign:
                                                            TextAlign.right,
                                                        style: TextStyle(
                                                          fontFamily:
                                                              NyanTypography
                                                                  .uiFontFamily,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurface
                                                              .withValues(
                                                                alpha: isDark
                                                                    ? 0.42
                                                                    : 0.5,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                  ),
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
                                                        hasBottomBar)
                                                    ? 0
                                                    : 1,
                                                child: ValueListenableBuilder<
                                                    double>(
                                                  valueListenable: controller
                                                      .progressListenable,
                                                  builder:
                                                      (context, progress, _) =>
                                                          Text(
                                                    "${(progress * 100).toInt()}%",
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(
                                                              alpha: isDark
                                                                  ? 0.42
                                                                  : 0.5),
                                                      fontWeight:
                                                          FontWeight.w600,
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
                          ListenableBuilder(
                            listenable: controller,
                            builder: (context, _) {
                              final errorState = controller.errorState;
                              if (errorState == null) {
                                return const SizedBox.shrink();
                              }
                              // Wrap in Positioned.fill to ensure it has size in the Stack
                              return Positioned.fill(
                                child: Container(
                                  color:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  child: ReaderErrorView(
                                    errorState: errorState,
                                    onBack: () => Navigator.pop(context),
                                    onRetry: controller.retry,
                                  ),
                                ),
                              );
                            },
                          ),

                          // 3. Edge Gesture Binding for Brightness
                          // Keep gesture preview on the shared controller to avoid
                          // duplicate writes through multiple state owners.
                          if (readerPrefs.edgeBrightnessGestureEnabled)
                            Positioned(
                              left: 0,
                              bottom: 0,
                              width: 50.0,
                              height: math.max(
                                72.0,
                                MediaQuery.of(context).size.height * 0.10,
                              ),
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
                                  _brightnessController.handleInteractionEnd();
                                },
                                child: const SizedBox.expand(),
                              ),
                            ),

                          // 4. Top overlay — floating paper bar: back /
                          // title + author / sun (brightness) / bookmark /
                          // more. Stays a floating inset bar (One Paper).
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: _ReaderTopOverlay(
                              visible: _showControls,
                              controller: controller,
                              onBack: () => _handleBackFromTopOverlay(
                                context,
                                controller,
                              ),
                              onAddBookmark: () =>
                                  _handleAddBookmarkFromTopOverlay(
                                context,
                                controller,
                              ),
                              onToggleBrightness: _toggleBrightnessPopover,
                              brightnessActive: _brightnessPopoverOpen,
                              onOpenSettings: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsPage(),
                                ),
                              ),
                            ),
                          ),

                          // 5. Scrim — warm-ink dim that rises with a grown
                          // sheet; tapping it collapses the dock back to a
                          // resting bar. Above the top bar (dims it), below the
                          // dock. (Canvas recede/blur added in C5.)
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: _openSheet == null,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _collapseSheet,
                                child: AnimatedOpacity(
                                  opacity: _openSheet != null ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: const Cubic(0.33, 0.9, 0.36, 1.0),
                                  // The 2px Gaussian recede is the one place
                                  // blur is used; mount the BackdropFilter only
                                  // while a sheet is open so it carries no idle
                                  // saveLayer cost during reading.
                                  child: _openSheet != null
                                      ? BackdropFilter(
                                          filter: ImageFilter.blur(
                                            sigmaX: 2,
                                            sigmaY: 2,
                                          ),
                                          child: ColoredBox(
                                            color: Theme.of(context)
                                                        .brightness ==
                                                    Brightness.dark
                                                ? const Color(0x94000000)
                                                : const Color(0x57282420),
                                          ),
                                        )
                                      : const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),

                          // 6. One Paper dock — floating panel that grows into
                          // a sheet (Settings / Chapters). Replaces the P4
                          // sticky strip. Brightness lives elsewhere (top-bar
                          // sun popover + left-edge drag), not in the dock.
                          OnePaperDock(
                            visible: _showControls,
                            sheetOpen: _openSheet != null,
                            // Title/meta/body track [_displayedSheet] so content
                            // stays mounted through the collapse animation.
                            title: _sheetTitle(loc, _displayedSheet),
                            meta: _sheetMeta(controller, loc, _displayedSheet),
                            onGrabberTap: _collapseSheet,
                            footer: DockFooter(
                              sheetOpen: _openSheet != null,
                              chapterIndex:
                                  controller.currentChapterIndex ?? -1,
                              chapterCount: controller.chapters.length,
                              progressListenable: controller.progressListenable,
                              activeAction: _openSheet,
                              onAction: (a) =>
                                  _handleDockAction(a, context, controller),
                              onPrevChapter: () => _stepChapter(controller, -1),
                              onNextChapter: () => _stepChapter(controller, 1),
                            ),
                            child: _buildSheetChild(controller, _displayedSheet),
                          ),

                          // 7. Brightness sun popover — centered glass dialog
                          // over the canvas; above the dock (only mounts while
                          // open).
                          ReaderBrightnessPopover(
                            visible: _brightnessPopoverOpen,
                            controller: _brightnessController,
                            onDismiss: _closeBrightnessPopover,
                          ),

                          // 8. Rest Reminder overlay — full-screen eye-rest
                          // nudge after the configured reading interval.
                          // Listener(opaque) ensures the reader body's
                          // HitTestBehavior.opaque GestureDetector (item 1)
                          // is never reached by the hit-test walk while the
                          // overlay is visible, so the "Continue reading"
                          // button wins the gesture arena uncontested.
                          if (_showRestReminder)
                            Positioned.fill(
                              child: Listener(
                                behavior: HitTestBehavior.opaque,
                                child: ValueListenableBuilder<int>(
                                  valueListenable: _restSecondsRemaining,
                                  builder: (_, remaining, __) =>
                                      RestReminderOverlay(
                                    remaining: remaining,
                                    total: _kRestCountdownSeconds,
                                    onSkip: _finishRestReminder,
                                  ),
                                ),
                              ),
                            ),

                        ],
                      ),
                    ),
                  ), // end Scaffold
                ); // end PopScope
              },
            );
          },
        );
      },
    );
  }

  /// P4: the bottom overlay is now a sticky strip rather than a modal sheet.
  /// Tapping the reader center toggles [_showControls]; the overlay widget
  /// renders inside the existing Stack and animates itself in/out.
  Future<void> _showQuickActionsBottomSheet(
    BuildContext context,
    ReaderController controller,
  ) async {
    if (_showControls) {
      _setControlsVisible(false);
      return;
    }
    _setControlsVisible(true);
    // Keep the chapter sync we always did before showing the overlay so the
    // chapter label is fresh when the dock appears.
    await controller.syncChapterAfterScroll();
    if (!mounted) return;
  }

  // ── One Paper dock state machine ─────────────────────────────────────────

  /// Header title for the grown sheet (driven by [_displayedSheet]).
  String? _sheetTitle(AppLocalizations loc, DockAction? sheet) {
    switch (sheet) {
      case DockAction.settings:
        return loc.readingSettings;
      case DockAction.chapters:
        return loc.readerDockChapters;
      case DockAction.bookmarks:
      case DockAction.highlights:
      case null:
        return null;
    }
  }

  /// Header trailing meta for the grown sheet ("42% read" / "184 chapters").
  String? _sheetMeta(
    ReaderController controller,
    AppLocalizations loc,
    DockAction? sheet,
  ) {
    switch (sheet) {
      case DockAction.settings:
        final pct = (controller.currentProgress.clamp(0.0, 1.0) * 100).round();
        return loc.readerSettingsProgressHint(pct);
      case DockAction.chapters:
        return loc.chapterCount(controller.chapters.length);
      case DockAction.bookmarks:
      case DockAction.highlights:
      case null:
        return null;
    }
  }

  /// The grown-sheet body — the existing settings / chapters widgets rendered
  /// chromeless inside the dock. Driven by [_displayedSheet] so content stays
  /// mounted through the collapse animation; `null` once fully collapsed.
  Widget? _buildSheetChild(ReaderController controller, DockAction? sheet) {
    switch (sheet) {
      case DockAction.settings:
        return ReaderMenu(
          controller: controller,
          scaffoldKey: readerPageScaffoldKey,
          brightnessController: _brightnessController,
          showSheetChrome: false,
          showHeader: false,
        );
      case DockAction.chapters:
        return ChapterListWidget(
          bookTitle: controller.book.title,
          bookAuthor: controller.book.author,
          chapters: controller.chapters,
          currentChapterIndex: controller.currentChapterIndex,
          currentProgress: controller.currentProgress,
          // The dock's Flexible bounds the real height; this only feeds the
          // (now-bypassed) compact heuristic, so a nominal value is fine.
          maxSheetHeight: 520,
          showSheetChrome: false,
          showHeader: false,
          onChapterTap: (index, locator) {
            controller.jumpToChapter(index, locator);
            _collapseSheet();
          },
        );
      case DockAction.bookmarks:
      case DockAction.highlights:
      case null:
        return null;
    }
  }

  /// Dispatch a dock footer action: chapters/settings grow the dock in place;
  /// bookmarks and highlights push destination pages (collapsing any open sheet first).
  void _handleDockAction(
    DockAction action,
    BuildContext context,
    ReaderController controller,
  ) {
    switch (action) {
      case DockAction.bookmarks:
        _collapseSheet();
        unawaited(_openBookmarksPage(context, controller));
      case DockAction.highlights:
        _collapseSheet();
        unawaited(_openHighlightsPage(context, controller));
      case DockAction.chapters:
      case DockAction.settings:
        _toggleSheet(action, controller);
    }
  }

  /// Grow the dock into [action]'s sheet, or collapse it if already open.
  void _toggleSheet(DockAction action, ReaderController controller) {
    final willOpen = _openSheet != action;
    if (willOpen && action == DockAction.chapters) {
      // Freshen the current-chapter highlight before the list appears.
      unawaited(controller.syncChapterAfterScroll());
    }
    _sheetCloseTimer?.cancel();
    setState(() {
      if (willOpen) {
        _openSheet = action;
        _displayedSheet = action;
        // Opening a sheet implies chrome up + the brightness popover closed.
        _showControls = true;
        _brightnessPopoverOpen = false;
      } else {
        _openSheet = null;
        _scheduleDisplayedSheetClear();
      }
    });
  }

  /// Collapse a grown sheet back to a resting dock.
  void _collapseSheet() {
    if (_openSheet == null) return;
    setState(() => _openSheet = null);
    _scheduleDisplayedSheetClear();
  }

  /// Clear the mounted sheet body after the collapse animation finishes, so the
  /// content fades out with the dock rather than vanishing on the first frame.
  void _scheduleDisplayedSheetClear() {
    _sheetCloseTimer?.cancel();
    // Matches OnePaperDock's --dur-grow (320ms) collapse.
    _sheetCloseTimer = Timer(const Duration(milliseconds: 320), () {
      if (!mounted || _openSheet != null || _displayedSheet == null) return;
      setState(() => _displayedSheet = null);
    });
  }

  /// Toggle the top-bar brightness popover (mutually exclusive with a sheet).
  void _toggleBrightnessPopover() {
    setState(() {
      _brightnessPopoverOpen = !_brightnessPopoverOpen;
      if (_brightnessPopoverOpen && _openSheet != null) {
        _openSheet = null;
        _scheduleDisplayedSheetClear();
      }
    });
  }

  void _closeBrightnessPopover() {
    if (!_brightnessPopoverOpen) return;
    setState(() => _brightnessPopoverOpen = false);
  }

  /// Step one chapter via the dock footer carets. Calls the existing
  /// [ReaderController.jumpToChapter] — pagination/position math is untouched.
  Future<void> _stepChapter(ReaderController controller, int delta) async {
    final current = controller.currentChapterIndex;
    if (current == null) return;
    final target = current + delta;
    if (target < 0 || target >= controller.chapters.length) return;
    HapticFeedback.selectionClick();
    await controller.jumpToChapter(target, controller.chapters[target].locator);
  }

  /// Top-bar back button: saves reading progress and shuts down brightness
  /// before popping. Mirrors the [PopScope.onPopInvokedWithResult] flow so both
  /// paths (hardware back / overlay back button) reach the same exit sequence.
  Future<void> _handleBackFromTopOverlay(
    BuildContext context,
    ReaderController controller,
  ) async {
    _setControlsVisible(false);
    await controller.saveBeforeExit();
    await _brightnessController.shutdown();
    if (context.mounted) Navigator.of(context).pop();
  }

  /// Top-bar bookmark button: saves a bookmark at the current reading position
  /// and shows a brief response toast confirming the action.
  Future<void> _handleAddBookmarkFromTopOverlay(
    BuildContext context,
    ReaderController controller,
  ) async {
    final added = await controller.addBookmark();
    if (!added || !context.mounted) return;
    final loc = AppLocalizations.of(context)!;
    SnackBarUtils.show(context, loc.bookmarkAdded, tone: NyanSnackTone.success);
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

  Future<void> _openHighlightsPage(
    BuildContext context,
    ReaderController controller,
  ) async {
    _setControlsVisible(false);
    // NotesListPage pops with the tapped Highlight when onJumpToHighlight is
    // non-null. Passing a no-op enables the tap-to-navigate affordance; the
    // actual jump is handled here after the page returns.
    final result = await Navigator.push<Highlight>(
      context,
      MaterialPageRoute(
        builder: (_) => NotesListPage(
          bookId: controller.book.id,
          bookTitle: controller.book.title,
          onJumpToHighlight: (_) {},
        ),
      ),
    );
    if (result != null && !mounted) return;
    if (result != null) {
      await controller.handleBookmarkSelection({
        'position_type': controller.book.format,
        'position_payload': '{"paragraphIndex": ${result.paragraphIndex}}',
      });
    }
  }

  void _setControlsVisible(bool visible) {
    // Hiding chrome also collapses any grown sheet / brightness popover.
    if (_showControls == visible &&
        (visible || (_openSheet == null && !_brightnessPopoverOpen))) {
      return;
    }
    setState(() {
      _showControls = visible;
      if (!visible) {
        _openSheet = null;
        _brightnessPopoverOpen = false;
      }
    });
    if (!visible) _scheduleDisplayedSheetClear();
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

  Future<void> _dispatchPageTurn(
    ReaderController controller, {
    required bool forward,
  }) async {
    if (controller.settingsManager.preferences.pageTurnMode ==
        PageTurnMode.tap) {
      final smoothState = _smoothPageReaderKey.currentState;
      if (smoothState != null && !smoothState.isAnimating) {
        await smoothState.playTurn(
          forward: forward,
          dispatchTurn: () async {
            if (forward) {
              await controller.nextPage();
            } else {
              await controller.previousPage();
            }
          },
        );
        return;
      }
    }

    if (forward) {
      await controller.nextPage();
    } else {
      await controller.previousPage();
    }
  }

}
