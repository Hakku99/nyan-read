/* ============================================================================
   Nyan Read — NyanPageHeader
   Compiled into the DS bundle; consume as window.<Namespace>.NyanPageHeader.
   Props contract: ./NyanPageHeader.d.ts
   ============================================================================ */

import { Icon } from "../primitives/Icon.jsx";

/* ── Page header ─────────────────────────────────────────────────────────────
   Title + optional subtitle, a leading slot, and a trailing actions row.
   `back` is a convenience that renders the standard 40px arrow-left button in
   the leading slot (ignored when an explicit `leading` node is passed). */
const NyanPageHeader = ({ title, subtitle, leading, actions, back = false, onBack, style }) => {
  const lead = leading || (back ? (
    <button onClick={onBack} aria-label="Back" style={{ all: "unset", cursor: "pointer", width: 40, height: 40, borderRadius: "var(--r-control)", display: "grid", placeItems: "center", flexShrink: 0 }}>
      <Icon name="arrow_back" size={21} color="var(--nyan-text)" />
    </button>
  ) : null);
  return (
    <div style={{ padding: "16px 16px 12px", display: "flex", alignItems: subtitle ? "flex-start" : "center", gap: 12, ...style }}>
      {lead}
      <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0 }}>
        <div className="nyan-title" style={{ letterSpacing: "-0.15px" }}>{title}</div>
        {subtitle && (
          <div className="nyan-meta" style={{ marginTop: 4, color: "var(--nyan-text-muted)", lineHeight: 1.35 }}>{subtitle}</div>
        )}
      </div>
      {actions && <div style={{ display: "flex", gap: 4 }}>{actions}</div>}
    </div>
  );
};

export { NyanPageHeader };
