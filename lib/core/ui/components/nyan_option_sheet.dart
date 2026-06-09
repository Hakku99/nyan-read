import 'package:flutter/material.dart';

import '../../theme/nyan_colors.dart';
import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import '../../theme/nyan_typography.dart';
import '../../theme/theme_presets.dart';
import '../nyan_icons.dart';
import '../nyan_theme_context.dart';

/// A single selectable option for [showNyanOptionSheet].
class NyanOptionItem<T> {
  const NyanOptionItem({
    required this.value,
    required this.label,
    this.hint,
    this.swatch,
    this.swatchGradient,
    this.icon,
    this.action,
  }) : assert(
          swatch == null || swatchGradient == null,
          'Provide swatch (solid) or swatchGradient, not both.',
        );

  final T value;
  final String label;

  /// Optional secondary description line shown below [label].
  final String? hint;

  /// Solid color swatch circle shown to the left of [label] (e.g. theme picker).
  final Color? swatch;

  /// Gradient swatch circle (e.g. "Match System" half-cream/half-dark).
  final Gradient? swatchGradient;

  /// Icon shown in a tinted tile to the left of [label] (e.g. page turn picker).
  final IconData? icon;

  /// Callback invoked (after the sheet pops) in the action variant.
  /// In the radio variant this is ignored; the sheet returns [value] instead.
  final VoidCallback? action;
}

/// Shows a [NyanOptionSheet] as a modal bottom sheet.
///
/// Radio variant (default): returns the tapped [NyanOptionItem.value] or
/// `null` if the user dismissed without selecting.
///
/// Action variant ([isActionSheet] = true): returns `null`; each item fires
/// its [NyanOptionItem.action] callback after the sheet closes.
Future<T?> showNyanOptionSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<NyanOptionItem<T>> options,
  T? currentValue,
  bool isActionSheet = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => NyanOptionSheet<T>(
      title: title,
      subtitle: subtitle,
      options: options,
      currentValue: currentValue,
      isActionSheet: isActionSheet,
    ),
  );
}

