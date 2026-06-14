import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/nyan_radius.dart';
import '../../../../core/theme/nyan_spacing.dart';
import '../../../../core/theme/nyan_typography.dart';
import '../../../../core/ui/nyan_theme_context.dart';

/// Padding for overlay progress card and toolbar (keep in sync).
const EdgeInsets kReaderOverlayChromePadding =
    EdgeInsets.all(NyanSpacing.space8);

/// Minimum / maximum for reader typography controls (matches layout auto-scale range).
const double kReaderFontSizeMin = 12.0;
const double kReaderFontSizeMax = 32.0;
const double kReaderLineHeightMin = 1.1;
const double kReaderLineHeightMax = 2.5;

/// Spec-aligned Knob container wrapping each reader-settings control group.
/// Background: [NyanTheme.surfaceMuted]; radius: [NyanRadius.cardNested] (16pt);
/// padding: 14pt (spec-defined exception to §4.2.3 — `reader.jsx` `Knob { padding: 14 }`).
/// Header: bold 15px label left + optional 13px meta hint right.
///
/// Source: `components/reader.jsx` `Knob`.
class ReaderSettingsKnob extends StatelessWidget {
  const ReaderSettingsKnob({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final String? hint;
  final Widget child;

  // Deliberate exception to §4.2.3 — spec `reader.jsx` Knob { padding: 14 }.
  // §4.6: delivery package takes priority over the 8-multiple spacing rule.
  static const double _kPadding = 14.0;
  // Spec: 600 / 15px label. §4.6 exception to the 6-size type ladder (§4.2.5).
  static const double _kLabelSize = 15.0;
  // Spec: marginBottom 11px between label row and control children.
  static const double _kHeaderGap = 11.0;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    return Container(
      decoration: BoxDecoration(
        color: nyan.surfaceMuted,
        borderRadius: BorderRadius.circular(NyanRadius.cardNested),
      ),
      padding: const EdgeInsets.all(_kPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  fontSize: _kLabelSize,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: nyan.textPrimary,
                ),
              ),
              if (hint != null)
                Text(
                  hint!,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: NyanTypography.meta,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                    color: nyan.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: _kHeaderGap),
          child,
        ],
      ),
    );
  }
}

/// Ring thumb per spec `NyanSlider`: surface-white fill + activeColor ring @60% + soft lift.
/// Source: `components/primitives.jsx` `NyanSlider` thumb style.
class _NyanRingThumbShape extends SliderComponentShape {
  const _NyanRingThumbShape({
    required this.surfaceColor,
    required this.ringColor,
  });

  final Color surfaceColor;
  final Color ringColor;

  // Spec NyanSlider thumb: 20pt diameter (10pt radius).
  static const double _kRadius = 10.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(_kRadius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Spec: "0 1px 4px shadow@28%" lift
    canvas.drawCircle(
      center.translate(0, 1),
      _kRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );

    // Spec: "0 0 0 1.5px ringColor@60%" — wider filled circle behind fill
    canvas.drawCircle(
      center,
      _kRadius + 1.5,
      Paint()
        ..color = ringColor.withValues(alpha: 0.60)
        ..style = PaintingStyle.fill,
    );

    // Surface white fill
    canvas.drawCircle(
      center,
      _kRadius,
      Paint()
        ..color = surfaceColor
        ..style = PaintingStyle.fill,
    );
  }
}

/// Shared slider with a floating percentage label while dragging.
class ReaderSettingsSlider extends StatefulWidget {
  const ReaderSettingsSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.enabled = true,
    this.dragLabelAbove = false,
    this.dragLabelBelowGap,
    this.overlayRadius = 0,
    this.horizontalStretch = 0,
    this.edgeToEdgeTrack = false,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final bool enabled;

  /// When true, drag % label sits above the track (ignored if [dragLabelBelowGap] is set).
  final bool dragLabelAbove;

