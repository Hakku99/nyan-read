part of 'reader_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// P4 (2026-05): Reader bottom overlay rewritten to match the Claude Design
// system spec (`ReaderScreen.jsx` bottom block):
//   • Sticky bottom strip (not a modal bottom sheet)
//   • Paper-bg @ 92% + 0.5pt top hairline at ink @ 8%
//   • Row: "Chapter X" (left, 11/w400 @ 60%) + "{N}%" (right, 12/w500 @ 70%)
//   • 4pt progress bar (ink @ 14% bg / ink @ 60% fill, radius 999)
//   • 4-tile dock (icon + label below): Chapters / Bookmarks / Brightness /
//     Settings. No edge-brightness toggle / add-bookmark / notes tiles
//     (intentional per spec; those flows live elsewhere).
//   • Quick / Full layer toggle removed: the Settings tile opens the full
//     ReaderMenu as its own modal sheet.
// ─────────────────────────────────────────────────────────────────────────────

const Duration _kReaderOverlayAnimDuration = Duration(milliseconds: 220);
const Curve _kReaderOverlayAnimCurve = Curves.easeOutCubic;

/// Sticky bottom strip overlay. The widget is always laid out at the bottom
/// of the parent Stack; visibility is controlled by [visible] which drives
/// the slide + fade animation. When hidden it is also wrapped in
/// [IgnorePointer] so it does not intercept taps on the reader body below.
class _ReaderBottomOverlay extends StatelessWidget {
  const _ReaderBottomOverlay({
    required this.visible,
    required this.controller,
    required this.onOpenChapters,
    required this.onOpenBookmarks,
    required this.onOpenBrightness,
    required this.onOpenSettings,
  });