/// Bottom sheet that presents a set of options as a radio list (single-select)
/// or an action list (icon rows with chevrons).
///
/// Spec source: `surfaces.jsx` `NyanOptionSheet`.
/// - Grabber + header with title/subtitle + close ✕ button.
/// - Each radio row: optional swatch/icon, label+hint, radio indicator.
/// - Selected radio row: `primary @ 8%` tint background.
/// - Action rows: icon tile + label+hint + chevron; tap fires the item's
///   [NyanOptionItem.action] callback after popping.
class NyanOptionSheet<T> extends StatelessWidget {
  const NyanOptionSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.options,
    this.currentValue,
    this.isActionSheet = false,
  });

  final String title;
  final String? subtitle;
  final List<NyanOptionItem<T>> options;
  final T? currentValue;
  final bool isActionSheet;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    // Spec (surfaces.jsx NyanOptionSheet): sheet floats inset 12pt from sides
    // and bottom — all four corners rounded. Bottom safe-area is folded into
    // the margin so the grabber/content don't underlap the home indicator.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
      child: Container(
        decoration: BoxDecoration(
          // Spec: `background: var(--nyan-surface)` (surfaces.jsx NyanOptionSheet).
          color: nyan.surface,
          borderRadius: BorderRadius.circular(NyanRadius.sheet),
          border: nyan.brightness == Brightness.dark
              ? Border.all(color: nyan.divider, width: 1)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Grabber ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: NyanSpacing.space8),
              child: Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    // Spec: `var(--grabber)` = primary @ 36% light / 50% dark.
                    color: nyan.brightness == Brightness.dark
                        ? nyan.primary.withValues(alpha: 0.50)
                        : nyan.primary.withValues(alpha: 0.36),
                    borderRadius: BorderRadius.circular(NyanSpacing.space4 / 2),
                  ),
                ),
              ),
            ),

            // ── Header: title + optional subtitle + close button ─────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NyanSpacing.space20,
                NyanSpacing.space12,
                NyanSpacing.space12,
                NyanSpacing.space8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: NyanTypography.uiFontFamily,
                            // Spec: `font: "600 18px/1.2"` — One Paper sheet title.
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            letterSpacing: -0.1,
                            color: nyan.textPrimary,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: NyanSpacing.space4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontFamily: NyanTypography.uiFontFamily,
                              fontSize: NyanTypography.meta,
                              fontWeight: FontWeight.w400,
                              height: 1.38,
                              color: nyan.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Close button — 32×32, NyanRadius.chip, textMuted icon.
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      icon: Icon(NyanIcons.close, color: nyan.textMuted),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(NyanRadius.chip),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),

            // ── Options list ─────────────────────────────────────────────
            // Bottom safe-area is already absorbed by the outer Padding margin.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NyanSpacing.space12,
                0,
                NyanSpacing.space12,
                NyanSpacing.space16,
              ),
              child: Column(
                children: [
                  for (final item in options)
                    isActionSheet
                        ? _ActionRow(item: item, nyan: nyan)
                        : _RadioRow<T>(
                            item: item,
                            nyan: nyan,
                            isSelected: item.value == currentValue,
                          ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Radio row ────────────────────────────────────────────────────────────────

class _RadioRow<T> extends StatelessWidget {
  const _RadioRow({
    required this.item,
    required this.nyan,
    required this.isSelected,
  });

  final NyanOptionItem<T> item;
  final NyanTheme nyan;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(NyanRadius.cardNested),
        onTap: () => Navigator.of(context).pop(item.value),
        child: Container(
          // Spec: selected row = `color-mix(in srgb, primary 8%, transparent)`.
          decoration: BoxDecoration(
            color: isSelected
                ? nyan.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(NyanRadius.cardNested),
          ),
          padding: const EdgeInsets.all(NyanSpacing.space12),
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              // Optional swatch circle (theme picker).
              if (item.swatch != null || item.swatchGradient != null) ...[
                _SwatchCircle(
                  color: item.swatch,
                  gradient: item.swatchGradient,
                  nyan: nyan,
                ),
                const SizedBox(width: NyanSpacing.space12),
              ],
              // Optional icon tile (page turn picker).
              if (item.icon != null) ...[
                _IconTile(icon: item.icon!, nyan: nyan),
                const SizedBox(width: NyanSpacing.space12),
              ],
              // Label + hint.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontFamily: NyanTypography.uiFontFamily,
                        fontSize: NyanTypography.body,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        height: 1.2,
                        color: isSelected
                            ? nyan.primaryDeep
                            : nyan.textPrimary,
                      ),
                    ),
                    if (item.hint != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.hint!,
                        style: TextStyle(
                          fontFamily: NyanTypography.uiFontFamily,
                          // Spec: 12.5pt — between meta(13) and caption(11),
                          // option hint is a named spec exception (§4.6).
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                          color: nyan.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: NyanSpacing.space12),
              // Radio indicator — 22×22 circle.
              _RadioIndicator(isSelected: isSelected, nyan: nyan),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Action row ───────────────────────────────────────────────────────────────

class _ActionRow<T> extends StatelessWidget {
  const _ActionRow({required this.item, required this.nyan});

  final NyanOptionItem<T> item;
  final NyanTheme nyan;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(NyanRadius.cardNested),
        onTap: () {
          Navigator.of(context).pop();
          item.action?.call();
        },
        child: Padding(
          padding: const EdgeInsets.all(NyanSpacing.space12),
          child: Row(
            children: [
              if (item.icon != null) ...[
                _IconTile(icon: item.icon!, nyan: nyan),
                const SizedBox(width: NyanSpacing.space12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontFamily: NyanTypography.uiFontFamily,
                        fontSize: NyanTypography.body,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                        color: nyan.textPrimary,
                      ),
                    ),
                    if (item.hint != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.hint!,
                        style: TextStyle(
                          fontFamily: NyanTypography.uiFontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                          color: nyan.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: NyanSpacing.space12),
              Icon(
                NyanIcons.chevronRight,
                size: 16,
                color: nyan.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Supporting widgets ───────────────────────────────────────────────────────

class _SwatchCircle extends StatelessWidget {
  const _SwatchCircle({
    required this.nyan,
    this.color,
    this.gradient,
  });

  final NyanTheme nyan;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        shape: BoxShape.circle,
        border: Border.all(
          color: nyan.divider.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.nyan});

  final IconData icon;
  final NyanTheme nyan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        // Spec: `color-mix(in srgb, primary 10%, surfaceMuted)`.
        color: Color.alphaBlend(
          nyan.primary.withValues(alpha: 0.10),
          nyan.surfaceMuted,
        ),
        borderRadius: BorderRadius.circular(NyanRadius.chip),
      ),
      child: Icon(icon, size: 18, color: nyan.primary),
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  const _RadioIndicator({required this.isSelected, required this.nyan});

  final bool isSelected;
  final NyanTheme nyan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? nyan.primary
              : nyan.divider.withValues(alpha: 0.8),
          width: 2,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: nyan.primary,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

// ── Match System swatch gradient ─────────────────────────────────────────────

/// Pre-built diagonal half-cream/half-dark gradient for the "Match System"
/// swatch — matches the CSS `linear-gradient(135deg, creamBg 50%, sumiBg 50%)`.
final matchSystemSwatchGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  stops: const [0.5, 0.5],
  colors: [
    NyanColors.creamBackground, // #F6F3EA
    NyanColors.inkNightBackground, // #181B16
  ],
);
