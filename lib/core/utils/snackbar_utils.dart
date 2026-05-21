import 'package:flutter/material.dart';

import '../theme/nyan_spacing.dart';
import '../ui/components/components.dart';
import '../ui/nyan_app_keys.dart';
import '../ui/nyan_icons.dart';

enum NyanSnackTone { info, success, error }

class SnackBarUtils {
  static OverlayEntry? _currentEntry;

  /// Prefer nearest Overlay ([Navigator.overlay]); avoid relying solely on
  /// root overlay lookups — those often resolve null under GoRouter shells,
  /// which silently swallowed notices before.
  static OverlayState? _resolveOverlay(BuildContext context) {
    OverlayState? fromNavigator(bool rootNavigator) {
      final nav = Navigator.maybeOf(context, rootNavigator: rootNavigator);
      return nav?.overlay;
    }

    return Overlay.maybeOf(context, rootOverlay: true) ??
        Overlay.maybeOf(context) ??
        fromNavigator(true) ??
        fromNavigator(false);
  }

  static void show(
    BuildContext context,
    String message, {
    VoidCallback? onAction,
    NyanSnackTone tone = NyanSnackTone.info,
    double bottomOffset = 40,
    int maxLines = 2,
  }) {
    final IconData icon;
    final NyanFloatingNoticeTone noticeTone;
    final Duration duration;

    switch (tone) {
      case NyanSnackTone.success:
        icon = NyanIcons.check;
        noticeTone = NyanFloatingNoticeTone.success;
        duration = const Duration(milliseconds: 1900);
        break;
      case NyanSnackTone.error:
        icon = NyanIcons.error;
        noticeTone = NyanFloatingNoticeTone.error;
        duration = const Duration(milliseconds: 2600);
        break;
      case NyanSnackTone.info:
        icon = NyanIcons.info;
        noticeTone = NyanFloatingNoticeTone.info;
        duration = const Duration(milliseconds: 1900);
        break;
    }

    final clippedLines = maxLines < 1 ? 1 : (maxLines > 2 ? 2 : maxLines);

    // GoRouter's navigator owns the visible overlay.
    final navState = nyanRootNavigatorKey.currentState;
    final navCtx = nyanRootNavigatorKey.currentContext;
    OverlayState? overlay = navState?.overlay;
    MediaQueryData? mediaQuery =
        navCtx != null ? MediaQuery.maybeOf(navCtx) : null;
    overlay ??= _resolveOverlay(context);
    mediaQuery ??= MediaQuery.maybeOf(context);

    if (overlay != null && mediaQuery != null) {
      _currentEntry?.remove();
      _currentEntry = null;

      final resolvedBottomOffset =
          mediaQuery.padding.bottom + bottomOffset + NyanSpacing.minTapTarget + 6;

      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (overlayContext) => TickerMode(
          enabled: true,
          child: NyanFloatingNoticeOverlay(
            message: message,
            icon: icon,
            tone: noticeTone,
            maxLines: clippedLines,
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
        ),
      );

      _currentEntry = entry;
      overlay.insert(entry);
      return;
    }

    final messenger = nyanScaffoldMessengerKey.currentState ??
        ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message, maxLines: clippedLines),
          duration: duration,
          behavior: SnackBarBehavior.floating,
        ),
      );
      onAction?.call();
      return;
    }

    debugPrint(
      'SnackBarUtils.show: no Overlay/MediaQuery or ScaffoldMessenger for '
      '"${message.replaceAll(RegExp(r'\s+'), ' ')}"',
    );
  }
}
