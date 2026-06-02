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
