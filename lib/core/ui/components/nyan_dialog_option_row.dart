import 'package:flutter/material.dart';

import '../../theme/nyan_colors.dart';
import '../../theme/nyan_spacing.dart';
import '../nyan_theme_context.dart';
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
    final olive = theme.colorScheme.primary;
    final tileColor = value
        ? context.selectionSurface
        : NyanColors.overlayRecessedSurface;
    final borderColor = value
        ? theme.colorScheme.primary
        : NyanColors.overlayOptionBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(NyanOverlayStyle.optionRowRadius),
        child: AnimatedContainer(
          duration: NyanOverlayStyle.overlayTransitionDuration,
          curve: NyanOverlayStyle.overlayCurve,
          constraints: const BoxConstraints(
            minHeight: NyanOverlayStyle.optionTileMinHeight,
          ),
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(NyanOverlayStyle.optionRowRadius),
            border: Border.all(color: borderColor, width: 1),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: NyanOverlayStyle.optionTileHorizontalPadding,
            vertical: NyanOverlayStyle.optionTileVerticalPadding,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: context.nyanTheme.textPrimary.withValues(alpha: 0.92),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12.8,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                          color: context.nyanTheme.textSecondary.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: NyanSpacing.space16),
              _buildControl(context, value),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControl(BuildContext context, bool value) {
    switch (control) {
      case NyanDialogOptionControl.switchControl:
        final palette = NyanOverlayStyle.tonePalette(context, NyanOverlayTone.success);
        return Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: palette.foreground,
          activeTrackColor: palette.softFill,
        );
      case NyanDialogOptionControl.checkbox:
        final olive = Theme.of(context).colorScheme.primary;
        final checkedFill = Color.alphaBlend(
          olive.withValues(alpha: 0.09),
          NyanOverlayStyle.creamSurface(context),
        );

        return IgnorePointer(
          child: AnimatedContainer(
            duration: NyanOverlayStyle.overlayTransitionDuration,
            curve: NyanOverlayStyle.overlayCurve,
            width: NyanOverlayStyle.checkboxSize,
            height: NyanOverlayStyle.checkboxSize,
            decoration: BoxDecoration(
              color: value ? checkedFill : Colors.transparent,
              borderRadius: BorderRadius.circular(NyanOverlayStyle.checkboxRadius),
              border: Border.all(
                color: value
                    ? olive.withValues(alpha: 0.94)
                    : NyanOverlayStyle.divider(context, alpha: 0.34),
                width: 1.5,
              ),
            ),
            child: value
                ? Icon(
                    Icons.done_rounded,
                    size: 16,
                    color: olive,
                  )
                : null,
          ),
        );
    }
  }
}
