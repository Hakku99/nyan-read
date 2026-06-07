import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_shadows.dart';
import '../../theme/nyan_spacing.dart';
import '../nyan_theme_context.dart';

/// The "One Paper" static floating panel shell — the visual container shared
/// by all non-reader modal sheets (import, sort, action sheets, etc.).
///
/// Provides:
///   • All-4-corner `NyanRadius.sheet` (28pt) rounded rectangle
///   • Chrome-edge border: transparent in Cream, `divider` ring in Sumi Dark
///   • `NyanShadows.lightCard` lift (dark mode: ambient + glow ring)
///   • `surface` / `surfaceRaised` background (light / dark ladder)
///   • Matcha grabber pill — `primary @ 36%` light / `50%` dark
///
/// **Usage with [showNyanSheet]** (the canonical entry point):
/// ```dart
/// showNyanSheet(context: context, builder: (_) => NyanOnePaperSheet(child: …));
/// ```
///
/// The [child] is rendered below the grabber with no built-in padding —
/// callers supply their own via [Padding] so each sheet can tune its insets.
///
/// Source: `components/reader.jsx` `OnePaperDock` decoration block;
///         `screens/bundle3.jsx` `ImportSheet` floating-sheet div.
class NyanOnePaperSheet extends StatelessWidget {
  const NyanOnePaperSheet({
    super.key,
    required this.child,
    this.onGrabberTap,
  });

  /// Content below the grabber. Must include its own padding.
  final Widget child;

  /// Optional collapse/dismiss callback wired to the grabber.
  final VoidCallback? onGrabberTap;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final isDark = nyan.brightness == Brightness.dark;

    // --grabber: primary @ 36% light / 50% dark (colors_and_type.css)
    final grabberColor =
        nyan.primary.withValues(alpha: isDark ? 0.50 : 0.36);
    // --chrome-edge: invisible in light, divider ring in Sumi Dark v3 ladder.
    final chromeEdge = isDark ? nyan.divider : Colors.transparent;
    // Surface: use the topmost elevation tier in dark (surfaceRaised = #2E342B).
    final surface = isDark ? nyan.surfaceRaised : nyan.surface;

    final borderRadius = BorderRadius.circular(NyanRadius.sheet);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: NyanShadows.lightCard(nyan),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: ColoredBox(
          color: surface,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: chromeEdge, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Grabber — 10pt top margin, 5pt pill, 2pt bottom breathing room.
                // paddingTop: 10 matches the reader.jsx OnePaperDock spec exactly.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onGrabberTap,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.only(
                        top: 10,
                        bottom: 2,
                      ),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: grabberColor,
                        borderRadius: BorderRadius.circular(
                          NyanSpacing.space4 / 2,
                        ),
                      ),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
