import 'package:flutter/material.dart';

import '../theme/nyan_spacing.dart';
import '../ui/components/components.dart';

enum NyanSnackTone { info, success, error }

class SnackBarUtils {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context,
    String message, {
    VoidCallback? onAction,
    NyanSnackTone tone = NyanSnackTone.info,
    double bottomOffset = 28,
    int maxLines = 2,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    final mediaQuery = MediaQuery.of(context);
    final IconData icon;
    final NyanFloatingNoticeTone noticeTone;
    final Duration duration;

    switch (tone) {
      case NyanSnackTone.success:
        icon = Icons.check_rounded;
        noticeTone = NyanFloatingNoticeTone.success;
        duration = const Duration(milliseconds: 1900);
        break;
      case NyanSnackTone.error:
        icon = Icons.error_outline_rounded;
        noticeTone = NyanFloatingNoticeTone.error;
        duration = const Duration(milliseconds: 2600);
        break;
      case NyanSnackTone.info:
        icon = Icons.info_rounded;
        noticeTone = NyanFloatingNoticeTone.info;
        duration = const Duration(milliseconds: 1900);
        break;
    }

    _currentEntry?.remove();
    _currentEntry = null;

    final resolvedBottomOffset =
        mediaQuery.padding.bottom + bottomOffset + NyanSpacing.minTapTarget + 6;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => NyanFloatingNoticeOverlay(
        message: message,
        icon: icon,
        tone: noticeTone,
        maxLines: maxLines < 1 ? 1 : (maxLines > 2 ? 2 : maxLines),
        bottomOffset: resolvedBottomOffset,
        duration: duration,
        onClosed: () {
          if (_currentEntry == entry) {
            _currentEntry = null;
          }
          if (entry.mounted) {
            entry.remove();
          }
          onAction?.call();
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}