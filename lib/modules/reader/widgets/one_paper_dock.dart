import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/nyan_radius.dart';
import '../../../core/theme/nyan_shadows.dart';
import '../../../core/theme/nyan_spacing.dart';
import '../../../core/theme/nyan_typography.dart';
import '../../../core/theme/theme_presets.dart';
import '../../../core/ui/nyan_icons.dart';
import '../../../core/ui/nyan_theme_context.dart';
import '../../../l10n/app_localizations.dart';

/// The three persistent dock actions. Brightness intentionally lives elsewhere
/// (top-bar sun popover + left-edge vertical drag), per the One Paper model.
enum DockAction { chapters, bookmarks, settings }

// Animation tokens (colors_and_type.css):
//   --dur-grow 320ms · --dur-chrome 280ms · --ease-paper cubic(0.33,0.9,0.36,1)
const Duration _kDurGrow = Duration(milliseconds: 320);
const Duration _kDurChrome = Duration(milliseconds: 280);
const Curve _kEasePaper = Cubic(0.33, 0.9, 0.36, 1.0);

/// "One Paper" reader chrome — a single floating paper panel that is a **dock**
/// when collapsed and a **sheet** when grown. Same width, inset, surface, and
/// shadow either way; the radius eases `r-dock` (24) → `r-sheet` (28) and the
/// body grows in place. The [footer] is always pinned at the base.
///
/// Place inside a `Stack` (it returns a [Positioned]); the parent owns the
/// canvas recede + scrim (the depth response). Pass [visible] for immersive
/// show/hide and [sheetOpen] to grow the dock into a sheet.
///
/// Source: `components/reader.jsx` `OnePaperDock`; `ReaderScreen.jsx`.
class OnePaperDock extends StatelessWidget {
  const OnePaperDock({
    super.key,
    required this.visible,
    required this.sheetOpen,
    required this.footer,
    this.title,
    this.meta,
    this.child,
    this.onGrabberTap,
    this.maxSheetHeight = 520,
  });

  /// Immersive visibility — when false the whole panel slides off the bottom.
  final bool visible;

  /// When true the dock is grown into a sheet (body revealed, radius → 28).
  final bool sheetOpen;

  /// Always-pinned base — typically a [DockFooter].
  final Widget footer;

  /// Grown-sheet header title (e.g. "Reading Settings" / "Chapters").
  final String? title;

  /// Grown-sheet header trailing meta (e.g. "42% read" / "18 chapters").
  final String? meta;

  /// Grown-sheet body (the settings panels / chapter list).
  final Widget? child;

  /// Tapping the grabber collapses the sheet back to a dock.
  final VoidCallback? onGrabberTap;

  /// Cap on the grown body height; it scrolls internally beyond this.
  final double maxSheetHeight;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isDark = nyan.brightness == Brightness.dark;

    // Grabber tint (--grabber): primary @ 36% light / 50% dark.
    final grabberColor =
        nyan.primary.withValues(alpha: isDark ? 0.5 : 0.36);
    // --chrome-edge: invisible in light, a divider ring in dark.
    final chromeEdge = isDark ? nyan.divider : Colors.transparent;

    final body = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          NyanSpacing.space16,
          0,
          NyanSpacing.space16,
          NyanSpacing.space8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grabber — also a collapse affordance.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onGrabberTap,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: grabberColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  2,
                  NyanSpacing.space4 + 2,
                  2,
                  NyanSpacing.space12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: NyanTypography.uiFontFamily,
                          fontSize: NyanTypography.section, // 20
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          letterSpacing: -0.2,
                          color: nyan.textPrimary,
                        ),
                      ),
                    ),
                    if (meta != null) ...[
                      const SizedBox(width: NyanSpacing.space8),
                      Text(
                        meta!,
                        style: TextStyle(
                          fontFamily: NyanTypography.uiFontFamily,
                          fontSize: NyanTypography.meta, // 13
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                          color: nyan.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (child != null) child!,
          ],
        ),
      ),
    );

    final dock = GestureDetector(
      // Consume stray taps on the panel so they don't bubble to the reader
      // body's GestureDetector and toggle the chrome off.
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: AnimatedContainer(
        duration: _kDurChrome,
        curve: _kEasePaper,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: nyan.surface,
          border: Border.all(color: chromeEdge, width: 1),
          borderRadius: BorderRadius.circular(
            sheetOpen ? NyanRadius.sheet : NyanRadius.dock,
          ),
          boxShadow: NyanShadows.lightCard(nyan),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grow region: reveal the body from 0 → full height (clipped).
            ClipRect(
              child: AnimatedAlign(
                alignment: Alignment.topCenter,
                heightFactor: sheetOpen ? 1.0 : 0.0,
                duration: _kDurGrow,
                curve: _kEasePaper,
                child: body,
              ),
            ),
            footer,
          ],
        ),
      ),
    );

    return Positioned(
      left: NyanSpacing.space12,
      right: NyanSpacing.space12,
      bottom: NyanSpacing.space12 + bottomInset,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          // translateY(140%) when hidden, per spec.
          offset: visible ? Offset.zero : const Offset(0, 1.4),
          duration: _kDurGrow,
          curve: _kEasePaper,
          child: AnimatedOpacity(
            opacity: visible ? 1.0 : 0.0,
            duration: _kDurChrome,
            curve: _kEasePaper,
            child: RepaintBoundary(child: dock),
          ),
        ),
      ),
    );
  }
}

