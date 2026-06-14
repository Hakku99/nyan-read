/* ============================================================================
   Nyan Read — PinPad
   Compiled into the DS bundle; consume as window.<Namespace>.PinPad.
   Props contract: ./PinPad.d.ts
   ============================================================================ */

import { Icon } from "../primitives/Icon.jsx";

/* ── PIN keypad (U16) ─────────────────────────────────────────────────────────
   The numeric keypad for the privacy gate. 72px round keys with a tinted fill, a
   backspace in the bottom-right, and an empty cell bottom-left. `keyColor` adapts
   to the takeover theme. Pairs with PinDots above it. */
const PinPad = ({ onDigit, onDelete, keyColor = "var(--nyan-text)", keySize = 72, gap = 16 }) => {
  const rows = [[1, 2, 3], [4, 5, 6], [7, 8, 9], [null, 0, "del"]];
  const key = {
    all: "unset", cursor: "pointer", width: keySize, height: keySize, borderRadius: "50%",
    background: `color-mix(in srgb, ${keyColor} 10%, transparent)`,
    border: `1px solid color-mix(in srgb, ${keyColor} 16%, transparent)`,
    display: "grid", placeItems: "center", color: keyColor,
    transition: "background 100ms ease",
  };
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 12, alignItems: "center" }}>
      {rows.map((row, ri) => (
        <div key={ri} style={{ display: "flex", gap }}>
          {row.map((k, ki) => k === null ? (
            <div key={`e${ki}`} style={{ width: keySize, height: keySize }} />
          ) : k === "del" ? (
            <button key="del" onClick={onDelete} aria-label="Delete" style={key}>
              <Icon name="backspace" size={24} color={keyColor} />
            </button>
          ) : (
            <button key={k} onClick={() => onDigit && onDigit(k)} aria-label={String(k)} style={{ ...key, font: "400 26px/1 var(--font-ui)" }}>
              {k}
            </button>
          ))}
        </div>
      ))}
    </div>
  );
};

export { PinPad };
