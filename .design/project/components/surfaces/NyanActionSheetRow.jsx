/* ============================================================================
   Nyan Read — NyanActionSheetRow
   Compiled into the DS bundle; consume as window.<Namespace>.NyanActionSheetRow.
   Props contract: ./NyanActionSheetRow.d.ts
   ============================================================================ */

import { Icon } from "../primitives/Icon.jsx";

/* ── Action-sheet row (NyanActionSheetRow) ───────────────────────────────── */
const NyanActionSheetRow = ({ icon, title, subtitle, onPress, showChevron = true }) => (
  <div onClick={onPress} style={{
    padding: "12px 16px", display: "flex", alignItems: "center", gap: 12,
    cursor: "pointer",
  }}>
    <div style={{
      width: 36, height: 36, borderRadius: "var(--radius-small)",
      background: "color-mix(in srgb, var(--nyan-primary) 9%, transparent)",
      display: "grid", placeItems: "center", flexShrink: 0,
    }}>
      <Icon name={icon} size={17} color="var(--nyan-primary)" />
    </div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ font: "600 16px/1.2 var(--font-ui)", color: "var(--nyan-text)" }}>{title}</div>
      <div className="nyan-meta" style={{ marginTop: 4 }}>{subtitle}</div>
    </div>
    {showChevron && <Icon name="chevron_right" size={18} color="color-mix(in srgb, var(--nyan-text-secondary) 44%, transparent)" />}
  </div>
);

export { NyanActionSheetRow };
