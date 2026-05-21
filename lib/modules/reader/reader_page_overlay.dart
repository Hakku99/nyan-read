part of 'reader_page.dart';

class _ReaderQuickToolRow extends StatelessWidget {
  const _ReaderQuickToolRow({
    required this.showChapterNavigation,
    required this.showNotes,
    required this.onOpenChapters,
    required this.onAddBookmark,
    required this.onOpenBookmarks,
    required this.onOpenNotes,
    required this.onOpenSettings,
    required this.chromeWidth,
    required this.edgeBrightnessGestureEnabled,
    required this.onToggleEdgeBrightnessGesture,
  });

  final bool showChapterNavigation;
  final bool showNotes;
  final VoidCallback onOpenChapters;
  final VoidCallback onAddBookmark;
  final VoidCallback onOpenBookmarks;
  final VoidCallback onOpenNotes;
  final VoidCallback onOpenSettings;
  final double chromeWidth;
  final bool edgeBrightnessGestureEnabled;
  final VoidCallback onToggleEdgeBrightnessGesture;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final actions = <Widget>[
      if (showChapterNavigation)
        ReaderOverlayToolButton(
          icon: NyanIcons.tableOfContents,
          onTap: onOpenChapters,
          transparentBackground: true,
        ),
      ReaderOverlayToolButton(
        icon: NyanIcons.bookmark,
        onTap: onAddBookmark,
        transparentBackground: true,
      ),
      ReaderOverlayToolButton(
        icon: NyanIcons.bookmarks,
        onTap: onOpenBookmarks,
        transparentBackground: true,
      ),
      if (showNotes)
        ReaderOverlayToolButton(
          icon: NyanIcons.editNote,
          onTap: onOpenNotes,
          transparentBackground: true,
        ),
      ReaderOverlayToolButton(
        icon: NyanIcons.brightness,
        onTap: onToggleEdgeBrightnessGesture,
        isAccent: edgeBrightnessGestureEnabled,
        transparentBackground: true,
        tooltip: edgeBrightnessGestureEnabled
            ? loc.readerEdgeBrightnessOn
            : loc.readerEdgeBrightnessOff,
      ),
      ReaderOverlayToolButton(
        icon: NyanIcons.tune,
        onTap: onOpenSettings,
        isAccent: true,
        transparentBackground: true,
      ),
    ];

    return Center(
      child: SizedBox(
        key: const Key('reader-overlay-toolbar'),
        width: chromeWidth,
        child: Padding(
          padding: kReaderOverlayChromePadding,
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
      ),
    );
  }
}

class _QuickEdgeBrightnessRemark extends StatelessWidget {
  const _QuickEdgeBrightnessRemark({
    required this.edgeEnabled,
    required this.label,
  });

  final bool edgeEnabled;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NyanSpacing.space12,
        NyanSpacing.space4,
        NyanSpacing.space12,
        0,
      ),
      child: Row(
        children: [
          Icon(
            NyanIcons.brightness,
            size: 14,
            color: theme.colorScheme.primary.withValues(alpha: 0.56),
          ),
          const SizedBox(width: NyanSpacing.space8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w400,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsDock extends StatelessWidget {
  const _QuickActionsDock({
    required this.showChapterNavigation,
    required this.showNotes,
    required this.overlayChromeWidth,
    required this.onOpenChapters,
    required this.onAddBookmark,
    required this.onOpenBookmarks,
    required this.onOpenNotes,
    required this.onOpenSettings,
    required this.edgeBrightnessGestureEnabled,
    required this.onToggleEdgeBrightnessGesture,
  });

  final bool showChapterNavigation;
  final bool showNotes;
  final double overlayChromeWidth;
  final VoidCallback onOpenChapters;
  final VoidCallback onAddBookmark;
  final VoidCallback onOpenBookmarks;
  final VoidCallback onOpenNotes;
  final VoidCallback onOpenSettings;
  final bool edgeBrightnessGestureEnabled;
  final VoidCallback onToggleEdgeBrightnessGesture;

  @override
  Widget build(BuildContext context) {
    return _ReaderQuickToolRow(
      showChapterNavigation: showChapterNavigation,
      chromeWidth: overlayChromeWidth,
      showNotes: showNotes,
      onOpenChapters: onOpenChapters,
      onAddBookmark: onAddBookmark,
      onOpenBookmarks: onOpenBookmarks,
      onOpenNotes: onOpenNotes,
      onOpenSettings: onOpenSettings,
      edgeBrightnessGestureEnabled: edgeBrightnessGestureEnabled,
      onToggleEdgeBrightnessGesture: onToggleEdgeBrightnessGesture,
    );
  }
}

class _QuickNowReadingSection extends StatelessWidget {
  const _QuickNowReadingSection({
    required this.controller,
    required this.loc,
    required this.showChapterNavigation,
  });

  final ReaderController controller;
  final AppLocalizations loc;
  final bool showChapterNavigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ReaderSettingsProgressCard(
        key: const Key('reader-overlay-progress'),
        forQuickSheet: true,
        chapterLabel: readerChapterSummaryLabel(
          chapters: controller.chapters,
          currentChapterIndex: controller.currentChapterIndex,
          loc: loc,
        ),
        progressListenable: controller.progressListenable,
        showChapterNavigation: showChapterNavigation,
        onSeek: controller.seekTo,
        onPreviousChapter: controller.jumpToPreviousChapter,
        onNextChapter: controller.jumpToNextChapter,
      ),
    );
  }
}

class _QuickLayerCardShell extends StatelessWidget {
  const _QuickLayerCardShell({
    required this.nowReadingZone,
    required this.quickActionsZone,
    required this.remarkZone,
  });

  final Widget nowReadingZone;
  final Widget quickActionsZone;
  final Widget remarkZone;

  @override
  Widget build(BuildContext context) {
    return NyanSheetCard(
      radius: NyanRadius.card,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NyanSpacing.space16,
            NyanSpacing.space16,
            NyanSpacing.space16,
            NyanSpacing.space16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              nowReadingZone,
              const SizedBox(height: NyanSpacing.space8),
              Container(
                height: 1,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
              ),
              const SizedBox(height: NyanSpacing.space8),
              quickActionsZone,
              remarkZone,
            ],
          ),
        ),
      ],
    );
  }
}

