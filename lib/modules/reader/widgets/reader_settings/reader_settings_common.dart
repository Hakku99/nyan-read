import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/nyan_radius.dart';
import '../../../../core/theme/nyan_spacing.dart';
import '../../../../core/ui/components/nyan_overlay_style.dart';

/// Padding for overlay progress card and toolbar (keep in sync).
const EdgeInsets kReaderOverlayChromePadding =
    EdgeInsets.all(NyanSpacing.space8);

const double kReaderPillHeight = 40.0;
const BorderRadius kReaderPillBorderRadius =
    BorderRadius.all(Radius.circular(999));

/// Dense preset chips (warmth + typography); compact but tappable.
const double kReaderDensePresetMinHeight = kReaderPillHeight;

const EdgeInsets kReaderDensePresetPadding = EdgeInsets.symmetric(
  horizontal: NyanSpacing.space8,
  vertical: 2,
);

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
    this.overlayRadius = 16,
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
    final effective = widget.enabled ? widget.onChanged : null;

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: RoundSliderOverlayShape(overlayRadius: widget.overlayRadius),
        trackShape: widget.edgeToEdgeTrack
            ? const _EdgeToEdgeRoundedSliderTrackShape()
            : const RoundedRectSliderTrackShape(),
        thumbColor: widget.thumbColor ?? widget.activeColor,
        overlayColor: (widget.thumbColor ?? widget.activeColor)
            ?.withValues(alpha: 0.12),
        activeTrackColor: widget.activeColor,
        inactiveTrackColor: widget.inactiveColor,
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
                HapticFeedback.selectionClick();
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
      fontWeight: FontWeight.w700,
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

/// Minimum / maximum for reader typography controls (matches layout auto-scale range).
const double kReaderFontSizeMin = 12.0;
const double kReaderFontSizeMax = 32.0;
const double kReaderLineHeightMin = 1.1;
const double kReaderLineHeightMax = 2.5;

class ReaderSettingsIconButton extends StatelessWidget {
  const ReaderSettingsIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NyanRadius.input),
        child: Ink(
          height: NyanSpacing.minTapTarget,
          decoration: BoxDecoration(
            color: NyanOverlayStyle.recessedSurface(
              context,
              seed: theme.colorScheme.primary,
              strength: 0.02,
            ),
            borderRadius: BorderRadius.circular(NyanRadius.input),
          ),
          child: Icon(
            icon,
            size: 22,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}

class ReaderSettingsIconBadge extends StatelessWidget {
  const ReaderSettingsIconBadge({
    super.key,
    required this.icon,
    required this.iconColor,
  });

  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: NyanOverlayStyle.recessedSurface(
          context,
          seed: iconColor,
          strength: 0.08,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 22,
        color: iconColor,
      ),
    );
  }
}

class ReaderAutoBrightnessChip extends StatelessWidget {
  const ReaderAutoBrightnessChip({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      toggled: isActive,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: kReaderPillBorderRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
              horizontal: NyanSpacing.space12,
              vertical: 6,
            ),
            constraints: const BoxConstraints(minHeight: kReaderDensePresetMinHeight),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.14)
                  : NyanOverlayStyle.recessedSurface(context),
              borderRadius: kReaderPillBorderRadius,
              border: Border.all(
                color: isActive
                    ? theme.colorScheme.primary.withValues(alpha: 0.35)
                    : theme.dividerColor.withValues(alpha: 0.16),
                width: 0.72,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive
                      ? Icons.brightness_auto_rounded
                      : Icons.brightness_auto_outlined,
                  size: 18,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                ),
                const SizedBox(width: NyanSpacing.space4),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReaderSettingsSliderTile extends StatelessWidget {
  const ReaderSettingsSliderTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.slider,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget slider;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReaderSettingsIconBadge(icon: icon, iconColor: iconColor),
        const SizedBox(width: NyanSpacing.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: NyanSpacing.space4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            height: 1.12,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.68),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: NyanSpacing.space12),
                    trailing!,
                  ],
                ],
              ),
              const SizedBox(height: NyanSpacing.space12),
              slider,
            ],
          ),
        ),
      ],
    );
  }
}

class ReaderSettingsValueCell extends StatelessWidget {
  const ReaderSettingsValueCell({
    super.key,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onRemove,
    required this.onAdd,
    this.decreaseTooltip,
    this.increaseTooltip,
    this.compact = false,
  });

  final String label;
  final String subtitle;
  final String value;
  final VoidCallback onRemove;
  final VoidCallback onAdd;
  final String? decreaseTooltip;
  final String? increaseTooltip;

  /// Single-row [− value +] stepper; keeps 44dp minimum touch targets.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: NyanSpacing.space4),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            height: 1.12,
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.68),
          ),
        ),
        SizedBox(height: compact ? NyanSpacing.space8 : NyanSpacing.space12),
        if (compact)
          Row(
            children: [
              IconButton(
                style: IconButton.styleFrom(
                  minimumSize: const Size(
                    NyanSpacing.minTapTarget,
                    NyanSpacing.minTapTarget,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onRemove,
                tooltip: decreaseTooltip,
                icon: Icon(
                  Icons.remove_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  minimumSize: const Size(
                    NyanSpacing.minTapTarget,
                    NyanSpacing.minTapTarget,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onAdd,
                tooltip: increaseTooltip,
                icon: Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          )
        else ...[
          Text(
            value,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: NyanSpacing.space12),
          Row(
            children: [
              Expanded(
                child: ReaderSettingsIconButton(
                  icon: Icons.remove_rounded,
                  onTap: onRemove,
                  tooltip: decreaseTooltip,
                ),
              ),
              const SizedBox(width: NyanSpacing.space8),
              Expanded(
                child: ReaderSettingsIconButton(
                  icon: Icons.add_rounded,
                  onTap: onAdd,
                  tooltip: increaseTooltip,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