  /// When non-null, drag % sits [dragLabelBelowGap] px below the track (fixed layout).
  final double? dragLabelBelowGap;
  final double overlayRadius;
  final double horizontalStretch;
  final bool edgeToEdgeTrack;

  @override
  State<ReaderSettingsSlider> createState() => _ReaderSettingsSliderState();
}

class _ReaderSettingsSliderState extends State<ReaderSettingsSlider> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyan = context.nyanTheme;
    final effective = widget.enabled ? widget.onChanged : null;
    final effectiveActiveColor = widget.activeColor ?? nyan.primaryDeep;
    // Spec `NyanSlider`: inactive track = textPrimary@12% (overridable per-call).
    final effectiveInactiveColor =
        widget.inactiveColor ?? nyan.textPrimary.withValues(alpha: 0.12);

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        // Spec NyanSlider: track height 6px.
        trackHeight: 6,
        thumbShape: _NyanRingThumbShape(
          surfaceColor: nyan.surface,
          ringColor: effectiveActiveColor,
        ),
        overlayShape: RoundSliderOverlayShape(overlayRadius: widget.overlayRadius),
        trackShape: widget.edgeToEdgeTrack
            ? const _EdgeToEdgeRoundedSliderTrackShape()
            : const RoundedRectSliderTrackShape(),
        thumbColor: effectiveActiveColor,
        overlayColor: effectiveActiveColor.withValues(alpha: 0.12),
        activeTrackColor: effectiveActiveColor,
        inactiveTrackColor: effectiveInactiveColor,
      ),
      child: Slider(
        value: widget.value,
        min: widget.min,
        max: widget.max,
        divisions: widget.divisions,
        onChanged: effective,
        onChangeStart: effective != null
            ? (_) => setState(() => _isDragging = true)
            : null,
        onChangeEnd: effective != null
            ? (value) {
                setState(() => _isDragging = false);
                HapticFeedback.lightImpact();
                widget.onChangeEnd?.call(value);
              }
            : null,
      ),
    );
    final sliderChild = widget.horizontalStretch == 0
        ? slider
        : LayoutBuilder(
            builder: (context, constraints) {
              final stretchedWidth =
                  constraints.maxWidth + (widget.horizontalStretch * 2);
              return Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: stretchedWidth,
                  child: slider,
                ),
              );
            },
          );

    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: (widget.activeColor ?? theme.colorScheme.primary)
          .withValues(alpha: 0.82),
    );

    final dragLabel = AnimatedOpacity(
      opacity: _isDragging && effective != null ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 160),
      child: Text(
        '${(widget.value * 100).round()}%',
        style: labelStyle,
      ),
    );

    final gap = widget.dragLabelBelowGap;
    if (gap != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sliderChild,
          SizedBox(height: gap),
          SizedBox(
            height: 14,
            child: Center(child: dragLabel),
          ),
        ],
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        sliderChild,
        Positioned(
          top: widget.dragLabelAbove ? -20 : null,
          bottom: widget.dragLabelAbove ? null : -12,
          child: dragLabel,
        ),
      ],
    );
  }
}

/// Compact icon button for settings panels (chevron navigation in progress card).
///
/// 36×36pt tap area, [NyanRadius.chip] (12pt) corners, [surface] background.
class ReaderSettingsIconButton extends StatelessWidget {
  const ReaderSettingsIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    Widget child = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: nyan.surface,
          borderRadius: BorderRadius.circular(NyanRadius.chip),
          border: Border.all(color: nyan.divider, width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: nyan.textPrimary),
      ),
    );
    if (tooltip != null) {
      child = Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}

/// Uses the whole available width for track rect to align sliders with
/// surrounding text/action baselines instead of keeping Material's inner inset.
class _EdgeToEdgeRoundedSliderTrackShape extends RoundedRectSliderTrackShape {
  const _EdgeToEdgeRoundedSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 0;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
