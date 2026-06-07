import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:nyan_read/l10n/app_localizations.dart';

import '../../../../core/services/reader_preferences_service.dart';
import '../../../../core/theme/nyan_colors.dart';
import '../../../../core/theme/nyan_spacing.dart';
import '../../../../core/theme/nyan_typography.dart';
import '../../../../core/ui/components/nyan_pill_button.dart';
import '../../../../core/ui/nyan_theme_context.dart';
import '../../controllers/brightness_controller.dart';
import 'reader_settings_common.dart';

/// Brightness, warmth, and page-turn mode (Display tab).
///
/// Layout per spec `reader.jsx` `DisplayPanel`:
///   Brightness Knob (slider → Follow-system switch below)
///   Warmth Knob     (slider → Low/Medium/High pills below)
///   Page Turn Mode Knob (Tap/Swipe/Disabled pills)
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

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final gap = denseLayout ? NyanSpacing.space8 : NyanSpacing.space12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Brightness ────────────────────────────────────────────────────
        ListenableBuilder(
          listenable: brightnessController,
          builder: (context, _) {
            final follow = brightnessController.followSystem;
            return ReaderSettingsKnob(
              label: loc.readerBrightness,
              hint: loc.readerBrightnessHint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedOpacity(
                    opacity: follow ? 0.38 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: follow,
                      child: ValueListenableBuilder<double>(
                        valueListenable: brightnessController.uiBrightnessValue,
                        builder: (context, brightness, _) {
                          return ReaderSettingsSlider(
                            value: brightness.clamp(0.0, 1.0),
                            onChanged: brightnessController.setFromSlider,
                            onChangeEnd: brightnessController.commitFromSlider,
                            activeColor: nyan.primaryDeep,
                            enabled: !follow,
                            edgeToEdgeTrack: true,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        loc.readerFollowSystemBrightness,
                        style: TextStyle(
                          fontFamily: NyanTypography.uiFontFamily,
                          fontSize: NyanTypography.meta,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                          color: nyan.textSecondary,
                        ),
                      ),
                      _NyanSwitch(
                        value: follow,
                        onChanged: (_) =>
                            brightnessController.toggleFollowSystem(),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        SizedBox(height: gap),
        // ── Warmth ────────────────────────────────────────────────────────
        ReaderSettingsKnob(
          label: loc.readerWarmth,
          hint: loc.readerWarmthHint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: brightnessController.warmthListenable,
                builder: (context, warmth, _) {
                  return ReaderSettingsSlider(
                    value: warmth.clamp(0.0, 1.0),
                    onChanged: onWarmthChanged,
                    activeColor: NyanColors.highlightOrange,
                    edgeToEdgeTrack: true,
                  );
                },
              ),
              const SizedBox(height: NyanSpacing.space12),
              _WarmthPresetRow(
                lowLabel: loc.readerWarmthLow,
                mediumLabel: loc.readerWarmthMedium,
                highLabel: loc.readerWarmthHigh,
                warmthListenable: brightnessController.warmthListenable,
                onSelect: onWarmthChanged,
              ),
            ],
          ),
        ),
        SizedBox(height: gap),
        // ── Page Turn Mode ────────────────────────────────────────────────
        ReaderSettingsKnob(
          label: loc.pageTurnMode,
          child: _PageTurnModeRow(
            pageTurnMode: pageTurnMode,
            tapLabel: loc.pageTurnTap,
            swipeLabel: loc.pageTurnSwipe,
            disabledLabel: loc.pageTurnDisabled,
            onSelect: onSetPageTurnMode,
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

class _PageTurnModeRow extends StatelessWidget {
  const _PageTurnModeRow({
    required this.pageTurnMode,
    required this.tapLabel,
    required this.swipeLabel,
    required this.disabledLabel,
    required this.onSelect,
  });

  final PageTurnMode pageTurnMode;
  final String tapLabel;
  final String swipeLabel;
  final String disabledLabel;
  final ValueChanged<PageTurnMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final modes = PageTurnMode.values;
    final labels = [tapLabel, swipeLabel, disabledLabel];

    return Row(
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
    );
  }
}

/// Spec-matched toggle switch.
///
/// Spec `NyanSwitch` (`primitives.jsx`): 44×26pt container, `borderRadius: 999`,
/// 20pt surface-white thumb with 3pt inset. Animated via [AnimatedAlign].
class _NyanSwitch extends StatelessWidget {
  const _NyanSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: value ? nyan.primary : nyan.divider,
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            // Spec: thumb left 3px (off) → left 21px (on), thumb 20pt.
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: nyan.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
