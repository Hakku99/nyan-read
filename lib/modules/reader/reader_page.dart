import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/book.dart';
import '../../core/models/highlight.dart';
import '../../core/services/database_service.dart';
import '../../core/services/reader_preferences_service.dart';
import '../../core/services/service_locator.dart';
import '../../core/theme/nyan_radius.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/utils/snackbar_utils.dart';
import '../bookmark/bookmark_list_page.dart';
import '../notes/notes_list_page.dart';
import 'reader_engine/reader_engine.dart';
import 'reader_error.dart';
import 'widgets/reader_error_view.dart';
import 'widgets/highlight_note_dialog.dart';
import 'widgets/reader_menu.dart';
import 'dart:async';
import '../../core/ui/components/nyan_overlay_style.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/reader_chapter_summary.dart';
import 'widgets/reader_settings/reader_settings_progress_card.dart';
import 'brightness/brightness_orchestrator.dart';
import 'brightness/brightness_repository.dart';
import 'brightness/system_brightness_adapter.dart';
import 'controllers/brightness_controller.dart';
import 'controllers/reader_controller.dart';
import 'brightness/overlay_widget.dart';
import 'widgets/brightness_hud_widget.dart';
import 'widgets/chapter_list_widget.dart';
import 'widgets/reader_overlay_tool_button.dart';
import 'widgets/reader_settings/reader_settings_common.dart';
export 'controllers/reader_controller.dart';

part 'reader_page_overlay.dart';
part 'reader_page_gesture_handler.dart';

class ReaderPage extends StatefulWidget {
  final String bookId;

  const ReaderPage({super.key, required this.bookId});

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
                                if (errorState == null) {
                                  return const SizedBox.shrink();
                                }
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
    if (!context.mounted) {
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
