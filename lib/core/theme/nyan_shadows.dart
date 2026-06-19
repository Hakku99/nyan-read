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

  /// Selection state glow — applied to grid/list covers when a card is selected
  /// in multi-select mode.
  ///
  /// Source: `screens/bundle3.jsx` `SelectBookCard`:
  ///   `0 0 0 3px color-mix(in srgb, var(--nyan-primary) 16%, transparent)`
  static List<BoxShadow> cardSelectionGlow(NyanTheme nyan) => [
        BoxShadow(
          color: nyan.primary.withValues(alpha: 0.16),
          spreadRadius: 3,
          blurRadius: 0,
        ),
      ];

  /// Selection badge glow — applied to the filled (selected) state of the
  /// circular selection badge overlaid on book covers.
  ///
  /// Source: `screens/bundle3.jsx` `SelectCheck`:
  ///   `0 1px 4px color-mix(in srgb, var(--nyan-select-fill) 40%, transparent)`
  static List<BoxShadow> selectionBadgeGlow(NyanTheme nyan) => [
        BoxShadow(
          color: nyan.primary.withValues(alpha: 0.40),
          offset: const Offset(0, 1),
          blurRadius: 4,
        ),
      ];

  /// Pinned shelf tab-strip sticky shadow — shown only when the header overlaps
  /// scrolling content (`overlapsContent == true` in the sliver delegate).
  ///
  /// Source: `screens/bundle4.jsx` ShelfToolbarScreen tab wrapper:
  ///   `box-shadow: 0 6px 14px -8px rgba(40,36,30,.22)`
  ///
  static List<BoxShadow> shelfPinnedHeader(NyanTheme nyan) {
    if (nyan.brightness == Brightness.dark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.32),
          blurRadius: 14,
          spreadRadius: -8,
          offset: const Offset(0, 6),
        ),
      ];
    }
    return [
      const BoxShadow(
        color: Color.fromRGBO(40, 36, 30, 0.22),
        blurRadius: 14,
        spreadRadius: -8,
        offset: Offset(0, 6),
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
