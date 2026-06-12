/* ============================================================================
   Nyan Read — SegmentedTabControl
   Compiled into the DS bundle; consume as window.<Namespace>.SegmentedTabControl.
   Props contract: ./SegmentedTabControl.d.ts
   ============================================================================ */

import { Icon } from "./Icon.jsx";

/* ── Segmented tab control (NyanSegmentedTabControl) ─────────────────────────
   ONE recessed-track style for the whole system — top-level views AND sort.
   The track is recessed by TONE (surface-muted), never a border; the selected
   segment is a floating paper chip (surface + grouped shadow) that slides.
   Selected text is always matcha-deep — the single raised voice.
   `style="subtle"` swaps the white chip for a matcha-tint chip (same family). */
const SegmentedTabControl = ({ tabs, selected, onChange, style = "emphasis" }) => {
  const subtle = style === "subtle";
  return (
    <div style={{
      height: 40,
      background: "var(--nyan-surface-muted)",
      borderRadius: "var(--r-control)",
      padding: 4,
      display: "grid",
      gridTemplateColumns: `repeat(${tabs.length}, 1fr)`,
      position: "relative",
    }}>
      <div style={{
        position: "absolute", top: 4, bottom: 4,
        left: `calc(${(selected / tabs.length) * 100}% + 4px)`,
        width: `calc(${100 / tabs.length}% - 8px)`,
        background: subtle
          ? "color-mix(in srgb, var(--nyan-primary) 16%, transparent)"
          : "var(--nyan-surface)",
        borderRadius: "calc(var(--r-control) - 3px)",
        boxShadow: subtle ? "none" : "var(--shadow-grouped)",
        transition: "left var(--dur-chrome) var(--ease-paper)",
      }} />
      {tabs.map((t, i) => {
        const isSel = i === selected;
        const color = isSel
          ? "var(--nyan-primary-deep)"
          : "var(--nyan-text-secondary)";
        return (
          <button
            key={i}
            onClick={() => onChange(i)}
            style={{
              all: "unset", cursor: "pointer", position: "relative",
              display: "flex", alignItems: "center", justifyContent: "center", gap: 6,
              color, font: "500 14px/1 var(--font-ui)", zIndex: 1, padding: "0 4px",
              textAlign: "center",
            }}
          >
            {t.icon && <Icon name={t.icon} size={16} color={color} />}
            <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{t.label}</span>
          </button>
        );
      })}
    </div>
  );
};

export { SegmentedTabControl };
