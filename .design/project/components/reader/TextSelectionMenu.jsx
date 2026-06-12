/* ============================================================================
   Nyan Read — TextSelectionMenu
   Compiled into the DS bundle; consume as window.<Namespace>.TextSelectionMenu.
   Props contract: ./TextSelectionMenu.d.ts
   ============================================================================ */

import { Icon } from "../primitives/Icon.jsx";
import { HighlightSwatchRow } from "./HighlightSwatchRow.jsx";

/* ── Text selection menu (U5) ─────────────────────────────────────────────────
   The floating action bar that appears over a text selection: labelled action
   buttons (Copy / Search / …), a hairline divider, then the highlight pen row.
   A One Paper card — --nyan-surface, chrome-edge hairline, light-card lift — NOT
   Material elevation+grey. Caller positions it; this renders the bar only. */
const TextSelectionMenu = ({ actions, onAction, selectedPen, onSelectPen, pens, style }) => {
  const acts = actions || [
    { key: "copy", icon: "content_copy", label: "Copy" },
    { key: "search", icon: "search", label: "Search" },
  ];
  return (
    <div style={{
      display: "inline-flex", alignItems: "center",
      background: "var(--nyan-surface)", borderRadius: "var(--r-card)",
      border: "1px solid var(--chrome-edge)", boxShadow: "var(--shadow-light-card)",
      padding: "6px 8px", gap: 4, ...style,
    }}>
      {acts.map((a) => (
        <button
          key={a.key}
          onClick={() => onAction && onAction(a.key)}
          aria-label={a.label}
          style={{ all: "unset", cursor: "pointer", display: "flex", flexDirection: "column", alignItems: "center", gap: 3, padding: "6px 10px", borderRadius: "var(--r-chip)" }}
        >
          <Icon name={a.icon} size={18} color="var(--nyan-primary)" />
          <span style={{ font: "400 10px/1 var(--font-ui)", color: "var(--nyan-text-muted)" }}>{a.label}</span>
        </button>
      ))}
      <div style={{ width: "0.72px", height: 32, background: "color-mix(in srgb, var(--nyan-divider) 60%, transparent)", flexShrink: 0, margin: "0 2px" }} />
      <HighlightSwatchRow pens={pens} selected={selectedPen} onSelect={onSelectPen} size={22} />
    </div>
  );
};

export { TextSelectionMenu };