/// The persistent base of the One Paper panel: a chapter stepper flanking a
/// thin progress bar (shown only when collapsed), then the three actions.
/// The stepper carets are the only chapter-nav affordance in the dock model.
///
/// Source: `components/reader.jsx` `DockFooter`.
class DockFooter extends StatelessWidget {
  const DockFooter({
    super.key,
    required this.sheetOpen,
    required this.chapterIndex,
    required this.chapterCount,
    required this.chapterLabel,
    required this.progressListenable,
    required this.activeAction,
    required this.onAction,
    this.onPrevChapter,
    this.onNextChapter,
  });

  final bool sheetOpen;

  /// 0-based current chapter; may be `-1` when unknown.
  final int chapterIndex;
  final int chapterCount;

  /// Pre-resolved, localized chapter label (title or fallback).
  final String chapterLabel;

  final ValueListenable<double> progressListenable;
  final DockAction? activeAction;
  final void Function(DockAction) onAction;
  final VoidCallback? onPrevChapter;
  final VoidCallback? onNextChapter;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final loc = AppLocalizations.of(context)!;
    final atStart = chapterIndex <= 0;
    final atEnd = chapterCount <= 0 || chapterIndex >= chapterCount - 1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: _kEasePaper,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: sheetOpen ? nyan.divider : Colors.transparent,
            width: 1,
          ),
        ),
      ),
      child: AnimatedSize(
        duration: _kDurGrow,
        curve: _kEasePaper,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!sheetOpen) _buildProgressStepper(nyan, atStart, atEnd),
            _buildActions(nyan, loc),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStepper(NyanTheme nyan, bool atStart, bool atEnd) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NyanSpacing.space8,
        NyanSpacing.space12,
        NyanSpacing.space8,
        NyanSpacing.space4,
      ),
      child: Row(
        children: [
          _StepCaret(
            icon: NyanIcons.chevronLeft,
            color: nyan.textSecondary,
            disabled: atStart,
            onTap: atStart ? null : onPrevChapter,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: NyanSpacing.space4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          chapterLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: NyanTypography.uiFontFamily,
                            fontSize: 12,
                            height: 1.0,
                            fontWeight: FontWeight.w400,
                            color: nyan.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: NyanSpacing.space8),
                      ValueListenableBuilder<double>(
                        valueListenable: progressListenable,
                        builder: (context, p, _) => Text(
                          '${(p.clamp(0.0, 1.0) * 100).round()}%',
                          style: TextStyle(
                            fontFamily: NyanTypography.monoFontFamily,
                            fontSize: 12,
                            height: 1.0,
                            fontWeight: FontWeight.w500,
                            color: nyan.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NyanSpacing.space8),
                  ValueListenableBuilder<double>(
                    valueListenable: progressListenable,
                    builder: (context, p, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: p.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor:
                            nyan.textPrimary.withValues(alpha: 0.11),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(nyan.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _StepCaret(
            icon: NyanIcons.chevronRight,
            color: nyan.textSecondary,
            disabled: atEnd,
            onTap: atEnd ? null : onNextChapter,
          ),
        ],
      ),
    );
  }

  Widget _buildActions(NyanTheme nyan, AppLocalizations loc) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        NyanSpacing.space8,
        sheetOpen ? 6 : NyanSpacing.space8,
        NyanSpacing.space8,
        sheetOpen ? 10 : NyanSpacing.space12,
      ),
      child: Row(
        children: [
          _ActionTile(
            action: DockAction.chapters,
            icon: NyanIcons.tableOfContents,
            label: loc.readerDockChapters,
            selected: activeAction == DockAction.chapters,
            onTap: () => onAction(DockAction.chapters),
          ),
          _ActionTile(
            action: DockAction.bookmarks,
            icon: NyanIcons.bookmarks,
            label: loc.bookmarks,
            selected: activeAction == DockAction.bookmarks,
            onTap: () => onAction(DockAction.bookmarks),
          ),
          _ActionTile(
            action: DockAction.settings,
            icon: NyanIcons.tune,
            label: loc.settingsTitle,
            selected: activeAction == DockAction.settings,
            onTap: () => onAction(DockAction.settings),
          ),
        ],
      ),
    );
  }
}

/// Chapter stepper caret. Visual icon is 20pt; the hit target is expanded to
/// 40pt (the spec draws a 36pt transparent box — we round up toward the 44pt
/// tap floor without changing the visible glyph).
class _StepCaret extends StatelessWidget {
  const _StepCaret({
    required this.icon,
    required this.color,
    required this.disabled,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(NyanRadius.chip),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NyanRadius.chip),
          child: Center(
            // Disabled = dimmed glyph (no Opacity widget — avoids saveLayer).
            child: Icon(
              icon,
              size: 20,
              color: color.withValues(alpha: disabled ? 0.32 : 1.0),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the three dock actions: icon over label, matcha-tinted when active.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.action,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final DockAction action;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final color = selected ? nyan.primaryDeep : nyan.textSecondary;
    final radius = BorderRadius.circular(NyanRadius.control);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: _kEasePaper,
            decoration: BoxDecoration(
              color: selected
                  ? nyan.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: radius,
            ),
            padding: const EdgeInsets.symmetric(
              vertical: NyanSpacing.space8,
              horizontal: NyanSpacing.space4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: 12,
                    height: 1.0,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
