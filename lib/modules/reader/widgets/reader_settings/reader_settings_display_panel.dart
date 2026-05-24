import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../../../core/theme/nyan_colors.dart';
import '../../../../core/theme/nyan_radius.dart';
import '../../../../core/theme/nyan_spacing.dart';
import '../../../../core/ui/components/nyan_pill_button.dart';
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
                        icon: NyanIcons.sun,
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
                                  activeColor: nyanTheme.primaryDeep,
                                  inactiveColor: theme.dividerColor
                                      .withValues(alpha: 0.24),
                                  enabled: !follow,
                                  edgeToEdgeTrack: true,
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
                              NyanIcons.phone,
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
                icon: NyanIcons.thermostat,
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
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(width: NyanSpacing.space8),
                        Text(
                          '${(w * 100).round()}%',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
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
                          edgeToEdgeTrack: true,
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

/// Spec `ReaderSettingsSheet.jsx` warmth knob: 3 pill buttons (Low/Medium/High)
/// using the project signature [NyanPillButton] (outline-on-select, no fill).
/// Replaces the previous custom `_WarmthPresetChip` which used a filled style
/// with [FontWeight.w700] — a token violation per AGENTS.md §4.2.
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
                child: NyanPillButton(
                  label: labels[i],
                  selected: (w - _presets[i]).abs() < 0.06,
                  onPressed: () => onSelect(_presets[i]),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