double _overlayChromeWidth({
  required bool showChapterNavigation,
  required bool showNotes,
  required double availableWidth,
  double horizontalSafeGutter = 4,
}) {
  final actionCount =
      2 + (showChapterNavigation ? 1 : 0) + (showNotes ? 1 : 0) + 1 + 1;
  final buttonWidth = NyanSpacing.minTapTarget;
  final innerSpacing = NyanSpacing.space8 * (actionCount - 1);
  final sidePadding = kReaderOverlayChromePadding.horizontal;
  final targetWidth = (actionCount * buttonWidth) + innerSpacing + sidePadding;
  final maxAllowed = math.max(0.0, availableWidth - horizontalSafeGutter);
  return math.min(targetWidth, maxAllowed);
}

enum _ReaderSheetPage { quick, full }

class _ReaderQuickActionsSheet extends StatefulWidget {
  const _ReaderQuickActionsSheet({
    required this.controller,
    required this.readerPreferences,
    required this.scaffoldKey,
    required this.onOpenChapters,
    required this.onAddBookmark,
    required this.onOpenBookmarks,
    required this.onOpenNotes,
    required this.brightnessController,
  });

  final ReaderController controller;
  final ReaderPreferencesService readerPreferences;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final VoidCallback onOpenChapters;
  final VoidCallback onAddBookmark;
  final VoidCallback onOpenBookmarks;
  final VoidCallback onOpenNotes;
  final BrightnessController brightnessController;

  @override
  State<_ReaderQuickActionsSheet> createState() =>
      _ReaderQuickActionsSheetState();
}

class _ReaderQuickActionsSheetState extends State<_ReaderQuickActionsSheet> {
  _ReaderSheetPage _activePage = _ReaderSheetPage.quick;

  void _switchToFull() {
    HapticFeedback.lightImpact();
    if (_activePage == _ReaderSheetPage.full) return;
    setState(() {
      _activePage = _ReaderSheetPage.full;
    });
  }

  void _switchToQuick() {
    HapticFeedback.lightImpact();
    if (_activePage == _ReaderSheetPage.quick) return;
    setState(() {
      _activePage = _ReaderSheetPage.quick;
    });
  }

  Widget _buildFullBody({
    required double bottomInset,
  }) {
    return ReaderMenu(
      controller: widget.controller,
      scaffoldKey: widget.scaffoldKey,
      brightnessController: widget.brightnessController,
      showSheetChrome: false,
      showHeader: false,
      bottomInsetOverride: bottomInset,
    );
  }

