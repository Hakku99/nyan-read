import 'package:flutter/material.dart';

import '../theme/nyan_radius.dart';
import '../theme/nyan_spacing.dart';

enum NyanSnackTone { info, success, error }

class SnackBarUtils {
  static void show(
    BuildContext context,
    String message, {
    VoidCallback? onAction,
    NyanSnackTone tone = NyanSnackTone.info,
  }) {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = theme.colorScheme;

    final Color accentColor;
    final Color borderColor;
    final IconData icon;

    switch (tone) {
      case NyanSnackTone.success:
        accentColor = colorScheme.primary;
        borderColor = colorScheme.primary.withValues(alpha: 0.34);
        icon = Icons.check_circle_rounded;
        break;
      case NyanSnackTone.error:
        accentColor = colorScheme.error;
        borderColor = colorScheme.error.withValues(alpha: 0.22);
        icon = Icons.error_outline_rounded;
        break;
      case NyanSnackTone.info:
        accentColor = theme.textTheme.bodySmall?.color ?? colorScheme.outline;
        borderColor = theme.dividerColor.withValues(alpha: 0.42);
        icon = Icons.info_outline_rounded;
        break;
    }

    final foregroundColor =
        theme.textTheme.bodyLarge?.color ?? colorScheme.onSurface;
    final secondaryColor =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.76) ??
            foregroundColor.withValues(alpha: 0.68);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        dismissDirection: DismissDirection.horizontal,
        margin: const EdgeInsets.fromLTRB(
          NyanSpacing.space16,
          0,
          NyanSpacing.space16,
          92,
        ),
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        content: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(NyanRadius.card),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NyanSpacing.space16,
              vertical: NyanSpacing.space12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(NyanRadius.small),
                  ),
                  child: Icon(
                    icon,
                    size: NyanSpacing.space16,
                    color: accentColor.withValues(
                      alpha: tone == NyanSnackTone.info ? 0.72 : 1,
                    ),
                  ),
                ),
                const SizedBox(width: NyanSpacing.space8),
                Expanded(
                  child: Text(
                    message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w500,
                      height: 1.36,
                    ),
                  ),
                ),
                const SizedBox(width: NyanSpacing.space4),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: secondaryColor,
                    size: 18,
                  ),
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    onAction?.call();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: NyanSpacing.minTapTarget,
                    minHeight: NyanSpacing.minTapTarget,
                  ),
                  splashRadius: NyanSpacing.space20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



