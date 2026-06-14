/* ============================================================================
   Nyan Read — NyanInfoCard
   Compiled into the DS bundle; consume as window.<Namespace>.NyanInfoCard.
   Props contract: ./NyanInfoCard.d.ts
   ============================================================================ */

/* ── Info card (NyanInfoCard) ────────────────────────────────────────────── */
const NyanInfoCard = ({ children, variant = "standard", tone = "surface", padding = 16, onPress, style }) => {
  const isGrouped = variant === "grouped";
  const radius = isGrouped ? "var(--radius-input)" : "var(--radius-card)";
  const shadow = isGrouped ? "var(--shadow-grouped)" : "var(--shadow-light-card)";
  const bg = tone === "muted" ? "var(--nyan-surface-muted)"
           : tone === "raised" ? "var(--nyan-surface-raised, var(--nyan-surface))"
           : "var(--nyan-surface)";
  const borderAlpha = isGrouped ? 0.16 : 0.3;
  const borderWidth = isGrouped ? 0.72 : 0.5;
  return (
    <div
      onClick={onPress}
      style={{
        background: bg,
        borderRadius: radius,
        boxShadow: shadow,
        border: `${borderWidth}px solid color-mix(in srgb, var(--nyan-divider) ${borderAlpha * 100}%, transparent)`,
        padding,
        cursor: onPress ? "pointer" : "default",
        ...style,
      }}
    >
      {children}
    </div>
  );
};

export { NyanInfoCard };
