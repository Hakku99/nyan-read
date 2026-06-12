/* ============================================================================
   Nyan Read — HighlightSwatchRow
   Compiled into the DS bundle; consume as window.<Namespace>.HighlightSwatchRow.
   Props contract: ./HighlightSwatchRow.d.ts
   ============================================================================ */

/* ── Highlight swatch row ─────────────────────────────────────────────────────
   The five-pen colour picker shared by the text-selection menu (U5) and the
   highlight-note dialog (U2 / U13). Tokenised to the highlight pen palette
   (--hl-yellow … --hl-orange) — never raw hex. The selected pen gets a matcha
   ring + lift. Pass `selected` (a pen id or index) and `onSelect`. */
const NYAN_HL_PENS = [
  { id: "yellow", color: "var(--hl-yellow)", label: "Yellow" },
  { id: "green",  color: "var(--hl-green)",  label: "Green" },
  { id: "blue",   color: "var(--hl-blue)",   label: "Blue" },
  { id: "pink",   color: "var(--hl-pink)",   label: "Pink" },
  { id: "orange", color: "var(--hl-orange)", label: "Orange" },
];

const HighlightSwatchRow = ({ pens = NYAN_HL_PENS, selected, onSelect, size = 22, gap = 4, style }) => (
  <div style={{ display: "inline-flex", alignItems: "center", gap, ...style }}>
    {pens.map((p, i) => {
      const isSel = selected != null && (selected === p.id || selected === i);
      return (
        <button
          key={p.id || i}
          onClick={() => onSelect && onSelect(p.id ?? i, p)}
          title={p.label}
          aria-label={p.label}
          aria-pressed={isSel}
          style={{ all: "unset", cursor: "pointer", width: size + 10, height: size + 10, borderRadius: "50%", display: "grid", placeItems: "center" }}
        >
          <span style={{
            width: size, height: size, borderRadius: "50%", background: p.color,
            border: isSel ? "2px solid var(--nyan-primary-deep)" : "1.5px solid color-mix(in srgb, var(--nyan-surface) 80%, transparent)",
            boxShadow: isSel
              ? "0 0 0 2px var(--nyan-surface), 0 1px 4px color-mix(in srgb, var(--shadow-color) 30%, transparent)"
              : "0 1px 3px rgba(0,0,0,0.10)",
            transition: "box-shadow 140ms var(--ease-paper), border-color 140ms var(--ease-paper)",
          }} />
        </button>
      );
    })}
  </div>
);

export { HighlightSwatchRow };
