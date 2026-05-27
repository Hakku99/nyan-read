import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../../../core/services/reader_preferences_service.dart';
import '../../../../core/theme/nyan_colors.dart';
import '../../../../core/theme/nyan_radius.dart';
import '../../../../core/theme/nyan_spacing.dart';
import '../../../../core/theme/nyan_typography.dart';
import '../../../../core/ui/components/nyan_pill_button.dart';
import '../../../../core/ui/components/nyan_sheet_card.dart';
import '../../../../core/ui/nyan_theme_context.dart';
import '../../controllers/brightness_controller.dart';
import 'reader_settings_common.dart';

/// Brightness, auto, warmth, and page-turn mode (Display tab).
class ReaderSettingsDisplayPanel extends StatelessWidget {
  const ReaderSettingsDisplayPanel({
    super.key,
    required this.brightnessController,
    required this.loc,
    required this.onWarmthChanged,
    required this.pageTurnMode,
    required this.onSetPageTurnMode,
    this.denseLayout = false,
  });

  final BrightnessController brightnessController;
  final AppLocalizations loc;
  final ValueChanged<double> onWarmthChanged;
  final PageTurnMode pageTurnMode;
  final ValueChanged<PageTurnMode> onSetPageTurnMode;
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
              _PageTurnModeRow(
                pageTurnMode: pageTurnMode,
                tapLabel: loc.pageTurnTap,
                swipeLabel: loc.pageTurnSwipe,
                disabledLabel: loc.pageTurnDisabled,
                sectionLabel: loc.pageTurnMode,
                onSelect: onSetPageTurnMode,
              ),
              SizedBox(
                height: denseLayout ? NyanSpacing.space8 : NyanSpacing.space16,
              ),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _BrightnessPresetRow(
                                  dimLabel: loc.readerBrightnessDim,
                                  normalLabel: loc.readerBrightnessNormal,
                                  brightLabel: loc.readerBrightnessBright,
                                  brightnessListenable:
                                      brightnessController.uiBrightnessValue,
                                  onSelect: brightnessController.setBrightness,
                                ),
                                SizedBox(
                                  height: denseLayout
                                      ? NyanSpacing.space4
                                      : NyanSpacing.space8,
                                ),
                                ValueListenableBuilder<double>(
                                  valueListenable:
                                      brightnessController.uiBrightnessValue,
                                  builder: (context, brightness, _) {
                                    return ReaderSettingsSlider(
                                      value: brightness.clamp(0.0, 1.0),
                                      onChanged:
                                          brightnessController.setFromSlider,
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
                              ],
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

/// Spec `ReaderSettingsSheet.jsx` page-turn mode knob: 3 pill buttons
/// (Tap / Swipe / Disabled) using [NyanPillButton] (outline-on-select, no
/// fill).  Placed at the top of the Display panel, above brightness.
class _PageTurnModeRow extends StatelessWidget {
  const _PageTurnModeRow({
    required this.pageTurnMode,
    required this.tapLabel,
    required this.swipeLabel,
    required this.disabledLabel,
    required this.sectionLabel,
    required this.onSelect,
  });

  final PageTurnMode pageTurnMode;
  final String tapLabel;
  final String swipeLabel;
  final String disabledLabel;
  final String sectionLabel;
  final ValueChanged<PageTurnMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final modes = PageTurnMode.values;
    final labels = [tapLabel, swipeLabel, disabledLabel];

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
            for (var i = 0; i < modes.length; i++) ...[
              if (i > 0) const SizedBox(width: NyanSpacing.space8),
              Expanded(
                child: NyanPillButton(
                  label: labels[i],
                  selected: pageTurnMode == modes[i],
                  onPressed: () => onSelect(modes[i]),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Brightness preset row: 3 pill buttons (Dim / Normal / Bright) mirroring the
/// warmth preset row. Disabled and dimmed when auto-brightness is active — the
/// parent [AnimatedOpacity] + [IgnorePointer] handles that automatically since
/// this widget lives inside the brightness slider column.
class _BrightnessPresetRow extends StatelessWidget {
  const _BrightnessPresetRow({
    required this.dimLabel,
    required this.normalLabel,
    required this.brightLabel,
    required this.brightnessListenable,
    required this.onSelect,
  });

  final String dimLabel;
  final String normalLabel;
  final String brightLabel;
  final ValueListenable<double> brightnessListenable;
  final ValueChanged<double> onSelect;

  // Dim / Normal / Bright target values. ±0.06 match window keeps a pill
  // highlighted when the slider is dragged very close to a preset.
  static const _presets = [0.25, 0.5, 0.8];

  @override
  Widget build(BuildContext context) {
    final labels = [dimLabel, normalLabel, brightLabel];

    return ValueListenableBuilder<double>(
      valueListenable: brightnessListenable,
      builder: (context, brightness, _) {
        final b = brightness.clamp(0.0, 1.0);
        return Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: NyanSpacing.space8),
              Expanded(
                child: NyanPillButton(
                  label: labels[i],
                  selected: (b - _presets[i]).abs() < 0.06,
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
