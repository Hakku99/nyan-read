import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nyan_read/l10n/app_localizations.dart';

import '../../../../core/theme/nyan_colors.dart';
import '../../../../core/theme/nyan_radius.dart';
import '../../../../core/theme/nyan_spacing.dart';
import '../../../../core/ui/components/nyan_sheet_card.dart';
import '../../../../core/ui/nyan_theme_context.dart';
import '../../controllers/brightness_controller.dart';
import 'reader_settings_common.dart';

/// Brightness, auto, and warmth (Display tab).
class ReaderSettingsDisplayPanel extends StatelessWidget {
  const ReaderSettingsDisplayPanel({
    super.key,
    required this.brightnessController,
    required this.loc,
    required this.onWarmthChanged,
    this.denseLayout = false,
  });

  final BrightnessController brightnessController;
  final AppLocalizations loc;
  final ValueChanged<double> onWarmthChanged;
  final bool denseLayout;

  static String _warmthTierLabel(AppLocalizations loc, double warmth) {
    final w = warmth.clamp(0.0, 1.0);
    if (w < 0.34) return loc.readerWarmthLow;
    if (w < 0.67) return loc.readerWarmthMedium;
    return loc.readerWarmthHigh;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final isDarkApp = theme.brightness == Brightness.dark;
    final warmthInactive = NyanColors.highlightOrange.withValues(
      alpha: isDarkApp ? 0.26 : 0.18,
    );

    return NyanSheetCard(
      key: const Key('reader-menu-display-panel'),
      radius: NyanRadius.card,
      children: [
        Padding(
          padding: EdgeInsets.all(
            denseLayout ? NyanSpacing.space12 : NyanSpacing.space16,
          ),
          child: Column(
            children: [
              ListenableBuilder(
                listenable: brightnessController,
                builder: (context, _) {
                  final follow = brightnessController.followSystem;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ReaderSettingsSliderTile(
                        icon: Icons.wb_sunny_rounded,
                        iconColor: nyanTheme.primaryDeep,
                        title: loc.readerBrightness,
                        subtitle: loc.readerBrightnessHint,
                        trailing: ReaderAutoBrightnessChip(
                          label: loc.readerAutoBrightness,
                          semanticsLabel: loc.readerFollowSystemBrightness,
                          isActive: follow,
                          onTap: brightnessController.toggleFollowSystem,
                        ),
                        slider: AnimatedOpacity(
                          opacity: follow ? 0.38 : 1,
                          duration: const Duration(milliseconds: 200),
                          child: IgnorePointer(
                            ignoring: follow,
                            child: ValueListenableBuilder<double>(
                              valueListenable:
                                  brightnessController.uiBrightnessValue,
                              builder: (context, brightness, _) {
                                return ReaderSettingsSlider(
                                  value: brightness.clamp(0.0, 1.0),
                                  onChanged: brightnessController.setFromSlider,
                                  onChangeEnd:
                                      brightnessController.commitFromSlider,
                                  activeColor: nyanTheme.primary,
                                  inactiveColor: theme.dividerColor
                                      .withValues(alpha: 0.24),
                                  enabled: !follow,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      if (follow) ...[
                        SizedBox(
                          height:
                              denseLayout ? NyanSpacing.space4 : NyanSpacing.space8,
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_android_rounded,
                              size: 14,
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.75),
                            ),
                            const SizedBox(width: NyanSpacing.space8),
                            Expanded(
                              child: Text(
                                loc.readerBrightnessFollowingSystem,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.82),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
              SizedBox(
                height: denseLayout ? NyanSpacing.space8 : NyanSpacing.space16,
              ),
              ReaderSettingsSliderTile(
                icon: Icons.thermostat_rounded,
                iconColor: NyanColors.highlightOrange,
                title: loc.readerWarmth,
                subtitle: loc.readerWarmthHint,
                trailing: ValueListenableBuilder<double>(
                  valueListenable: brightnessController.warmthListenable,
                  builder: (context, warmth, _) {
                    final w = warmth.clamp(0.0, 1.0);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _warmthTierLabel(loc, w),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(width: NyanSpacing.space8),
                        Text(
                          '${(w * 100).round()}%',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                slider: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WarmthPresetRow(
                      lowLabel: loc.readerWarmthLow,
                      mediumLabel: loc.readerWarmthMedium,
                      highLabel: loc.readerWarmthHigh,
                      warmthListenable: brightnessController.warmthListenable,
                      onSelect: onWarmthChanged,
                    ),
                    SizedBox(
                      height:
                          denseLayout ? NyanSpacing.space4 : NyanSpacing.space8,
                    ),
                    ValueListenableBuilder<double>(
                      valueListenable: brightnessController.warmthListenable,
                      builder: (context, warmth, _) {
                        return ReaderSettingsSlider(
                          value: warmth.clamp(0.0, 1.0),
                          onChanged: onWarmthChanged,
                          activeColor: NyanColors.highlightOrange,
                          thumbColor: NyanColors.highlightOrange
                              .withValues(alpha: 0.95),
                          inactiveColor: warmthInactive,
                        );
                      },
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

class _WarmthPresetRow extends StatelessWidget {
  const _WarmthPresetRow({
    required this.lowLabel,
    required this.mediumLabel,
    required this.highLabel,
    required this.warmthListenable,
    required this.onSelect,
  });

  final String lowLabel;
  final String mediumLabel;
  final String highLabel;
  final ValueListenable<double> warmthListenable;
  final ValueChanged<double> onSelect;

  static const _presets = [0.0, 0.5, 1.0];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = [lowLabel, mediumLabel, highLabel];

    return ValueListenableBuilder<double>(
      valueListenable: warmthListenable,
      builder: (context, warmth, _) {
        final w = warmth.clamp(0.0, 1.0);
        return Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: NyanSpacing.space8),
              Expanded(
                child: _WarmthPresetChip(
                  label: labels[i],
                  selected: (w - _presets[i]).abs() < 0.06,
                  onTap: () => onSelect(_presets[i]),
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _WarmthPresetChip extends StatelessWidget {
  const _WarmthPresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: kReaderPillBorderRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: kReaderDensePresetPadding,
          constraints: const BoxConstraints(
            minHeight: kReaderDensePresetMinHeight,
          ),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.35),
            borderRadius: kReaderPillBorderRadius,
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.45)
                  : theme.dividerColor.withValues(alpha: 0.14),
              width: selected ? 1.1 : 0.72,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected
                  ? color
                  : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}
