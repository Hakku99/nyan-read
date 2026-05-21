import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_typography.dart';
import '../../theme/theme_presets.dart';

/// Size variants for [NyanPrimaryButton] — **heights are LOCKED** per the
/// Claude Design spec (`components.jsx`). Padding is horizontal-only; never
/// grow a button by passing extra vertical padding.
///
/// - [compact]      — 36pt tall, in-card CTAs (continue-reading row)
/// - [standard]     — 44pt tall, default body CTA (matches `minTapTarget`)
/// - [comfortable]  — 52pt tall, hero / sticky bottom CTA only
enum NyanPrimaryButtonSize { compact, standard, comfortable }

/// Visual variants for [NyanPrimaryButton] — choose by emphasis.
///
/// - [primary] — matcha-green fill, cream label (default)
/// - [deep]    — deeper matcha fill, cream label (heavier emphasis)
/// - [ghost]   — transparent fill, matcha-deep label (tertiary / inline)
enum NyanPrimaryButtonVariant { primary, deep, ghost }

/// Canonical primary action button for Nyan Read.
///
/// Implements the Claude Design spec (3 sizes × 3 variants) with:
///   • Locked heights (36 / 44 / 52pt) — padding is horizontal-only
///   • Single-line label with [TextOverflow.ellipsis]
///   • 6pt icon↔label gap (AGENTS.md §4.2.3 exception)
///   • Per-variant background / foreground via [NyanTheme] tokens
///
/// See: `nyan-read-design-system/project/ui_kits/nyan_read_app/components.jsx`
class NyanPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool expanded;
  final NyanPrimaryButtonSize size;
  final NyanPrimaryButtonVariant variant;

  const NyanPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
    this.size = NyanPrimaryButtonSize.standard,
    this.variant = NyanPrimaryButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final nyan = resolveNyanTheme(Theme.of(context));
    final disabled = onPressed == null;

    // ── Per-size metrics (locked per AGENTS.md §4.2.5 + §4.2.3 exceptions) ─
    final (double height, double padX, double fontSize, double iconSize) =
        switch (size) {
      NyanPrimaryButtonSize.compact => (
          36.0,
          14.0,
          NyanTypography.buttonCompact, // 14
          16.0,
        ),
      NyanPrimaryButtonSize.standard => (
          44.0,
          24.0,
          NyanTypography.body, // 16
          18.0,
        ),
      NyanPrimaryButtonSize.comfortable => (
          52.0,
          28.0,
          NyanTypography.buttonComfortable, // 17
          18.0,
        ),
    };

    // ── Per-variant colors ──────────────────────────────────────────────
    final (Color bg, Color fg, FontWeight weight) = switch (variant) {
      NyanPrimaryButtonVariant.primary => (
          nyan.primary,
          nyan.surface,
          FontWeight.w500,
        ),
      NyanPrimaryButtonVariant.deep => (
          nyan.primaryDeep,
          nyan.surface,
          FontWeight.w500,
        ),
      NyanPrimaryButtonVariant.ghost => (
          Colors.transparent,
          nyan.primaryDeep,
          FontWeight.w600,
        ),
    };

    // Disabled state: dim fill to ~40% (ghost stays transparent) and
    // dim foreground to ~50% per Material convention.
    final isGhost = variant == NyanPrimaryButtonVariant.ghost;
    final effectiveBg =
        disabled && !isGhost ? bg.withValues(alpha: 0.4) : bg;
    final effectiveFg = disabled ? fg.withValues(alpha: 0.5) : fg;

    final textStyle = TextStyle(
      fontFamily: NyanTypography.uiFontFamily,
      fontSize: fontSize,
      fontWeight: weight,
      color: effectiveFg,
      height: 1.0,
    );

    final labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );

    final Widget content = icon == null
        ? labelWidget
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(color: effectiveFg, size: iconSize),
                child: icon!,
              ),
              // 6pt icon↔label gap — AGENTS.md §4.2.3 exception
              // (Claude Design `components.jsx` `gap: 6`).
              const SizedBox(width: 6),
              Flexible(child: labelWidget),
            ],
          );

    final button = SizedBox(
      height: height,
      child: Material(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(NyanRadius.input),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          splashColor: fg.withValues(alpha: 0.12),
          highlightColor: fg.withValues(alpha: 0.06),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padX),
            child: Center(child: content),
          ),
        ),
      ),
    );

    if (!expanded) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}
