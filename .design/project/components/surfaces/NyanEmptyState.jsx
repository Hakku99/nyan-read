/* ============================================================================
   Nyan Read — NyanEmptyState
   Compiled into the DS bundle; consume as window.<Namespace>.NyanEmptyState.
   Props contract: ./NyanEmptyState.d.ts
   ============================================================================ */

import { Icon } from "../primitives/Icon.jsx";

/* ── Empty state (NyanEmptyState) ────────────────────────────────────────── */
const NyanEmptyState = ({ icon, title, description, action }) => (
  <div style={{ display: "flex", flexDirection: "column", alignItems: "center", textAlign: "center", padding: "32px 24px", gap: 16 }}>
    <div style={{ padding: 14, background: "color-mix(in srgb, var(--nyan-primary) 8%, transparent)", borderRadius: "var(--radius-card)" }}>
      {typeof icon === "string"
        ? <Icon name={icon} size={34} color="color-mix(in srgb, var(--nyan-primary) 80%, transparent)" />
        : icon}
    </div>
    <div style={{ display: "flex", flexDirection: "column", gap: 8, maxWidth: 320 }}>
      <div className="nyan-section">{title}</div>
      {description && <div style={{ font: "400 14px/1.5 var(--font-ui)", color: "var(--nyan-text-secondary)", whiteSpace: "pre-line" }}>{description}</div>}
    </div>
    {action && <div style={{ marginTop: 4 }}>{action}</div>}
  </div>
);

export { NyanEmptyState };
