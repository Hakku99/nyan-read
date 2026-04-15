import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/ui/components/nyan_overlay_style.dart';
import '../../../l10n/app_localizations.dart';
import '../controllers/brightness_controller.dart';

/// Center floating brightness HUD.
///
/// Gesture entry stays on left edge, but feedback appears in middle for
/// better readability and calmer visual balance.
class BrightnessHudWidget extends StatefulWidget {
  final BrightnessController controller;

  const BrightnessHudWidget({
    super.key,
    required this.controller,
  });

  @override
  State<BrightnessHudWidget> createState() => _BrightnessHudWidgetState();
}

class _BrightnessHudWidgetState extends State<BrightnessHudWidget> {
  int _lastHapticStep = -1;
  int _lastAnimatedPercent = -1;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ValueListenableBuilder<bool>(
          valueListenable: widget.controller.isAdjusting,
          builder: (context, isAdjusting, _) {
            return Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: isAdjusting ? 1 : 0),
                duration: Duration(
                  milliseconds: isAdjusting
                      ? NyanOverlayStyle.overlayTransitionDuration.inMilliseconds
                      : 130,
                ),
                curve: NyanOverlayStyle.overlayCurve,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 8),
                      child: Transform.scale(
                        scale: 0.98 + (0.02 * value),
                        child: child,
                      ),
                    ),
                  );
                },
                child: ValueListenableBuilder<double>(
                  valueListenable: widget.controller.uiBrightnessValue,
                  builder: (context, brightness, _) {
                    final percent = (brightness * 100).toInt();
                    final currentStep = (brightness * 10).floor();
                    if (isAdjusting && currentStep != _lastHapticStep) {
                      _lastHapticStep = currentStep;
                      HapticFeedback.selectionClick();
                    }
                    if ((percent - _lastAnimatedPercent).abs() >= 2 ||
                        _lastAnimatedPercent < 0) {
                      _lastAnimatedPercent = percent;
                    }
                    return _BrightnessCenterPanel(
                      brightness: brightness,
                      animatedPercent: _lastAnimatedPercent,
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrightnessCenterPanel extends StatelessWidget {
  const _BrightnessCenterPanel({
    required this.brightness,
    required this.animatedPercent,
  });

  final double brightness;
  final int animatedPercent;

  static const double _hardwareFloor = 0.10;
  static const double _panelWidth = 236.0;
  static const double _panelRadius = 24.0;

  @override
  Widget build(BuildContext context) {
    final isSubZero = brightness < _hardwareFloor;
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context)!;
    final primaryHsl = HSLColor.fromColor(cs.primary);
    final primary = primaryHsl
        .withLightness((primaryHsl.lightness - 0.04).clamp(0.0, 1.0))
        .toColor();
    final subZeroHsl = HSLColor.fromColor(primary);
    final subZeroAccent = subZeroHsl
        .withLightness((subZeroHsl.lightness + 0.06).clamp(0.0, 1.0))
        .withSaturation((subZeroHsl.saturation * 0.72).clamp(0.0, 1.0))
        .toColor();
    final accent = isSubZero ? subZeroAccent : primary;
    final percent = (brightness * 100).toInt();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_panelRadius),
        boxShadow: NyanOverlayStyle.noticeShadow(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_panelRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                cs.surface.withValues(alpha: 0.92),
                Theme.of(context).scaffoldBackgroundColor,
              ),
              borderRadius: BorderRadius.circular(_panelRadius),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.18),
                width: 0.72,
              ),
            ),
            child: SizedBox(
              width: _panelWidth,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.readerBrightness,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface.withValues(alpha: 0.58),
                          ),
                    ),
                    const SizedBox(height: 10),
                    _BrightnessTrack(
                      brightness: brightness,
                      accent: accent,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 58,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: animatedPercent.toDouble(),
                              end: percent.toDouble(),
                            ),
                            duration: const Duration(milliseconds: 120),
                            builder: (context, value, _) {
                              return Text(
                                '${value.round()}%',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontSize: 21,
                                      height: 1.0,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                      color: accent,
                                    ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              height: 32,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 160),
                                layoutBuilder: (currentChild, previousChildren) {
                                  return Stack(
                                    alignment: Alignment.centerRight,
                                    children: [
                                      ...previousChildren,
                                      if (currentChild != null) currentChild,
                                    ],
                                  );
                                },
                                child: isSubZero
                                    ? Text(
                                        loc.readerSoftwareDimModeActive,
                                        key: const ValueKey('subZeroHint'),
                                        textAlign: TextAlign.right,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w400,
                                              height: 1.18,
                                              color: cs.onSurfaceVariant.withValues(alpha: 0.72),
                                            ),
                                      )
                                    : const SizedBox(key: ValueKey('normalModeHint')),
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _BrightnessTrack extends StatelessWidget {
  const _BrightnessTrack({
    required this.brightness,
    required this.accent,
  });

  final double brightness;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final clamped = brightness.clamp(0.0, 1.0);
    final cs = Theme.of(context).colorScheme;
    final thumbBorder = cs.surface.withValues(alpha: 0.72);

    return Row(
      children: [
        Icon(
          Icons.dark_mode_outlined,
          size: 16,
          color: cs.onSurface.withValues(alpha: 0.58),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.17),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: clamped,
                    child: Container(
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const thumbSize = 14.0;
                      final maxLeft = (constraints.maxWidth - thumbSize).clamp(0.0, double.infinity);
                      final left = (clamped * maxLeft).clamp(0.0, maxLeft);
                      return Stack(
                        children: [
                          Positioned(
                            left: left,
                            top: -1,
                            child: Container(
                              width: thumbSize,
                              height: thumbSize,
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: thumbBorder.withValues(alpha: 0.78),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.light_mode_rounded,
          size: 16,
          color: cs.onSurface.withValues(alpha: 0.58),
        ),
      ],
    );
  }
}
