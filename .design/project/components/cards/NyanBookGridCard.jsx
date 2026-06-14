/* ============================================================================
   Nyan Read — NyanBookGridCard
   Compiled into the DS bundle; consume as window.<Namespace>.NyanBookGridCard.
   Props contract: ./NyanBookGridCard.d.ts
   ============================================================================ */

import { Icon } from "../primitives/Icon.jsx";

const { useState, useEffect, useRef, useCallback, useMemo } = React;

/* ── Book grid card (NyanBookGridCard) ───────────────────────────────────
   Source of truth: U9 Bookshelf Home, Cream · grid view (screens/bundle3.jsx
   `BookCard`). A chromeless column — NOT a bordered tile: a tall 120:156 cover
   wash carrying the format chip, a thin progress bar shown only once started,
   then a 2-line title + single-line author. `selectionMode` adds the top-left
   check + selected ring used by U21 multi-select.
   Accepts either `book.pct` (0–100) or `book.progress` (0–1). */
const NyanBookGridCard = ({ book, selected = false, selectionMode = false, onPress, onLongPress }) => {
  const longPressTimer = useRef(null);
  const start = () => { longPressTimer.current = setTimeout(() => onLongPress?.(), 400); };
  const cancel = () => clearTimeout(longPressTimer.current);
  const pct = book.pct != null ? book.pct : Math.round((book.progress || 0) * 100);
  return (
    <div
      onClick={onPress}
      onMouseDown={start} onMouseUp={cancel} onMouseLeave={cancel}
      onTouchStart={start} onTouchEnd={cancel}
      style={{ display: "flex", flexDirection: "column", gap: 6, cursor: "pointer", userSelect: "none" }}
    >
      {/* Cover wash */}
      <div style={{
        position: "relative", width: "100%", aspectRatio: "120 / 156", borderRadius: 12,
        background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))",
        border: selected
          ? "2px solid var(--nyan-primary)"
          : "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)",
        boxShadow: selected ? "0 0 0 3px color-mix(in srgb, var(--nyan-primary) 16%, transparent)" : "none",
        display: "grid", placeItems: "center", overflow: "hidden",
        transition: "box-shadow 140ms ease, border-color 140ms ease",
      }}>
        <Icon name="menu_book" size={26} color="var(--nyan-primary)" />
        {/* Format chip */}
        {book.fmt && (
          <div style={{
            position: "absolute", top: 6, right: 6, height: 17, padding: "0 6px", borderRadius: 999,
            background: "color-mix(in srgb, var(--nyan-surface) 88%, transparent)",
            border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)",
            display: "flex", alignItems: "center",
          }}>
            <span style={{ font: "600 9px/1 var(--font-ui)", color: "var(--nyan-primary-deep)" }}>{book.fmt}</span>
          </div>
        )}
        {/* Selection check (top-left) — matches U21 SelectCheck: deep-matcha circle + white tick */}
        {selectionMode && (
          <div style={{
            position: "absolute", top: 6, left: 6, width: 22, height: 22, borderRadius: "50%",
            display: "grid", placeItems: "center",
            background: selected ? "var(--nyan-select-fill)" : "color-mix(in srgb, var(--nyan-surface) 80%, transparent)",
            border: selected ? "1.5px solid var(--nyan-select-fill)" : "1.5px solid color-mix(in srgb, var(--nyan-text) 30%, transparent)",
            boxShadow: selected ? "0 1px 4px color-mix(in srgb, var(--nyan-select-fill) 40%, transparent)" : "none",
          }}>
            {selected && (
              <svg width={13} height={13} viewBox="0 0 24 24" fill="none" stroke="var(--nyan-surface)" strokeWidth="3.4" strokeLinecap="round" strokeLinejoin="round" style={{ display: "block" }}>
                <path d="M5 12.5 L10 17.5 L19 7" />
              </svg>
            )}
          </div>
        )}
      </div>
      {/* Progress — only once started */}
      {pct > 0 && (
        <div style={{ height: 3, borderRadius: 999, background: "color-mix(in srgb, var(--nyan-primary) 16%, var(--nyan-surface))", overflow: "hidden" }}>
          <div style={{ width: `${pct}%`, height: "100%", borderRadius: 999, background: "var(--nyan-primary)" }} />
        </div>
      )}
      {/* Title + author */}
      <div>
        <div style={{ font: "600 12.5px/1.25 var(--font-ui)", color: "var(--nyan-text)", overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical" }}>{book.title}</div>
        {book.author && <div style={{ font: "400 11px/1.3 var(--font-ui)", color: "var(--nyan-text-muted)", marginTop: 2, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{book.author}</div>}
      </div>
    </div>
  );
};

export { NyanBookGridCard };
