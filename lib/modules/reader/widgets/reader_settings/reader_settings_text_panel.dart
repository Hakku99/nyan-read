import 'package:flutter/material.dart';

import 'package:nyan_read/l10n/app_localizations.dart';

import '../../../../core/theme/nyan_radius.dart';
import '../../../../core/theme/nyan_spacing.dart';
import '../../../../core/theme/nyan_typography.dart';
import '../../../../core/ui/components/nyan_pill_button.dart';
import '../../../../core/ui/components/nyan_sheet_card.dart';
import '../../../../core/ui/nyan_theme_context.dart';
import 'reader_settings_common.dart';

/// Typography controls with presets and collapsible fine-tune (Text tab).
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

  void _applyPreset(_TypographyPreset preset) {
    onSetFontSize(
      preset.fontSize.clamp(kReaderFontSizeMin, kReaderFontSizeMax),
    );
    onSetLineHeight(
      preset.lineHeight.clamp(kReaderLineHeightMin, kReaderLineHeightMax),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompactWidth = MediaQuery.of(context).size.width < 360;
    final theme = Theme.of(context);
    final s = MediaQuery.sizeOf(context);
    // Default expanded on roomy layouts; collapsed on small phones (narrow width).
    final fineTuneExpandedDefault = s.height >= 600 && s.width >= 380;

    final fs = fontSize.clamp(kReaderFontSizeMin, kReaderFontSizeMax);
    final lh = lineHeight.clamp(kReaderLineHeightMin, kReaderLineHeightMax);

    final presetRows = <(String, _TypographyPreset)>[
      (loc.readerTypographyCompact, _TypographyPreset.compact),
      (loc.readerTypographyStandard, _TypographyPreset.standard),
      (loc.readerTypographyComfortable, _TypographyPreset.comfortable),
    ];

    final cells = [
      ReaderSettingsValueCell(
        label: loc.fontSize,
        subtitle: loc.readerFontSizeHint,
        value: fs.toStringAsFixed(0),
        compact: true,
        onRemove: () => onSetFontSize((fs - 1).clamp(
              kReaderFontSizeMin,
              kReaderFontSizeMax,
            )),
        onAdd: () => onSetFontSize((fs + 1).clamp(
              kReaderFontSizeMin,
              kReaderFontSizeMax,
            )),
      ),
      ReaderSettingsValueCell(
        label: loc.lineHeight,
        subtitle: loc.readerLineHeightHint,
        value: lh.toStringAsFixed(1),
        compact: true,
        onRemove: () => onSetLineHeight((lh - 0.1).clamp(
              kReaderLineHeightMin,
              kReaderLineHeightMax,
            )),
        onAdd: () => onSetLineHeight((lh + 0.1).clamp(
              kReaderLineHeightMin,
              kReaderLineHeightMax,
            )),
      ),
    ];

    return NyanSheetCard(
      key: Key(
        isCompactWidth
            ? 'reader-menu-typography-compact'
            : 'reader-menu-typography-wide',
      ),
      radius: NyanRadius.card,
      children: [
        Padding(
          padding: EdgeInsets.all(
            denseLayout ? NyanSpacing.space12 : NyanSpacing.space16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (var i = 0; i < presetRows.length; i++) ...[
                    if (i > 0) const SizedBox(width: NyanSpacing.space8),
                    Expanded(
                      child: NyanPillButton(
                        label: presetRows[i].$1,
                        selected: _TypographyPreset.matches(
                          fs,
                          lh,
                          presetRows[i].$2,
                        ),
                        onPressed: () => _applyPreset(presetRows[i].$2),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(
                height: denseLayout ? NyanSpacing.space8 : NyanSpacing.space12,
              ),
              _FontFamilyRow(
                useSerif: useSerif,
                sansLabel: loc.readerFontFamilySans,
                serifLabel: loc.readerFontFamilySerif,
                sectionLabel: loc.readerFontFamily,
                onSelect: onSetUseSerif,
              ),
              SizedBox(
                height: denseLayout ? NyanSpacing.space8 : NyanSpacing.space12,
              ),
              _FontPreviewTile(
                useSerif: useSerif,
                textColor: textColor,
                backgroundColor: backgroundColor,
              ),
              SizedBox(
                height: denseLayout ? NyanSpacing.space8 : NyanSpacing.space12,
              ),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const PageStorageKey<String>('reader-text-finetune'),
                  maintainState: true,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.only(
                    top: denseLayout ? NyanSpacing.space8 : NyanSpacing.space12,
                  ),
                  initiallyExpanded: fineTuneExpandedDefault,
                  collapsedShape: const RoundedRectangleBorder(
                    side: BorderSide(color: Colors.transparent),
                  ),
                  shape: const RoundedRectangleBorder(
                    side: BorderSide(color: Colors.transparent),
                  ),
                  title: Text(
                    loc.readerTypographyFineTune,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  subtitle: Text(
                    loc.readerTypographyFineTuneSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      height: 1.12,
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.68),
                    ),
                  ),
                  iconColor: theme.colorScheme.primary,
                  collapsedIconColor: theme.colorScheme.primary,
                  children: [
                    if (isCompactWidth)
                      Column(
                        children: [
                          cells[0],
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: NyanSpacing.space12,
                            ),
                            child: Divider(
                              height: 1,
                              thickness: 0.72,
                              color: theme.dividerColor.withValues(alpha: 0.12),
                            ),
                          ),
                          cells[1],
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cells[0]),
                          const SizedBox(width: NyanSpacing.space16),
                          Expanded(child: cells[1]),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypographyPreset {
  const _TypographyPreset(this.fontSize, this.lineHeight);

  final double fontSize;
  final double lineHeight;

  static const compact = _TypographyPreset(15, 1.35);
  static const standard = _TypographyPreset(18, 1.5);
  static const comfortable = _TypographyPreset(22, 1.75);

  static bool matches(double fs, double lh, _TypographyPreset p) {
    return (fs - p.fontSize).abs() < 0.55 && (lh - p.lineHeight).abs() < 0.06;
  }
}

/// Spec `ReaderSettingsSheet.jsx` font-family knob: two pills (Sans / Serif)
/// using [NyanPillButton] (outline-on-select, no fill).
class _FontFamilyRow extends StatelessWidget {
  const _FontFamilyRow({
    required this.useSerif,
    required this.sansLabel,
    required this.serifLabel,
    required this.sectionLabel,
    required this.onSelect,
  });

  final bool useSerif;
  final String sansLabel;
  final String serifLabel;
  final String sectionLabel;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionLabel,
          style: TextStyle(
            fontFamily: NyanTypography.uiFontFamily,
            fontSize: NyanTypography.meta,
            fontWeight: FontWeight.w500,
            color: nyan.textSecondary,
          ),
        ),
        const SizedBox(height: NyanSpacing.space8),
        Row(
          children: [
            Expanded(
              child: NyanPillButton(
                label: sansLabel,
                selected: !useSerif,
                onPressed: () => onSelect(false),
              ),
            ),
            const SizedBox(width: NyanSpacing.space8),
            Expanded(
              child: NyanPillButton(
                label: serifLabel,
                selected: useSerif,
                onPressed: () => onSelect(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Live preview tile showing sample text rendered in the selected font family,
/// using the reader's actual text and background colours for accuracy.
class _FontPreviewTile extends StatelessWidget {
  const _FontPreviewTile({
    required this.useSerif,
    required this.textColor,
    required this.backgroundColor,
  });

  final bool useSerif;
  final Color textColor;
  final Color backgroundColor;

  // A bilingual sample that exercises both Latin and CJK glyphs so the
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
        horizontal: NyanSpacing.space16,
        vertical: NyanSpacing.space12,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(NyanRadius.card),
      ),
      child: Text(
        _sample,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: NyanTypography.body,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: textColor,
        ),
      ),
    );
  }
}

// _TypographyPresetChip removed — typography presets now use the project
// signature [NyanPillButton] (outline-on-select, no fill), matching the spec
// `ReaderSettingsSheet.jsx` and aligning with the warmth preset row.
