/* ============================================================================
   Nyan Read — NyanSectionHeader
   Compiled into the DS bundle; consume as window.<Namespace>.NyanSectionHeader.
   Props contract: ./NyanSectionHeader.d.ts
   ============================================================================ */

/* ── Section header (olive caption + optional dot) ───────────────────────── */
const NyanSectionHeader = ({ title, withDot = false, style }) => (
  <div style={{ padding: "0 16px 12px", display: "flex", alignItems: "center", gap: 8, ...style }}>
    {withDot && (
      <div style={{ width: 4, height: 4, borderRadius: "50%", background: "color-mix(in srgb, var(--nyan-primary) 63%, transparent)" }} />
    )}
    <div className="nyan-section-header" style={{ textTransform: "uppercase" }}>{title}</div>
  </div>
);

export { NyanSectionHeader };
