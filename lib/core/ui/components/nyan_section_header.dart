import 'package:flutter/material.dart';

import '../../theme/nyan_typography.dart';
import '../nyan_theme_context.dart';

/// Olive eyebrow section header above grouped cards.
/// Uses [NyanTypography.eyebrowStyle] (11pt / w500 / primaryDeep) per
/// `_chrome.jsx` SectionHdr and AGENTS.md §4.2.5.
///
/// Pass `withLeadingDot: true` to add a small olive dot before the title — a
/// quietly distinctive accent used by Book Details, opt-out by default so the
/// Settings page renders unchanged.
class NyanSectionHeader extends StatelessWidget {
  const NyanSectionHeader({
    super.key,
    required this.title,
    this.padding,
    this.withLeadingDot = false,
  });

  final String title;
  final EdgeInsetsGeometry? padding;
  final bool withLeadingDot;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    // Spec (_chrome.jsx SectionHdr): 11px/w500/primaryDeep/lh1.0 eyebrow caption.
    // NyanTypography.eyebrowStyle already encodes these values per AGENTS.md §4.2.5.
    final titleWidget = Text(
      title.toUpperCase(),
      style: NyanTypography.eyebrowStyle(nyan.primaryDeep),
    );

    return Padding(
      // Spec: `padding: "16px 0 8px"` — top:16, sides:0, bottom:8.
      // Horizontal padding is provided by the parent (ListView or Column).
      padding: padding ??
          const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: withLeadingDot
          ? Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Spec: 5×5 circle, var(--nyan-primary), gap: 6px.
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: nyan.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                titleWidget,
              ],
            )
          : titleWidget,
    );
  }
}
