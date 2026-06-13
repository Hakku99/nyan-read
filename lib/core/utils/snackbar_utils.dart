import 'package:flutter/material.dart';

import '../theme/nyan_spacing.dart';
import '../ui/components/components.dart';
import '../ui/nyan_app_keys.dart';

enum NyanSnackTone { info, success, error, skipped, loading }

class SnackBarUtils {
  static OverlayEntry? _currentEntry;
  // Kept alive for the full lifetime of the visible toast; nulled in onClosed.
  static NyanToastController? _activeController;

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

  /// Triggers the exit animation on the active toast, if any.
  static void dismiss() {
    _activeController?.triggerDismiss();
  }

  static void show(
    BuildContext context,
    String message, {
    String? description,
    VoidCallback? onAction,
    String? actionLabel,
    VoidCallback? onActionTap,
    NyanSnackTone tone = NyanSnackTone.info,
    int maxLines = 2,
  }) {
    final NyanResponseStatus status;
    final Duration duration;

    switch (tone) {
      case NyanSnackTone.success:
        status = NyanResponseStatus.success;
        duration = const Duration(milliseconds: 4000);
        break;
      case NyanSnackTone.error:
        status = NyanResponseStatus.error;
        duration = const Duration(milliseconds: 6000);
        break;
      case NyanSnackTone.skipped:
        status = NyanResponseStatus.skipped;
        duration = const Duration(milliseconds: 3500);
        break;
      case NyanSnackTone.loading:
        status = NyanResponseStatus.loading;
        // Long sentinel: replaced by the result toast when the operation ends.
        duration = const Duration(minutes: 5);
        break;
      case NyanSnackTone.info:
        status = NyanResponseStatus.info;
        duration = const Duration(milliseconds: 4000);
        break;
    }

    final clippedLines = maxLines < 1 ? 1 : (maxLines > 2 ? 2 : maxLines);

    // If a toast is already visible, swap its content in-place so the card
    // container does not flash through an exit+entrance cycle.
    if (_activeController != null) {
      _activeController!.replace(
        status: status,
        title: message,
        description: description,
        duration: duration,
        maxLines: clippedLines,
        actionLabel: actionLabel,
        onActionTap: onActionTap,
      );
      return;
    }

    // GoRouter's navigator owns the visible overlay.
    final navState = nyanRootNavigatorKey.currentState;
    final navCtx = nyanRootNavigatorKey.currentContext;
    OverlayState? overlay = navState?.overlay;
    MediaQueryData? mediaQuery =
        navCtx != null ? MediaQuery.maybeOf(navCtx) : null;
    overlay ??= _resolveOverlay(context);
    mediaQuery ??= MediaQuery.maybeOf(context);

    if (overlay != null && mediaQuery != null) {
      // SafeArea in NyanResponseOverlay already accounts for system insets;
      // we only add the spec's floating inset (--inset = 12pt).
      const resolvedBottomOffset = NyanSpacing.space12;

      final controller = NyanToastController(
        status: status,
        title: message,
        description: description,
        duration: duration,
        maxLines: clippedLines,
        actionLabel: actionLabel,
        onActionTap: onActionTap,
      );
      _activeController = controller;

      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (overlayContext) => TickerMode(
          enabled: true,
          child: NyanResponseOverlay(
            controller: controller,
            bottomOffset: resolvedBottomOffset,
            onClosed: () {
              controller.dispose();
              if (_activeController == controller) _activeController = null;
              if (_currentEntry == entry) _currentEntry = null;
              if (entry.mounted) entry.remove();
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
