import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/nyan_radius.dart';
import '../../../core/theme/nyan_shadows.dart';
import '../../../core/theme/nyan_spacing.dart';
import '../../../core/theme/nyan_typography.dart';
import '../../../core/theme/theme_presets.dart';
import '../../../core/ui/nyan_icons.dart';
import '../../../core/ui/nyan_theme_context.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/brightness_controller.dart';
import 'reader_settings/reader_settings_common.dart';

/// Brightness as a centered dialog over a warm glassmorphism overlay — the One
/// Paper brightness affordance reached from the top-bar sun button (the other
/// is the left-edge vertical drag). Brightness-only: a slider + "Follow system".
///
/// The glassmorphism blur is a deliberate, sanctioned exception to the
/// "paper, not glass" rule (see HANDOFF-flutter.md §4 / README); it is mounted
/// only while [visible] so the [BackdropFilter] carries no idle cost.
///
/// Source: `ReaderScreen.jsx` brightness dialog block.
class ReaderBrightnessPopover extends StatelessWidget {
  const ReaderBrightnessPopover({
    super.key,
    required this.visible,
    required this.controller,
    required this.onDismiss,
  });

  final bool visible;
  final BrightnessController controller;
  final VoidCallback onDismiss;

  static const Duration _kDur = Duration(milliseconds: 280);
  static const Curve _kEase = Cubic(0.33, 0.9, 0.36, 1.0);

  @override
  Widget build(BuildContext context) {
    // Mount the blurred overlay only while visible — no idle saveLayer cost.
    if (!visible) return const SizedBox.shrink();

    final nyan = context.nyanTheme;
    final loc = AppLocalizations.of(context)!;
    final isDark = nyan.brightness == Brightness.dark;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 13.6, sigmaY: 13.6),
          child: AnimatedOpacity(
            opacity: visible ? 1.0 : 0.0,
            duration: _kDur,
            curve: _kEase,
            child: ColoredBox(
              // Warm-ink wash so the page reads as "receded behind glass".
              color: nyan.background.withValues(alpha: isDark ? 0.42 : 0.46),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(NyanSpacing.space24),
                  child: LayoutBuilder(
                    builder: (context, outer) {
                      // Explicit card width: fill available space up to 320pt.
                      // LayoutBuilder resolves the real constraint so BackdropFilter
                      // can't shrink-wrap against content instead of the max.
                      final cardWidth = outer.maxWidth.clamp(0.0, 320.0);
                      return GestureDetector(
                      // Taps on the card must not dismiss.
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: SizedBox(
                          width: cardWidth,
                          // Shadow must live outside ClipRRect — BoxShadow
                          // renders beyond the box bounds and would be clipped
                          // otherwise, making it invisible.
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(NyanRadius.sheet),
                              boxShadow: NyanShadows.lightCard(nyan),
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(NyanRadius.sheet),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    // Semi-transparent frosted-glass card.
                                    color: nyan.surface.withValues(
                                      alpha: isDark ? 0.88 : 0.82,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(NyanRadius.sheet),
                                    border: Border.all(
                                      // Spec: color-mix(surface 70%, chrome-edge)
                                      // chrome-edge = transparent (light) / divider (dark)
                                      color: isDark
                                          ? Color.lerp(
                                              nyan.surface,
                                              nyan.divider,
                                              0.30,
                                            )!
                                          : nyan.surface.withValues(alpha: 0.70),
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(22),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _header(nyan, loc),
                                        const SizedBox(height: 18),
                                        _sliderRow(nyan),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(NyanTheme nyan, AppLocalizations loc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: nyan.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(NyanRadius.control),
          ),
          alignment: Alignment.center,
          child: Icon(NyanIcons.sun, size: 20, color: nyan.primaryDeep),
        ),
        const SizedBox(width: NyanSpacing.space12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.readerBrightness,
                style: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                  height: 1.15,
                  color: nyan.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                loc.readerBrightnessHint,
                style: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: nyan.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: NyanSpacing.space8),
        ValueListenableBuilder<double>(
          valueListenable: controller.uiBrightnessValue,
          builder: (context, v, _) => Text(
            '${(v.clamp(0.0, 1.0) * 100).round()}%',
            style: TextStyle(
              fontFamily: NyanTypography.monoFontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.0,
              color: nyan.primaryDeep,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sliderRow(NyanTheme nyan) {
    return Row(
      children: [
        Icon(NyanIcons.moon, size: 18, color: nyan.textMuted),
        const SizedBox(width: NyanSpacing.space12),
        Expanded(
          child: ValueListenableBuilder<double>(
            valueListenable: controller.uiBrightnessValue,
            builder: (context, v, _) => ReaderSettingsSlider(
              value: v.clamp(0.0, 1.0),
              activeColor: nyan.primaryDeep,
              inactiveColor: nyan.surfaceMuted,
              thumbColor: nyan.primaryDeep,
              onChanged: controller.setFromSlider,
            ),
          ),
        ),
        const SizedBox(width: NyanSpacing.space12),
        Icon(NyanIcons.sun, size: 18, color: nyan.textMuted),
      ],
    );
  }
}
