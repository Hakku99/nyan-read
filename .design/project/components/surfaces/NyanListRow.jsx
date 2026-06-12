/* ============================================================================
   Nyan Read — NyanListRow
   Compiled into the DS bundle; consume as window.<Namespace>.NyanListRow.
   Props contract: ./NyanListRow.d.ts
   ============================================================================ */

import { Icon } from "../primitives/Icon.jsx";

/* ── List row (NyanListRow / settings row) ───────────────────────────────────
   The single settings/details row for the whole system. A tinted icon tile,
   title + optional subtitle, and a trailing slot. The chevron shows when the
   row is actionable: pass `onPress` (auto-chevron) or force it with `chevron`.
   `indent` drops the icon and insets the text — used for sub-rows nested under
   a parent setting. `danger` renders title + icon in error tones. */
const NyanListRow = ({ icon, title, subtitle, trailing, onPress, danger = false, indent = false, chevron = false }) => {
  const fg = danger ? "var(--error-secondary)" : "var(--nyan-text)";
  const accent = danger ? "var(--error-secondary)" : "var(--nyan-primary)";
  const showChevron = chevron || (onPress && trailing === undefined);
  return (
    <div
      onClick={onPress}
      style={{
        background: "var(--nyan-surface)",
        display: "flex",
        alignItems: "center",
        gap: 12,
        padding: indent ? "12px 16px 12px 52px" : "12px 16px",
        minHeight: 44,
        cursor: onPress ? "pointer" : "default",
      }}
    >
      {!indent && icon && (
        <div style={{
          width: 32, height: 32, borderRadius: "var(--r-chip)", flexShrink: 0,
          background: `color-mix(in srgb, ${accent} 9%, var(--nyan-surface-muted))`,
          display: "grid", placeItems: "center",
        }}>
          <Icon name={icon} size={16} color={accent} />
        </div>
      )}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ font: "500 15px/1.2 var(--font-ui)", color: fg }}>{title}</div>
        {subtitle && <div style={{ font: "400 13px/1.3 var(--font-ui)", color: "var(--nyan-text-secondary)", marginTop: 2 }}>{subtitle}</div>}
      </div>
      {trailing}
      {showChevron && <Icon name="chevron_right" size={16} color="var(--nyan-text-muted)" style={{ flexShrink: 0 }} />}
    </div>
  );
};

export { NyanListRow };
