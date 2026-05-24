import 'package:flutter/services.dart';
import 'dart:math' as math;

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
import 'reader_engine/reader_engine.dart';
import 'widgets/reader_error_view.dart';
import 'widgets/highlight_note_dialog.dart';
import 'widgets/reader_menu.dart';
import 'dart:async';
import '../../core/ui/components/nyan_overlay_style.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/reader_chapter_summary.dart';
import 'widgets/reader_settings/reader_settings_display_panel.dart';
import 'brightness/brightness_orchestrator.dart';
import 'brightness/brightness_repository.dart';
import 'brightness/system_brightness_adapter.dart';
import 'controllers/brightness_controller.dart';
import 'controllers/reader_controller.dart';
import 'controllers/reader_controller_provider.dart';
import 'brightness/overlay_widget.dart';
import 'widgets/brightness_hud_widget.dart';
import 'widgets/chapter_list_widget.dart';
import 'widgets/smooth_page_reader.dart';
import '../../core/ui/nyan_icons.dart';
export 'controllers/reader_controller.dart';

part 'reader_page_overlay.dart';
part 'reader_page_gesture_handler.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final String bookId;

  const ReaderPage({super.key, required this.bookId});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  late Future<Map<String, dynamic>?> _bookFuture;
  late final BrightnessController _brightnessController;
  ReaderController? _boundController;
  final GlobalKey<ScaffoldState> readerPageScaffoldKey =
      GlobalKey<ScaffoldState>();
  final GlobalKey _readerBodyKey = GlobalKey();
  bool _showControls = false;
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
  }

  @override
  void dispose() {
    _pageTurnLockTimer?.cancel();
    _chapterSyncDebounce?.cancel();
    _boundController = null;
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
                                                          PageTurnMode.leftRight
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

                          // 4. P4 bottom overlay — sticky strip with
                          // 4-tile dock. Sits in the Stack so it lives within
                          // the same brightness-overlay-affected region as the
                          // reader engine. IgnorePointer wrapper inside the
                          // widget makes it pass-through when hidden.
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _ReaderBottomOverlay(
                              visible: _showControls,
                              controller: controller,
                              onOpenChapters: () => _handleOverlayTile(
                                () => _openChapterList(context, controller),
                              ),
                              onOpenBookmarks: () => _handleOverlayTile(
                                () => _openBookmarksPage(context, controller),
                              ),
                              onOpenBrightness: () => _handleOverlayTile(
                                () => _openReaderBrightness(
                                  context,
                                  controller,
                                ),
                              ),
                              onOpenSettings: () => _handleOverlayTile(
                                () => _openReaderSettings(context, controller),
                              ),
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

  /// Tile-press handler: dismiss the overlay strip first (so its slide-out
  /// can run in parallel with the child sheet's slide-in), then fire the
  /// destination action. Each [_open*] helper itself calls [_setControlsVisible]
  /// internally but we set it eagerly to avoid a frame where both layers are
  /// visible.
  void _handleOverlayTile(VoidCallback action) {
    _setControlsVisible(false);
    action();
  }

  /// Brightness tile destination — slim modal sheet with the brightness +
  /// warmth + auto-brightness controls reused from the full reader menu.
  Future<void> _openReaderBrightness(
    BuildContext context,
    ReaderController controller,
  ) async {
    if (!context.mounted) return;
    await _showReaderBrightnessSheet(
      context: context,
      brightnessController: _brightnessController,
      readerController: controller,
    );
  }

  /// Settings tile destination — opens the full [ReaderMenu] as a standalone
  /// modal bottom sheet. Replaces the old in-sheet Quick/Full toggle path.
  Future<void> _openReaderSettings(
    BuildContext context,
    ReaderController controller,
  ) async {
    if (!context.mounted) return;
    await _showReaderSettingsSheet(
      context: context,
      readerController: controller,
      brightnessController: _brightnessController,
      scaffoldKey: readerPageScaffoldKey,
    );
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
      backgroundColor:
          Theme.of(context).colorScheme.surface.withValues(alpha: 0),
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
                      maxSheetHeight: maxSheetHeight -
                          MediaQuery.viewPaddingOf(sheetContext).bottom,
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

  void _setControlsVisible(bool visible) {
    if (_showControls == visible) return;
    setState(() {
      _showControls = visible;
    });
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
        PageTurnMode.leftRight) {
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
