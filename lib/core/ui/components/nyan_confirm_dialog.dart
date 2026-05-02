import 'package:flutter/material.dart';

import '../../theme/nyan_colors.dart';
import '../../theme/nyan_spacing.dart';
import '../nyan_theme_context.dart';
import 'nyan_overlay_style.dart';

enum NyanConfirmTone { neutral, warning, danger }

Future<bool?> showNyanConfirmDialog(
  BuildContext context, {
  required String title,
  String? description,
  required String confirmLabel,
  required String cancelLabel,
  Widget? extraContent,
  NyanConfirmTone tone = NyanConfirmTone.neutral,
  IconData? icon,
  bool barrierDismissible = true,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: NyanOverlayStyle.modalBarrierColor(context),
    builder: (dialogContext) => TweenAnimationBuilder<double>(
      duration: NyanOverlayStyle.overlayTransitionDuration,
      curve: NyanOverlayStyle.overlayCurve,
      tween: Tween(begin: 0, end: 1),
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
      child: NyanConfirmDialog(
        title: title,
        description: description,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        extraContent: extraContent,
        tone: tone,
        icon: icon,
      ),
    ),
  );
}

class NyanConfirmDialog extends StatelessWidget {
  const NyanConfirmDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.cancelLabel,
    this.description,
    this.extraContent,
    this.tone = NyanConfirmTone.neutral,
    this.icon,
  });

  final String title;
  final String? description;
  final String confirmLabel;
  final String cancelLabel;
  final Widget? extraContent;
  final NyanConfirmTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryText = context.nyanTheme.textPrimary.withValues(alpha: 0.94);
    final secondaryText =
        context.nyanTheme.textSecondary.withValues(alpha: 0.82);
    final resolvedIcon = icon ??
        switch (tone) {
          NyanConfirmTone.neutral => Icons.info_outline_rounded,
          NyanConfirmTone.warning => Icons.warning_amber_rounded,
          NyanConfirmTone.danger => Icons.delete_outline_rounded,
        };
    final normalizedTitle = _normalizedTitle(title, tone);
    final cancelSurface = Color.alphaBlend(
      context.nyanTheme.textSecondary.withValues(alpha: 0.02),
      NyanOverlayStyle.creamSurface(context),
    );
    const removeFill = NyanColors.confirmOliveFill;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: NyanOverlayStyle.dialogHorizontalInset,
      ),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: NyanOverlayStyle.dialogMaxWidth),
        child: NyanOverlayPanel(
          radius: NyanOverlayStyle.dialogRadius,
          padding: const EdgeInsets.all(NyanOverlayStyle.dialogPadding),
          borderColor: NyanOverlayStyle.divider(context, alpha: 0.16),
          shadows: NyanOverlayStyle.dialogShadow(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _DialogBadge(
                    icon: resolvedIcon,
                    iconColor: NyanColors.confirmBadgeIcon,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.2),
                    borderColor: NyanColors.confirmBadgeBorder,
                  ),
                  const SizedBox(width: NyanSpacing.space12),
                  Expanded(
                    child: Text(
                      normalizedTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 18.5,
                        fontWeight: FontWeight.w700,
                        height: 1.18,
                        color: primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              if (description != null) ...[
                const SizedBox(height: 18),
                Text(
                  description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                    color: secondaryText,
                  ),
                ),
              ],
              if (extraContent != null) ...[
                const SizedBox(height: 18),
                extraContent!,
              ],
              const SizedBox(height: NyanOverlayStyle.dialogActionGap),
              Row(
                children: [
                  Expanded(
                    child: _DialogActionButton(
                      label: cancelLabel,
                      onTap: () => Navigator.of(context).pop(false),
                      backgroundColor: cancelSurface,
                      borderColor: NyanColors.overlayOptionBorder,
                      foregroundColor: primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: NyanSpacing.space12),
                  Expanded(
                    child: _DialogActionButton(
                      label: confirmLabel,
                      onTap: () => Navigator.of(context).pop(true),
                      backgroundColor: removeFill,
                      borderColor: removeFill,
                      foregroundColor: Colors.white.withValues(alpha: 0.96),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _normalizedTitle(String rawTitle, NyanConfirmTone tone) {
    if (tone != NyanConfirmTone.danger) {
      return rawTitle.trim();
    }

    const warningEmoji = '\u26A0\uFE0F';
    const warningGlyph = '\u26A0';
    final normalized = rawTitle.trimLeft();
    if (normalized.startsWith(warningEmoji)) {
      return normalized.substring(warningEmoji.length).trimLeft();
    }
    if (normalized.startsWith(warningGlyph)) {
      return normalized.substring(warningGlyph.length).trimLeft();
    }
    return normalized;
  }
}

class _DialogBadge extends StatelessWidget {
  const _DialogBadge({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: SizedBox(
        width: NyanOverlayStyle.dialogBadgeSize,
        height: NyanOverlayStyle.dialogBadgeSize,
        child: Icon(
          icon,
          size: 14,
          color: iconColor,
        ),
      ),
    );
  }
}

class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
    required this.fontWeight,
  });

  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NyanOverlayStyle.buttonRadius),
        child: Ink(
          height: NyanOverlayStyle.buttonHeight,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(NyanOverlayStyle.buttonRadius),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                fontWeight: fontWeight,
                color: foregroundColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
