import 'package:flutter/material.dart';

import '../../theme/nyan_spacing.dart';
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
    builder: (dialogContext) => NyanConfirmDialog(
      title: title,
      description: description,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      extraContent: extraContent,
      tone: tone,
      icon: icon,
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
    final palette = NyanOverlayStyle.tonePalette(
      context,
      switch (tone) {
        NyanConfirmTone.neutral => NyanOverlayTone.info,
        NyanConfirmTone.warning => NyanOverlayTone.info,
        NyanConfirmTone.danger => NyanOverlayTone.danger,
      },
    );
    final resolvedIcon =
        icon ??
        switch (tone) {
          NyanConfirmTone.neutral => Icons.info_outline_rounded,
          NyanConfirmTone.warning => Icons.warning_amber_rounded,
          NyanConfirmTone.danger => Icons.delete_outline_rounded,
        };
    final normalizedTitle = _normalizedTitle(title, tone);
    final cancelForeground =
        theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.8) ??
        theme.colorScheme.onSurface.withValues(alpha: 0.8);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: NyanSpacing.space24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 388),
        child: NyanOverlayPanel(
          radius: NyanOverlayStyle.dialogRadius,
          padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
          borderColor: NyanOverlayStyle.divider(context, alpha: 0.28),
          shadows: NyanOverlayStyle.dialogShadow(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogBadge(icon: resolvedIcon, palette: palette),
              const SizedBox(height: NyanSpacing.space12),
              Text(
                normalizedTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.08,
                  color: theme.textTheme.titleLarge?.color?.withValues(alpha: 0.92),
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: NyanSpacing.space8),
                Text(
                  description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.34,
                    color: palette.secondary.withValues(alpha: 0.88),
                  ),
                ),
              ],
              if (extraContent != null) ...[
                const SizedBox(height: NyanSpacing.space24),
                extraContent!,
              ],
              const SizedBox(height: NyanSpacing.space20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        foregroundColor: cancelForeground,
                        backgroundColor: NyanOverlayStyle.recessedSurface(context),
                        side: BorderSide(
                          color: NyanOverlayStyle.divider(context, alpha: 0.36),
                          width: 0.75,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: NyanSpacing.space12,
                          vertical: NyanSpacing.space8,
                        ),
                        textStyle: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            NyanOverlayStyle.buttonRadius,
                          ),
                        ),
                      ),
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: NyanSpacing.space12),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        foregroundColor: NyanOverlayStyle.destructiveText(context),
                        backgroundColor: NyanOverlayStyle.destructiveSubtleBackground(
                          context,
                        ),
                        side: BorderSide(
                          color: NyanOverlayStyle.destructiveSubtleBorder(context),
                          width: 0.75,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: NyanSpacing.space12,
                          vertical: NyanSpacing.space8,
                        ),
                        textStyle: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            NyanOverlayStyle.buttonRadius,
                          ),
                        ),
                      ),
                      child: Text(confirmLabel),
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
  const _DialogBadge({required this.icon, required this.palette});

  final IconData icon;
  final NyanOverlayTonePalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.iconSurface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: palette.border.withValues(alpha: 0.3),
          width: 0.65,
        ),
      ),
      child: SizedBox(
        width: 30,
        height: 30,
        child: Icon(
          icon,
          size: 13,
          color: palette.foreground,
        ),
      ),
    );
  }
}