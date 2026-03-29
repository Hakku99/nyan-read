import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import 'nyan_overlay_style.dart';

enum NyanDialogOptionControl { checkbox, switchControl }

enum NyanDialogOptionVariant { embedded, card }

class NyanDialogOptionRow extends StatelessWidget {
  const NyanDialogOptionRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.control = NyanDialogOptionControl.checkbox,
    this.variant = NyanDialogOptionVariant.embedded,
    this.isDanger = false,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final NyanDialogOptionControl control;
  final NyanDialogOptionVariant variant;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controlPalette = NyanOverlayStyle.tonePalette(
      context,
      NyanOverlayTone.success,
    );
    final isEmbedded = variant == NyanDialogOptionVariant.embedded;
    final backgroundColor = value
        ? NyanOverlayStyle.recessedSurface(
            context,
            seed: NyanOverlayStyle.mutedBrandOlive(context),
            strength: 0.016,
          )
        : NyanOverlayStyle.recessedSurface(context, strength: 0.0);
    final borderColor = value
        ? NyanOverlayStyle.divider(context, alpha: 0.24)
        : NyanOverlayStyle.divider(context, alpha: 0.18);
    final titleColor = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.87);
    final secondaryColor = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.66);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(NyanRadius.input),
        child: AnimatedContainer(
          duration: NyanOverlayStyle.overlayTransitionDuration,
          curve: NyanOverlayStyle.overlayCurve,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(NyanOverlayStyle.optionRowRadius),
            border: Border.all(color: borderColor, width: isEmbedded ? 0.7 : 0.8),
          ),
          padding: const EdgeInsets.fromLTRB(
            NyanSpacing.space16,
            14,
            NyanSpacing.space12,
            14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: NyanSpacing.space4),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.26,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: NyanSpacing.space16),
              _buildControl(context, controlPalette, value),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControl(
    BuildContext context,
    NyanOverlayTonePalette palette,
    bool value,
  ) {
    switch (control) {
      case NyanDialogOptionControl.switchControl:
        return Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: palette.foreground,
          activeTrackColor: palette.softFill,
        );
      case NyanDialogOptionControl.checkbox:
        final theme = Theme.of(context);
        final idleBorder = NyanOverlayStyle.divider(context, alpha: 0.4);

        return IgnorePointer(
          child: AnimatedContainer(
            duration: NyanOverlayStyle.overlayTransitionDuration,
            curve: NyanOverlayStyle.overlayCurve,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value
                  ? palette.softFill
                  : theme.colorScheme.surface.withValues(alpha: 0.54),
              borderRadius: BorderRadius.circular(NyanOverlayStyle.checkboxRadius),
              border: Border.all(
                color: value
                    ? palette.border.withValues(alpha: 0.74)
                    : idleBorder,
                width: 0.95,
              ),
            ),
            child: value
                ? Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: palette.foreground,
                  )
                : null,
          ),
        );
    }
  }
}