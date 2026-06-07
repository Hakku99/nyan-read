import 'package:flutter/material.dart';

import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../../../core/theme/nyan_radius.dart';
import '../../../../core/theme/nyan_spacing.dart';
import '../../../../core/theme/nyan_typography.dart';
import '../../../../core/ui/components/nyan_pill_button.dart';
import '../../../../core/ui/nyan_theme_context.dart';
import 'reader_settings_common.dart';

/// Typography controls (Text tab).
///
/// Layout per spec `reader.jsx` `TextPanel`:
///   Font Size Knob   (slider + − / + step buttons + monospace pt label)
///   Line Height Knob (Compact / Standard / Comfortable pills)
///   Font Family Knob (Sans / Serif pills + live preview)
class ReaderSettingsTextPanel extends StatelessWidget {
  const ReaderSettingsTextPanel({
    super.key,
    required this.fontSize,
    required this.lineHeight,
    required this.textColor,
    required this.backgroundColor,
    required this.onSetFontSize,
    required this.onSetLineHeight,
    required this.useSerif,
    required this.onSetUseSerif,
    required this.loc,
    this.denseLayout = false,
  });

  final double fontSize;
  final double lineHeight;
  final Color textColor;
  final Color backgroundColor;
  final ValueChanged<double> onSetFontSize;
  final ValueChanged<double> onSetLineHeight;
  final bool useSerif;
  final ValueChanged<bool> onSetUseSerif;
  final AppLocalizations loc;
  final bool denseLayout;

  // Spec line-height presets (reader.jsx TextPanel): 1.45 / 1.75 / 2.05.
  static const _lhPresets = [1.45, 1.75, 2.05];

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final gap = denseLayout ? NyanSpacing.space8 : NyanSpacing.space12;
    final fs = fontSize.clamp(kReaderFontSizeMin, kReaderFontSizeMax);
    final lh = lineHeight.clamp(kReaderLineHeightMin, kReaderLineHeightMax);

    final lhLabels = [
      loc.readerTypographyCompact,
      loc.readerTypographyStandard,
      loc.readerTypographyComfortable,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Font Size ─────────────────────────────────────────────────────
        ReaderSettingsKnob(
          label: loc.fontSize,
          hint: loc.readerFontSizeHint,
          child: Row(
            children: [
              _StepButton(
                icon: NyanIcons.remove,
                onTap: () => onSetFontSize(
                  (fs - 1).clamp(kReaderFontSizeMin, kReaderFontSizeMax),
                ),
              ),
              const SizedBox(width: NyanSpacing.space12),
              Expanded(
                child: ReaderSettingsSlider(
                  value: fs,
                  min: kReaderFontSizeMin,
                  max: kReaderFontSizeMax,
                  onChanged: onSetFontSize,
                  activeColor: nyan.primaryDeep,
                  // Default textPrimary@12% track (divider@24% was too faint
                  // on the surfaceMuted Knob background).
                  edgeToEdgeTrack: true,
                ),
              ),
              const SizedBox(width: NyanSpacing.space12),
              _StepButton(
                icon: NyanIcons.add,
                onTap: () => onSetFontSize(
                  (fs + 1).clamp(kReaderFontSizeMin, kReaderFontSizeMax),
                ),
              ),
              const SizedBox(width: NyanSpacing.space8),
              // Monospace pt value label — always visible beside the + button.
              SizedBox(
                width: 34,
                child: Text(
                  '${fs.round()}pt',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: NyanTypography.monoFontFamily,
                    fontSize: NyanTypography.meta,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                    color: nyan.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: gap),
        // ── Line Height ───────────────────────────────────────────────────
        ReaderSettingsKnob(
          label: loc.lineHeight,
          hint: loc.readerLineHeightHint,
          child: Row(
            children: [
              for (var i = 0; i < _lhPresets.length; i++) ...[
                if (i > 0) const SizedBox(width: NyanSpacing.space8),
                Expanded(
                  child: NyanPillButton(
                    label: lhLabels[i],
                    selected: (lh - _lhPresets[i]).abs() < 0.06,
                    onPressed: () => onSetLineHeight(_lhPresets[i]),
                    // Spec TextPanel: 3 pills share a narrow row, override to
                    // "9px 6px" so "Comfortable" fits without truncation.
                    horizontalPadding: 6.0,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: gap),
        // ── Font Family ───────────────────────────────────────────────────
        ReaderSettingsKnob(
          label: loc.readerFontFamily,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: NyanPillButton(
                      label: loc.readerFontFamilySans,
                      selected: !useSerif,
                      onPressed: () => onSetUseSerif(false),
                    ),
                  ),
                  const SizedBox(width: NyanSpacing.space8),
                  Expanded(
                    child: NyanPillButton(
                      label: loc.readerFontFamilySerif,
                      selected: useSerif,
                      onPressed: () => onSetUseSerif(true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: NyanSpacing.space12),
              _FontPreviewTile(
                useSerif: useSerif,
                textColor: textColor,
                backgroundColor: backgroundColor,
                fontSize: fs,
                lineHeight: lh,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Step button for the font-size row: 34×34pt, [NyanRadius.chip] (12pt) corners,
/// 1px [divider] border, [surface] background.
///
/// Source: `reader.jsx` `stepBtn` style.
class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: nyan.surface,
          borderRadius: BorderRadius.circular(NyanRadius.chip),
          border: Border.all(color: nyan.divider, width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 17, color: nyan.textPrimary),
      ),
    );
  }
}

/// Live preview tile — shows sample text at the active reader font and colors.
/// Placed inside the Font Family Knob per spec `reader.jsx` `TextPanel`.
class _FontPreviewTile extends StatelessWidget {
  const _FontPreviewTile({
    required this.useSerif,
    required this.textColor,
    required this.backgroundColor,
    required this.fontSize,
    required this.lineHeight,
  });

  final bool useSerif;
  final Color textColor;
  final Color backgroundColor;
  final double fontSize;
  final double lineHeight;

  // Bilingual sample that exercises both Latin and CJK glyphs so the
  // difference between Sans and Serif is immediately perceptible.
  static const _sample = 'Aa — Reading preview. 永远若水，致虚守静。';

  @override
  Widget build(BuildContext context) {
    final fontFamily = useSerif
        ? NyanTypography.readingSerifFontFamily
        : NyanTypography.uiFontFamily;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(
        horizontal: NyanSpacing.space12,
        vertical: NyanSpacing.space12,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(NyanRadius.chip),
      ),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        // Spec TextPanel: preview renders at the live fontSize and lineHeight
        // so dragging the slider immediately shows the reading impact.
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          height: lineHeight,
          color: textColor,
        ),
        child: const Text(_sample),
      ),
    );
  }
}
