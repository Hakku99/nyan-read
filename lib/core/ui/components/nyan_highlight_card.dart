import 'package:flutter/material.dart';

import '../../theme/nyan_colors.dart';
import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import '../nyan_theme_context.dart';

// Padding matches spec (bundle3.jsx HighlightCard padding: "12px 14px").
// 14pt horizontal is an exception to the 8-grid rule — allowed only here.
const double _kCardPaddingH = 14;
const double _kCardPaddingV = 12;

// Spec: gap between color strip and content is 10px.
const double _kStripContentGap = 10;

class NyanHighlightCard extends StatelessWidget {
  final String label;
  final String excerpt;
  final Color highlightColor;
  final String? note;
  final String? meta;
  final String? noteTagLabel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const NyanHighlightCard({
    super.key,
    required this.label,
    required this.excerpt,
    required this.highlightColor,
    this.note,
    this.meta,
    this.noteTagLabel,
    this.onTap,
    this.onLongPress,
  });

  // Strip/dot display color. Only yellow maps to its ink variant (#D8C06B per
  // bundle3.jsx HIGHLIGHTS[0].color). Blue (#9EC5E8) and green (#A8D18D) use
  // their raw pen colors directly — that is what the spec shows for those entries.
  Color _resolveStripColor() {
    if (highlightColor.toARGB32() == 0xFFF2E58A) {
      return NyanColors.highlightInkYellow; // yellow pen → ink #D8C06B
    }
    return highlightColor;
  }

  // Darkened "ink" shade used exclusively for label text blending.
  // Approximates the per-color dark ink values in the spec (e.g. yellow #B89A2C,
  // blue #2E6B96, green #4E8A2D per bundle3.jsx hl.ink / bundle1.jsx HL_SWATCHES.ink).
  // These are much darker than the CSS --hl-ink-* tokens and are computed via
  // HSL lightness reduction rather than a lookup.
  Color _inkColor() {
    final hsl = HSLColor.fromColor(highlightColor);
    return hsl.withLightness((hsl.lightness * 0.62).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final isDark = theme.brightness == Brightness.dark;

    final cardSurface = isDark
        ? Color.alphaBlend(
            nyanTheme.surface.withValues(alpha: 0.78),
            nyanTheme.background,
          )
        : theme.cardColor;

    // Spec: "0.72px solid color-mix(nyan-divider 36%, transparent)"
    // Note: theme.dividerColor is the legacy Flutter default (~12% black), NOT
    // nyanTheme.divider. Always use nyanTheme.divider for the correct warm token.
    final cardBorder = nyanTheme.divider.withValues(alpha: 0.36);

    final cardShadow = isDark
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.022),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ];

    final compactExcerpt = excerpt.replaceAll(RegExp(r'\s+'), ' ').trim();
    final compactNote = note?.replaceAll(RegExp(r'\s+'), ' ').trim();
    final hasNote = compactNote != null && compactNote.isNotEmpty;

    // Strip/dot: yellow uses ink variant #D8C06B; all others use raw pen color.
    final stripColor = _resolveStripColor();

    // Label: blend heavily-darkened ink into textPrimary, mirroring spec's
    // color-mix(hl.ink 85%, --nyan-text) where hl.ink is a very dark shade.
    final labelColor = Color.alphaBlend(
      _inkColor().withValues(alpha: isDark ? 0.78 : 0.85),
      nyanTheme.textPrimary,
    );

    final content = Container(
      // Spec: padding: "12px 14px" wraps everything including the strip.
      padding: const EdgeInsets.symmetric(
        horizontal: _kCardPaddingH,
        vertical: _kCardPaddingV,
      ),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(NyanRadius.cardNested),
        border: Border.all(color: cardBorder, width: 0.72),
        boxShadow: cardShadow,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Color strip — pill-shaped, floats inside the card padding.
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: stripColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: _kStripContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row: [● dot  label] ──────── [paragraph] ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: stripColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cardSurface.withValues(alpha: 0.8),
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6), // icon-label gap per spec
                      Expanded(
                        child: Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10.5,
                            color: labelColor,
                            fontWeight: FontWeight.w500,
                            height: 1.04,
                          ),
                        ),
                      ),
                      if (meta != null && meta!.isNotEmpty)
                        Text(
                          meta!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10.5,
                            color: nyanTheme.textMuted,
                            fontWeight: FontWeight.w400,
                            height: 1.04,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // ── Excerpt ──────────────────────────────────────────
                  Text(
                    compactExcerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: nyanTheme.textPrimary.withValues(
                        alpha: isDark ? 0.95 : 0.86,
                      ),
                      fontWeight: FontWeight.w400,
                      height: 1.45,
                    ),
                  ),
                  // ── Note section ────────────────────────────────────
                  if (hasNote) ...[
                    const SizedBox(height: NyanSpacing.space8),
                    // Spec: "0.5px solid color-mix(nyan-divider 34%, transparent)"
                    Divider(
                      height: 0,
                      thickness: 0.5,
                      color: nyanTheme.divider.withValues(alpha: 0.34),
                    ),
                    const SizedBox(height: 6), // paddingTop per spec
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NotePill(
                          label: noteTagLabel ?? 'Note',
                          pillBackground: Color.alphaBlend(
                            nyanTheme.primary.withValues(
                              alpha: isDark ? 0.12 : 0.10,
                            ),
                            nyanTheme.surfaceMuted,
                          ),
                          pillBorder: nyanTheme.primary.withValues(
                            alpha: isDark ? 0.22 : 0.18,
                          ),
                          labelColor: nyanTheme.primaryDeep,
                          theme: theme,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            compactNote,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 13,
                              color: nyanTheme.textSecondary,
                              height: 1.38,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null && onLongPress == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(NyanRadius.cardNested),
        child: content,
      ),
    );
  }
}

class _NotePill extends StatelessWidget {
  final String label;
  final Color pillBackground;
  final Color pillBorder;
  final Color labelColor;
  final ThemeData theme;

  const _NotePill({
    required this.label,
    required this.pillBackground,
    required this.pillBorder,
    required this.labelColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: pillBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: pillBorder, width: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          color: labelColor,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
    );
  }
}