  final bool visible;
  final ReaderController controller;
  final VoidCallback onOpenChapters;
  final VoidCallback onOpenBookmarks;
  final VoidCallback onOpenBrightness;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final ink = theme.colorScheme.onSurface;
    final paperBg = theme.scaffoldBackgroundColor;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1),
        duration: _kReaderOverlayAnimDuration,
        curve: _kReaderOverlayAnimCurve,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: GestureDetector(
            // Consume taps so they don't bubble up to the reader body and
            // immediately toggle the overlay back off.
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: paperBg.withValues(alpha: 0.92),
                border: Border(
                  top: BorderSide(
                    color: ink.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    NyanSpacing.space16,
                    NyanSpacing.space12,
                    NyanSpacing.space16,
                    NyanSpacing.space16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ReaderBottomOverlayProgress(
                        controller: controller,
                        ink: ink,
                        loc: loc,
                      ),
                      const SizedBox(height: NyanSpacing.space8),
                      _ReaderBottomOverlayDock(
                        ink: ink,
                        loc: loc,
                        onOpenChapters: onOpenChapters,
                        onOpenBookmarks: onOpenBookmarks,
                        onOpenBrightness: onOpenBrightness,
                        onOpenSettings: onOpenSettings,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Progress block: chapter label (left) / percent (right) on top of a 4pt
/// non-interactive progress bar. Subscribes to the chapter-changing parts of
/// the controller and to the high-frequency [ReaderController.progressListenable]
/// separately so the percent text repaints without rebuilding the chapter row.
class _ReaderBottomOverlayProgress extends StatelessWidget {
  const _ReaderBottomOverlayProgress({
    required this.controller,
    required this.ink,
    required this.loc,
  });

  final ReaderController controller;
  final Color ink;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final label = readerChapterSummaryLabel(
                    chapters: controller.chapters,
                    currentChapterIndex: controller.currentChapterIndex,
                    loc: loc,
                  );
                  return Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: NyanTypography.uiFontFamily,
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w400,
                      color: ink.withValues(alpha: 0.6),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: NyanSpacing.space8),
            ValueListenableBuilder<double>(
              valueListenable: controller.progressListenable,
              builder: (context, progress, _) => Text(
                '${(progress.clamp(0.0, 1.0) * 100).round()}%',
                style: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: ink.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: NyanSpacing.space8),
        ValueListenableBuilder<double>(
          valueListenable: controller.progressListenable,
          builder: (context, progress, _) => ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: ink.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(
                ink.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 4-tile bottom dock — icon + label below. Matches spec layout:
/// `space-around` distribution, 8/12px padding per tile, icon 20pt @ 0.85
/// opacity, label 11/w500 @ 0.75 opacity.
class _ReaderBottomOverlayDock extends StatelessWidget {
  const _ReaderBottomOverlayDock({
    required this.ink,
    required this.loc,
    required this.onOpenChapters,
    required this.onOpenBookmarks,
    required this.onOpenBrightness,
    required this.onOpenSettings,
  });

  final Color ink;
  final AppLocalizations loc;
  final VoidCallback onOpenChapters;
  final VoidCallback onOpenBookmarks;
  final VoidCallback onOpenBrightness;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    // Each tile is wrapped in [Expanded] so the dock occupies the full width
    // evenly — prevents horizontal overflow when localized labels run long
    // (e.g. EN "Reading Settings" / "Table of Contents" used to push the row
    // 25px past the strip's right edge on a 360-wide viewport).
    return Row(
      children: [
        Expanded(
          child: _ReaderBottomDockTile(
            icon: NyanIcons.tableOfContents,
            label: loc.readerDockChapters,
            ink: ink,
            onTap: onOpenChapters,
          ),
        ),
        Expanded(
          child: _ReaderBottomDockTile(
            icon: NyanIcons.bookmarks,
            label: loc.bookmarks,
            ink: ink,
            onTap: onOpenBookmarks,
          ),
        ),
        Expanded(
          child: _ReaderBottomDockTile(
            icon: NyanIcons.brightness,
            label: loc.readerBrightness,
            ink: ink,
            onTap: onOpenBrightness,
          ),
        ),
        Expanded(
          child: _ReaderBottomDockTile(
            icon: NyanIcons.tune,
            label: loc.settingsTitle,
            ink: ink,
            onTap: onOpenSettings,
          ),
        ),
      ],
    );
  }
}

class _ReaderBottomDockTile extends StatelessWidget {
  const _ReaderBottomDockTile({
    required this.icon,
    required this.label,
    required this.ink,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      radius: 32,
      child: Padding(
        // Horizontal padding kept small (4pt) because tiles are wrapped in
        // [Expanded] in the dock — the parent already enforces a uniform
        // width slice per tile, so we only need a hair of inset around the
        // touch target.
        padding: const EdgeInsets.symmetric(
          horizontal: NyanSpacing.space4,
          vertical: NyanSpacing.space8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: ink.withValues(alpha: 0.85),
            ),
            const SizedBox(height: NyanSpacing.space4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: NyanTypography.uiFontFamily,
                fontSize: 11,
                height: 1.0,
                fontWeight: FontWeight.w500,
                color: ink.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top overlay — slides in from the top, mirrors the bottom overlay's animation.
// Per ReaderScreen.jsx spec: back button | title + author | bookmark | more.
// ─────────────────────────────────────────────────────────────────────────────

/// Sticky top-strip overlay showing book title/author and quick action buttons.
/// [visible] drives the same AnimatedSlide + AnimatedOpacity used by
/// [_ReaderBottomOverlay], but offset is `(0, -1)` when hidden so it slides up
/// off-screen. The bottom border mirrors the bottom overlay's top hairline.
class _ReaderTopOverlay extends StatelessWidget {
  const _ReaderTopOverlay({
    required this.visible,
    required this.controller,
    required this.onBack,
    required this.onAddBookmark,
    required this.onOpenSettings,
  });

  final bool visible;
  final ReaderController controller;
  final VoidCallback onBack;
  final VoidCallback onAddBookmark;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final paperBg = theme.scaffoldBackgroundColor;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -1),
        duration: _kReaderOverlayAnimDuration,
        curve: _kReaderOverlayAnimCurve,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: GestureDetector(
            // Consume taps so they don't fall through to the reader body.
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: paperBg.withValues(alpha: 0.92),
                border: Border(
                  // Mirror of the bottom overlay's top hairline, flipped to
                  // the bottom edge so the strip has a clear lower boundary.
                  bottom: BorderSide(
                    color: ink.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NyanSpacing.space4,
                    vertical: NyanSpacing.space8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _TopOverlayIconButton(
                        icon: NyanIcons.back,
                        ink: ink,
                        onTap: onBack,
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              controller.book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: NyanTypography.uiFontFamily,
                                // 14pt is the button-label compact size —
                                // reused here for the title chip so it's
                                // visually heavier than the 11pt author line
                                // without overstepping the section (20pt) tier.
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                                color: ink.withValues(alpha: 0.88),
                              ),
                            ),
                            if (controller.book.author.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                controller.book.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: NyanTypography.uiFontFamily,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  height: 1.2,
                                  color: ink.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _TopOverlayIconButton(
                        icon: NyanIcons.bookmark,
                        ink: ink,
                        onTap: onAddBookmark,
                      ),
                      _TopOverlayIconButton(
                        icon: NyanIcons.moreHorizontal,
                        ink: ink,
                        onTap: onOpenSettings,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 44×44 pt icon button used inside [_ReaderTopOverlay]. The fixed SizedBox
/// guarantees [NyanSpacing.minTapTarget] without relying on InkResponse's
/// hit-test expansion, which varies by platform.
class _TopOverlayIconButton extends StatelessWidget {
  const _TopOverlayIconButton({
    required this.icon,
    required this.ink,
    required this.onTap,
  });

  final IconData icon;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      radius: 24,
      child: SizedBox(
        width: NyanSpacing.minTapTarget,
        height: NyanSpacing.minTapTarget,
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: ink.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal sheet helpers used by the bottom-dock tiles. Each is shown via
// [showModalBottomSheet] so it animates over the reader and dismisses with
// the standard backdrop tap / drag.
// ─────────────────────────────────────────────────────────────────────────────

/// Brightness tile destination: small modal sheet wrapping the existing
/// [ReaderSettingsDisplayPanel] (brightness + warmth + auto-brightness chip).
/// Kept slim so it doesn't recreate the full reading-settings surface.
Future<void> _showReaderBrightnessSheet({
  required BuildContext context,
  required BrightnessController brightnessController,
  required ReaderController readerController,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
    barrierColor: NyanOverlayStyle.modalBarrierColor(context),
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final loc = AppLocalizations.of(sheetContext)!;
      return Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(NyanRadius.sheet),
            ),
            child: BrightnessOverlayWidget(
              stackFit: StackFit.passthrough,
              stateListenable: brightnessController.stateListenable,
              warmthListenable: brightnessController.warmthListenable,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.bottomSheetTheme.backgroundColor ??
                      theme.cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(NyanRadius.sheet),
                  ),
                  boxShadow: NyanOverlayStyle.dialogShadow(sheetContext),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      NyanSpacing.space20,
                      NyanSpacing.space12,
                      NyanSpacing.space20,
                      NyanSpacing.space12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: NyanSpacing.space4,
                            decoration: BoxDecoration(
                              color: theme.dividerColor.withValues(alpha: 0.44),
                              borderRadius:
                                  BorderRadius.circular(NyanRadius.small),
                            ),
                          ),
                        ),
                        const SizedBox(height: NyanSpacing.space16),
                        ReaderSettingsDisplayPanel(
                          brightnessController: brightnessController,
                          loc: loc,
                          onWarmthChanged: readerController.setWarmth,
                          pageTurnMode: readerController.settingsManager
                              .preferences.pageTurnMode,
                          onSetPageTurnMode: readerController.setPageTurnMode,
                          denseLayout: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Settings tile destination: opens [ReaderMenu] as a standalone modal sheet.
/// Previously this was an embedded "full" layer reached via an in-sheet
/// Quick/Full toggle; P4 removed that toggle so the sheet is the menu now.
Future<void> _showReaderSettingsSheet({
  required BuildContext context,
  required ReaderController readerController,
  required BrightnessController brightnessController,
  required GlobalKey<ScaffoldState> scaffoldKey,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
    barrierColor: NyanOverlayStyle.modalBarrierColor(context),
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      const maxHeightFactor = 0.78;
      final maxSheetHeight =
          MediaQuery.sizeOf(sheetContext).height * maxHeightFactor;
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
              stateListenable: brightnessController.stateListenable,
              warmthListenable: brightnessController.warmthListenable,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.bottomSheetTheme.backgroundColor ??
                      theme.cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(NyanRadius.sheet),
                  ),
                  boxShadow: NyanOverlayStyle.dialogShadow(sheetContext),
                ),
                child: ReaderMenu(
                  controller: readerController,
                  scaffoldKey: scaffoldKey,
                  brightnessController: brightnessController,
                  showSheetChrome: true,
                  showHeader: true,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
