/* ============================================================================
   Nyan Read — Headers
   ----------------------------------------------------------------------------
   Page header (title + subtitle + actions) and the olive section caption.
   Part of the split component library. Exports go to window so other Babel
   <script> blocks (galleries, screens, the live prototype) can use them.
   ============================================================================ */

const { useState, useEffect, useRef, useCallback, useMemo } = React;

/* ── Section header (olive caption + optional dot) ───────────────────────── */
const NyanSectionHeader = ({ title, withDot = false, style }) => (
  <div style={{ padding: "0 16px 12px", display: "flex", alignItems: "center", gap: 8, ...style }}>
    {withDot && (
      <div style={{ width: 4, height: 4, borderRadius: "50%", background: "color-mix(in srgb, var(--nyan-primary) 63%, transparent)" }} />
    )}
    <div className="nyan-section-header" style={{ textTransform: "uppercase" }}>{title}</div>
  </div>
);


/* ── Page header ─────────────────────────────────────────────────────────── */
const NyanPageHeader = ({ title, subtitle, leading, actions, style }) => (
  <div style={{ padding: "16px 16px 12px", display: "flex", alignItems: "flex-start", gap: 12, ...style }}>
    {leading}
    <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0 }}>
      <div className="nyan-title" style={{ letterSpacing: "-0.15px" }}>{title}</div>
      {subtitle && (
        <div className="nyan-meta" style={{ marginTop: 4, color: "var(--nyan-text-muted)", lineHeight: 1.35 }}>{subtitle}</div>
      )}
    </div>
    {actions && <div style={{ display: "flex", gap: 4 }}>{actions}</div>}
  </div>
);


/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, { NyanSectionHeader, NyanPageHeader });
