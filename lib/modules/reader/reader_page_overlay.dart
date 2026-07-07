part of 'reader_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reader chrome overlays.
//
// One Paper (2026-06): the bottom control surface is now the floating
// `OnePaperDock` (see `widgets/one_paper_dock.dart`) built directly in
// `reader_page.dart`. The old P4 sticky bottom strip + its modal-sheet
// destinations (brightness / settings / chapters) were removed — Settings and
// Chapters now grow the dock in place; Bookmarks pushes a page. Only the
// floating top bar lives here.
// ─────────────────────────────────────────────────────────────────────────────

const Duration _kReaderOverlayAnimDuration = Duration(milliseconds: 220);
const Curve _kReaderOverlayAnimCurve = Curves.easeOutCubic;

// ─────────────────────────────────────────────────────────────────────────────
// Top overlay — slides in from the top, a floating paper bar.
// Per ReaderScreen.jsx spec: back button | title + author | bookmark | more.
// ─────────────────────────────────────────────────────────────────────────────

/// Sticky top-strip overlay showing book title/author and quick action buttons.
/// [visible] drives an AnimatedSlide + AnimatedOpacity; offset is `(0, -1)` when
/// hidden so it slides up off-screen.
class _ReaderTopOverlay extends StatelessWidget {
  const _ReaderTopOverlay({
    required this.visible,
    required this.controller,
    required this.onBack,
    required this.onAddBookmark,
    required this.onToggleBrightness,
    required this.brightnessActive,
    required this.onOpenSettings,
  });

  final bool visible;
  final ReaderController controller;
  final VoidCallback onBack;
  final VoidCallback onAddBookmark;
  final VoidCallback onToggleBrightness;
  final bool brightnessActive;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final isDark = nyan.brightness == Brightness.dark;
    // --chrome-edge: invisible in light, a divider ring in dark. Same rule
    // OnePaperDock uses, so the top/bottom chrome reads as a matched set.
    final chromeEdge = isDark ? nyan.divider : Colors.transparent;

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
                color: nyan.surfaceRaised,
                border: Border.all(color: chromeEdge, width: 1),
                borderRadius: BorderRadius.circular(NyanRadius.dock),
                boxShadow: NyanShadows.lightCard(nyan),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NyanSpacing.space8,
                  vertical: 7,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _TopOverlayIconButton(
                      icon: NyanIcons.back,
                      color: nyan.textPrimary,
                      iconSize: 22,
                      onTap: onBack,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: NyanSpacing.space4,
                        ),
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
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                                letterSpacing: -0.2,
                                color: nyan.textPrimary,
                              ),
                            ),
                            if (controller.book.author.isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(
                                controller.book.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: NyanTypography.uiFontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  height: 1.3,
                                  color: nyan.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    _TopOverlayIconButton(
                      icon: NyanIcons.sun,
                      color: nyan.textSecondary,
                      iconSize: 21,
                      active: brightnessActive,
                      activeColor: nyan.primaryDeep,
                      onTap: onToggleBrightness,
                    ),
                    _TopOverlayIconButton(
                      icon: NyanIcons.bookmark,
                      color: nyan.textSecondary,
                      iconSize: 21,
                      onTap: onAddBookmark,
                    ),
                    _TopOverlayIconButton(
                      icon: NyanIcons.moreHorizontal,
                      color: nyan.textSecondary,
                      iconSize: 21,
                      onTap: onOpenSettings,
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

/// Icon button used inside [_ReaderTopOverlay]. Visual chip is 40×40 with
/// `NyanRadius.chip` (matches `ReaderTopBar`'s `iconBtn`); the outer SizedBox
/// still guarantees [NyanSpacing.minTapTarget] (44×44) without relying on
/// InkResponse's hit-test expansion, which varies by platform.
class _TopOverlayIconButton extends StatelessWidget {
  const _TopOverlayIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.iconSize = 21,
    this.active = false,
    this.activeColor,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double iconSize;

  /// When true the button reads as "toggled on" (matcha-tinted chip + glyph) —
  /// used by the brightness sun button while its popover is open.
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final accent = activeColor ?? color;
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active
                  ? accent.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(NyanRadius.chip),
            ),
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: active ? accent : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
