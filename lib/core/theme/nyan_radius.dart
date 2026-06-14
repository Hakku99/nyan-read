class NyanRadius {
  const NyanRadius._();

  // ── One Paper concentric family (from innermost to outermost) ────────────
  /// Option chips / pill buttons — nested deepest inside tracks/cards.
  static const double chip = 12;

  /// Segmented-control track + tinted list-row icon chip.
  /// Also aliased as [small] for back-compat — existing call sites need not change.
  static const double control = 14;

  /// Cards nested inside a sheet (concentric inner to [dock]/[sheet]).
  /// Also aliased as [input] for back-compat.
  static const double cardNested = 16;

  /// Cards at top-level: bookshelf items, stand-alone panels.
  static const double card = 20;

  /// Resting dock / floating bars.
  /// Also aliased as [panel] for back-compat.
  static const double dock = 24;

  /// Dock grown into a sheet; all bottom sheets + dialogs (full-size).
  static const double sheet = 28;

  // ── Legacy aliases (preserved for existing callers) ─────────────────────
  /// Alias for [control] (14). Prefer [control] in new code.
  static const double small = control;

  /// Alias for [cardNested] (16). Prefer [cardNested] in new code.
  static const double input = cardNested;

  /// Alias for [dock] (24). Prefer [dock] in new code.
  static const double panel = dock;
}
