import 'package:flutter/material.dart';
import '../../theme/nyan_radius.dart';
import '../../theme/nyan_shadows.dart';
import '../../theme/nyan_spacing.dart';
import '../nyan_theme_context.dart';

/// Visual weight:
/// [emphasis] = floating surface chip + grouped shadow, `primaryDeep` selected
///   text (default — reader sort / sections, per `primitives.jsx`).
/// [subtle] = matcha-tint chip, `primaryDeep` selected text (sort-order sheet —
///   doesn't compete with a hero CTA nearby).
/// [shelf] = surface chip + grouped shadow, **`textPrimary` w600** selected /
///   `textMuted` unselected. The top-level Public/Private shelf switcher
///   (`BookshelfScreen.jsx`): a dark bold label reads as page-level navigation,
///   not an in-panel adjustment. Documented exception to AGENTS.md §4.3.
enum SegmentedTabStyle {
  emphasis,
  subtle,
  shelf,
}

/// Segmented / tab control — "ONE recessed-track style for the whole system."
///
/// Track: `r-control` (14pt), `surfaceMuted` background, no border — recessed
/// by tone, never by a ring. Indicator: concentric inner 11pt (= 14 − 3);
/// emphasis = `surface` chip + `settingsGrouped` shadow; subtle = matcha-tint.
/// Animation: `--dur-chrome` 280ms, `ease-paper` (cubic-bezier 0.33,0.9,0.36,1).
/// Selected text: `primaryDeep`. Unselected: `textSecondary`.
///
/// Source: `components/primitives.jsx` `SegmentedTabControl`; `colors_and_type.css`
/// `--dur-chrome`, `--r-control`; `HANDOFF-flutter.md §2`.
class SegmentedTabControl extends StatefulWidget {
  final List<SegmentedTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  /// Override the track background. Defaults to [NyanTheme.surfaceMuted].
  final Color? backgroundColor;

  /// When set, applied to tab label [TextStyle.height] (e.g. reader settings).
  final double? labelLineHeight;

  /// [subtle] = matcha-tint chip (bookshelf); [emphasis] = surface chip (default).
  final SegmentedTabStyle style;

  const SegmentedTabControl({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
    this.backgroundColor,
    this.labelLineHeight,
    this.style = SegmentedTabStyle.emphasis,
  });

  @override
  State<SegmentedTabControl> createState() => _SegmentedTabControlState();
}

class _SegmentedTabControlState extends State<SegmentedTabControl> {
  // --dur-chrome 280ms; --ease-paper cubic-bezier(0.33, 0.9, 0.36, 1)
  static const _kDuration = Duration(milliseconds: 280);
  static const _kCurve = Cubic(0.33, 0.9, 0.36, 1.0);

  // Concentric inner: track r-control(14) minus 3px padding on each side → 11.
  // This is intentional off-scale (not a NyanRadius constant) — the inner arc
  // must look parallel to the outer arc, not independent.
  static const double _kIndicatorRadius = NyanRadius.control - 3; // 11

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final subtle = widget.style == SegmentedTabStyle.subtle;
    final shelf = widget.style == SegmentedTabStyle.shelf;

    final Color trackBg = widget.backgroundColor ?? nyan.surfaceMuted;

    // emphasis + shelf both use a surface chip; only subtle uses the matcha tint.
    final Color indicatorBg = subtle
        ? nyan.primary.withValues(alpha: 0.16)
        : nyan.surface;

    final List<BoxShadow> indicatorShadow =
        subtle ? const [] : NyanShadows.settingsGrouped(nyan);

    // Shelf uses 3pt inset so the 11pt indicator (14−3) reads truly concentric,
    // matching BookshelfScreen.jsx; other variants keep the 4pt grid value.
    final double trackPadding = shelf ? 3 : NyanSpacing.space4;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: trackBg,
        borderRadius: BorderRadius.circular(NyanRadius.control),
        // No border — recessed by tone only (AGENTS.md §4.3 / bundle spec).
      ),
      padding: EdgeInsets.all(trackPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / widget.tabs.length;
          final indicatorLeft = widget.selectedIndex * tabWidth;

          return Stack(
            children: [
              // Sliding indicator — owns the card-on-track lift.
              AnimatedPositioned(
                duration: _kDuration,
                curve: _kCurve,
                left: indicatorLeft,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: indicatorBg,
                    borderRadius: BorderRadius.circular(_kIndicatorRadius),
                    boxShadow: indicatorShadow,
                  ),
                ),
              ),
              // Tab buttons overlay (z > indicator).
              Row(
                children: List.generate(widget.tabs.length, (index) {
                  final tab = widget.tabs[index];
                  final isSelected = index == widget.selectedIndex;
                  // Shelf switcher: dark bold selected label (page-level voice).
                  // Other variants: matcha-deep selected label (in-panel voice).
                  final Color labelColor = shelf
                      ? (isSelected ? nyan.textPrimary : nyan.textMuted)
                      : (isSelected ? nyan.primaryDeep : nyan.textSecondary);
                  final FontWeight labelWeight = (shelf && isSelected)
                      ? FontWeight.w600
                      : FontWeight.w500;

                  return SizedBox(
                    width: tabWidth,
                    child: GestureDetector(
                      onTap: () => widget.onTabChanged(index),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: NyanSpacing.space4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (tab.icon != null) ...[
                              Icon(tab.icon, size: 16, color: labelColor),
                              const SizedBox(width: NyanSpacing.space4),
                            ],
                            Flexible(
                              child: Text(
                                tab.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: labelWeight,
                                  height: widget.labelLineHeight,
                                  color: labelColor,
                                ),
                                strutStyle: widget.labelLineHeight != null
                                    ? StrutStyle(
                                        fontSize: 14,
                                        height: widget.labelLineHeight,
                                        forceStrutHeight: true,
                                        leading: 0,
                                      )
                                    : null,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Data class for a single tab in the segmented control.
class SegmentedTab {
  final String label;
  final IconData? icon;

  const SegmentedTab({
    required this.label,
    this.icon,
  });
}