  Widget _buildQuickBody({
    required BuildContext context,
    required AppLocalizations loc,
    required double bottomInset,
    required bool showChapterNavigation,
    required bool showNotes,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Quick layer only: add visual breathing room under the card before the
        // home-indicator safe area.
        const tailGap = NyanSpacing.space12;
        final contentPadding = EdgeInsets.fromLTRB(
          NyanSpacing.space20,
          0,
          NyanSpacing.space20,
          tailGap + bottomInset,
        );
        final innerWidth = math.max(
          0.0,
          constraints.maxWidth - NyanSpacing.space20 * 2,
        );
        final overlayChromeWidth = _overlayChromeWidth(
          showChapterNavigation: showChapterNavigation,
          showNotes: showNotes,
          availableWidth: innerWidth,
          horizontalSafeGutter: 0,
        );
        return SingleChildScrollView(
          padding: contentPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _QuickLayerCardShell(
                nowReadingZone: _QuickNowReadingSection(
                  controller: widget.controller,
                  loc: loc,
                  showChapterNavigation: showChapterNavigation,
                ),
                quickActionsZone: ListenableBuilder(
                  listenable: widget.readerPreferences,
                  builder: (context, _) {
                    return _QuickActionsDock(
                      showChapterNavigation: showChapterNavigation,
                      overlayChromeWidth: overlayChromeWidth,
                      showNotes: showNotes,
                      onOpenChapters: widget.onOpenChapters,
                      onAddBookmark: widget.onAddBookmark,
                      onOpenBookmarks: widget.onOpenBookmarks,
                      onOpenNotes: widget.onOpenNotes,
                      onOpenSettings: _switchToFull,
                      edgeBrightnessGestureEnabled:
                          widget.readerPreferences.edgeBrightnessGestureEnabled,
                      onToggleEdgeBrightnessGesture: () {
                        HapticFeedback.selectionClick();
                        unawaited(
                          widget.readerPreferences.setEdgeBrightnessGestureEnabled(
                            !widget
                                .readerPreferences.edgeBrightnessGestureEnabled,
                          ),
                        );
                      },
                    );
                  },
                ),
                remarkZone: ListenableBuilder(
                  listenable: widget.readerPreferences,
                  builder: (context, _) {
                    final edgeEnabled =
                        widget.readerPreferences.edgeBrightnessGestureEnabled;
                    return _QuickEdgeBrightnessRemark(
                      edgeEnabled: edgeEnabled,
                      label: edgeEnabled
                          ? loc.readerEdgeBrightnessOn
                          : loc.readerEdgeBrightnessOff,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFixedHeader({
    required BuildContext context,
    required AppLocalizations loc,
  }) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.08,
      height: 1.2,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.92),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NyanSpacing.space20),
      child: SizedBox(
        height: NyanSpacing.minTapTarget,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: NyanSpacing.space4 / 2),
                child: Text(
                  loc.readingSettings,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
            ),
            const SizedBox(width: NyanSpacing.space8),
            Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(NyanRadius.input),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.16),
                  width: 0.8,
                ),
              ),
              child: ReaderLayerModeToggle(
                quickSelected: _activePage == _ReaderSheetPage.quick,
                quickTooltip: loc.readingSettings,
                fullTooltip: loc.readerQuickOpenFullSettings,
                onTapQuick: _switchToQuick,
                onTapFull: _switchToFull,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    const bottomInset = 0.0;
    final showChapterNavigation =
        widget.controller.capabilities.supportsChapterNavigation;
    final showNotes = widget.controller.capabilities.supportsHighlights ||
        widget.controller.capabilities.supportsAnnotations;

    const maxHeightFactor = 0.78;
    final maxSheetHeight = MediaQuery.sizeOf(context).height * maxHeightFactor;

    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1.0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: maxSheetHeight,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(NyanRadius.sheet),
          ),
          child: BrightnessOverlayWidget(
            stackFit: StackFit.passthrough,
            stateListenable: widget.brightnessController.stateListenable,
            warmthListenable: widget.brightnessController.warmthListenable,
            child: Container(
              decoration: BoxDecoration(
                color: theme.bottomSheetTheme.backgroundColor ?? theme.cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(NyanRadius.sheet),
                ),
                boxShadow: NyanOverlayStyle.dialogShadow(context),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: NyanSpacing.space12),
                    Center(
                      child: Container(
                        width: 40,
                        height: NyanSpacing.space4,
                        decoration: BoxDecoration(
                          color: theme.dividerColor.withValues(alpha: 0.44),
                          borderRadius: BorderRadius.circular(NyanRadius.small),
                        ),
                      ),
                    ),
                    const SizedBox(height: NyanSpacing.space12),
                    _buildFixedHeader(context: context, loc: loc),
                    const SizedBox(height: NyanSpacing.space12),
                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeInOutCubic,
                        alignment: Alignment.topCenter,
                        child: KeyedSubtree(
                          key: ValueKey<_ReaderSheetPage>(_activePage),
                          child: _activePage == _ReaderSheetPage.quick
                              ? _buildQuickBody(
                                  context: context,
                                  loc: loc,
                                  bottomInset: bottomInset,
                                  showChapterNavigation: showChapterNavigation,
                                  showNotes: showNotes,
                                )
                              : _buildFullBody(
                                  bottomInset: bottomInset,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
