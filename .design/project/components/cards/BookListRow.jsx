/* ============================================================================
   Nyan Read — BookListRow
   Compiled into the DS bundle; consume as window.<Namespace>.BookListRow.
   Props contract: ./BookListRow.d.ts
   ============================================================================ */

import { Icon } from "../primitives/Icon.jsx";
import { ProgressBar } from "../primitives/ProgressBar.jsx";

/* ── Book list row (BookListRow) ──────────────────────────────────────────────
   Source of truth: U9 / U6 list view (screens/bundle3.jsx). The list-view counter-
   part to NyanBookGridCard — a small 44×58 cover, title + author, an inline
   progress bar once started, a format chip, and a trailing chevron. Drop several
   inside a NyanRowGroup for the hairline-separated shelf list. 44px min height.
   Accepts either book.pct (0–100) or book.progress (0–1). */
const BookListRow = ({ book, onPress }) => {
  const pct = book.pct != null ? book.pct : Math.round((book.progress || 0) * 100);
  return (
    <div
      onClick={onPress}
      style={{ display: "flex", alignItems: "center", gap: 12, padding: "10px 12px", minHeight: 44, cursor: onPress ? "pointer" : "default" }}
    >
      <div style={{ width: 44, height: 58, flexShrink: 0, borderRadius: "var(--r-chip)", background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))", border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)", display: "grid", placeItems: "center" }}>
        <Icon name="menu_book" size={20} color="var(--nyan-primary)" />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ font: "600 14px/1.25 var(--font-ui)", color: "var(--nyan-text)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{book.title}</div>
        {book.author && <div style={{ font: "400 12px/1.3 var(--font-ui)", color: "var(--nyan-text-muted)", marginTop: 1, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{book.author}</div>}
        {pct > 0 && (
          <ProgressBar value={pct / 100} label={`${pct}%`} style={{ marginTop: 7 }} />
        )}
      </div>
      {book.fmt && (
        <div style={{ height: 18, padding: "0 7px", flexShrink: 0, borderRadius: 999, background: "var(--nyan-surface-muted)", border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)", display: "flex", alignItems: "center" }}>
          <span style={{ font: "600 9px/1 var(--font-ui)", color: "var(--nyan-primary-deep)" }}>{book.fmt}</span>
        </div>
      )}
      <Icon name="chevron_right" size={15} color="var(--nyan-text-muted)" style={{ flexShrink: 0 }} />
    </div>
  );
};

export { BookListRow };
