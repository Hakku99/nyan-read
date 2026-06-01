import 'package:flutter/material.dart';

import 'theme_presets.dart';

/// Elevation shadows for Nyan chrome. **Theme-aware** (design handoff 2026-06):
///
/// - **Cream Light** — soft warm-ink drop shadows, ≤12px blur, ≤5% alpha.
/// - **Sumi Dark — v3 elevation ladder.** Depth is carried by tone + a luminous
///   `0.75px` hairline ring (drawn as a non-blurred [BoxShadow] spread, the
///   equivalent of the CSS `0 0 0 0.75px` outline) plus a gentle black ambient.
///   The ring is what makes an elevated surface read as a distinct plane against
///   the deep page. The old *"no shadow in dark"* rule is **retired**.
///
/// Each recipe takes the active [NyanTheme] so it can pick the right ladder per
/// [NyanTheme.brightness] and source the ring color from [NyanTheme.divider].
/// Light recipes use [NyanTheme.textPrimary] as the warm-ink shadow color.
///
/// NOTE — catch-light: the CSS spec also folds an `inset 0 1px 0 white@5%` top
/// catch-light into the dark tokens. Flutter's [BoxShadow] has no inset mode, so
/// that 1px inner highlight is **not** carried here; raised surfaces that want it
/// apply a top [BorderSide] at ~5% white in their own decoration (see B4). The
/// ring — the load-bearing plane-separation cue — is fully represented.
class NyanShadows {
  const NyanShadows._();

  /// Luminous hairline ring used across the dark ladder: a non-blurred spread,
  /// the [BoxShadow] equivalent of CSS `0 0 0 <spread>px`.
  static BoxShadow _ring(Color color, double alpha) => BoxShadow(
        color: color.withValues(alpha: alpha),
        blurRadius: 0,
        spreadRadius: 0.75,
      );

  /// Standard floating-chrome lift: cards, top bar, sheets, dialogs, popovers.
  static List<BoxShadow> lightCard(NyanTheme nyan) {
    if (nyan.brightness == Brightness.dark) {
      return [
        _ring(nyan.divider, 0.88),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.44),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.34),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ];
    }
    final ink = nyan.textPrimary;
    return [
      BoxShadow(
        color: ink.withValues(alpha: 0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: ink.withValues(alpha: 0.02),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Secondary overlays (toasts, light floating notices).
  static List<BoxShadow> subtle(NyanTheme nyan) {
    if (nyan.brightness == Brightness.dark) {
      return [
        _ring(nyan.divider, 0.66),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.34),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];
    }
    return [
      BoxShadow(
        color: nyan.textPrimary.withValues(alpha: 0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Settings grouped cards — ultra-soft lift (was inlined as `_SettingsCard`).
  static List<BoxShadow> settingsGrouped(NyanTheme nyan) {
    if (nyan.brightness == Brightness.dark) {
      return [
        _ring(nyan.divider, 0.50),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.24),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return [
      BoxShadow(
        color: nyan.textPrimary.withValues(alpha: 0.014),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ];
  }
}
