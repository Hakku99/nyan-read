import 'package:flutter/material.dart';

import '../theme/nyan_spacing.dart';

/// Presents a [NyanOnePaperSheet] (or any widget) as a floating modal panel
/// with the "One Paper" inset configuration:
///
///   • Warm-ink scrim (`rgba(40,36,30,0.34)` = CSS `--scrim`) covers the full
///     screen behind the panel.
///   • 12pt inset on left, right, and bottom (`--inset` token) so the panel
///     floats inside the screen edges, never touching them.
///   • Bottom inset accounts for the device safe area so the sheet clears the
///     home indicator.
///   • Slide-up / fade entry using `--ease-paper` curve and `--dur-chrome`
///     duration, matching the reader dock animation tokens.
///
/// Uses [showGeneralDialog] instead of [showModalBottomSheet] so that Flutter's
/// bottom-sheet infrastructure (which forces full-screen width and clips with a
/// top-only rounded shape) cannot override the floating inset layout.
///
/// ```dart
/// showNyanSheet(
///   context: context,
///   builder: (_) => NyanOnePaperSheet(child: …),
/// );
/// ```
Future<T?> showNyanSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    // barrierLabel is required by accessibility when barrierDismissible=true.
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    // --scrim: rgba(40, 36, 30, 0.34) — warm-ink dim, not clinical black.
    barrierColor: const Color(0x57282420),
    // --dur-chrome: 280ms entry; exit mirrors entry via reverse animation.
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      final safeBottom = MediaQuery.of(ctx).viewPadding.bottom;
      return Align(
        // Anchor to the bottom of the screen; Padding then lifts it 12pt + safe area.
        alignment: Alignment.bottomCenter,
        child: Padding(
          // --inset: 12pt from left, right, bottom; safe area added on bottom.
          padding: EdgeInsets.fromLTRB(
            NyanSpacing.space12,
            0,
            NyanSpacing.space12,
            NyanSpacing.space12 + safeBottom,
          ),
          child: Material(
            // Transparent so NyanOnePaperSheet owns its own surface + shadow.
            type: MaterialType.transparency,
            child: builder(ctx),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      // Slide up from 100% below + simultaneous fade.
      // --ease-paper: cubic-bezier(0.33, 0.9, 0.36, 1) — paper-soft motion.
      final curved = CurvedAnimation(
        parent: animation,
        curve: const Cubic(0.33, 0.9, 0.36, 1.0),
        reverseCurve: Curves.easeIn,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
