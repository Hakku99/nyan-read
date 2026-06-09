/* ============================================================================
   Nyan Read — Cards — book & content cards
   ----------------------------------------------------------------------------
   Book grid card, collapsible Continue Reading card, bookmark card.
   Part of the split component library. Exports go to window so other Babel
   <script> blocks (galleries, screens, the live prototype) can use them.
   ============================================================================ */

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
              <svg width={14} height={14} viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" strokeWidth="3.4" strokeLinecap="round" strokeLinejoin="round" style={{ display: "block" }}>
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


/* ── Continue reading card (NyanContinueReadingCard) ───────────────────────
   Latest design (U9): collapsible. Header (book glyph + "Continue Reading"
   eyebrow + caret) is always visible and toggles the body. Expanded shows a
   cover, title/author, a progress row, and a full-width matcha CTA that
   enters the book. Collapsed shrinks to a slim row carrying title + percent. */
const NyanContinueReadingCard = ({ book, onContinue, collapsed = false, onToggleCollapse }) => {
  const pct = Math.round(book.progress * 100);
  return (
    <NyanInfoCard padding={0}>
      {/* Header — tap to collapse / expand */}
      <div
        onClick={onToggleCollapse}
        style={{ display: "flex", alignItems: "center", gap: 10, padding: collapsed ? "11px 14px" : "12px 14px 8px", cursor: onToggleCollapse ? "pointer" : "default" }}
      >
        <Icon name="menu_book" size={15} color="var(--nyan-primary)" />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ font: "500 11px/1.2 var(--font-ui)", color: "var(--nyan-text-muted)", letterSpacing: "0.2px" }}>Continue Reading</div>
          {collapsed && (
            <div style={{ font: "600 13px/1.3 var(--font-ui)", color: "var(--nyan-text)", marginTop: 2, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{book.title}</div>
          )}
        </div>
        {collapsed && (
          <span style={{ font: "600 11px/1 var(--font-ui)", color: "var(--nyan-primary-deep)", flexShrink: 0 }}>{pct}%</span>
        )}
        {onToggleCollapse && (
          <Icon name="keyboard_arrow_down" size={18} color="var(--nyan-text-muted)" style={{ flexShrink: 0, transform: collapsed ? "none" : "rotate(180deg)", transition: "transform 200ms var(--ease-paper)" }} />
        )}
      </div>

      {/* Body — collapses away */}
      {!collapsed && (
        <div style={{ padding: "0 14px 14px" }}>
          <div style={{ display: "flex", gap: 12 }}>
            <div style={{ width: 56, height: 72, borderRadius: 14, background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface-muted))", border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)", flexShrink: 0, display: "grid", placeItems: "center" }}>
              <Icon name="menu_book" size={22} color="var(--nyan-primary)" />
            </div>
            <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", justifyContent: "center", gap: 8 }}>
              <div>
                <div style={{ font: "600 15px/1.3 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.1px", overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical" }}>{book.title}</div>
                {book.author && <div style={{ font: "400 12px/1.3 var(--font-ui)", color: "var(--nyan-text-muted)", marginTop: 2, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{book.author}</div>}
              </div>
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <div style={{ flex: 1, height: 4, borderRadius: 999, background: "color-mix(in srgb, var(--nyan-primary) 16%, var(--nyan-surface-muted))", overflow: "hidden" }}>
                  <div style={{ width: `${pct}%`, height: "100%", borderRadius: 999, background: "var(--nyan-primary)" }} />
                </div>
                <span style={{ font: "600 11px/1 var(--font-ui)", color: "var(--nyan-primary-deep)", flexShrink: 0 }}>{pct}%</span>
              </div>
            </div>
          </div>
          <div style={{ marginTop: 12 }}>
            <NyanPrimaryButton label="Continue Reading" icon="menu_book" expanded onPress={onContinue} />
          </div>
        </div>
      )}
    </NyanInfoCard>
  );
};


/* ── Bookmark card ─────────────────────────────────────────────────────────
   Source of truth: U12 Bookmark List (screens/bundle3.jsx `BookmarkCard`).
   Uppercase primary-deep eyebrow label, a 2-line excerpt, and — when a note
   exists — a divider followed by a "Note" pill + the note text. The swipe-to-
   delete rail lives in the list context (U12), not on the card itself. */
const NyanBookmarkCard = ({ label, excerpt, note, onPress }) => (
  <div
    onClick={onPress}
    style={{
      background: "var(--nyan-surface)",
      borderRadius: 16,
      border: "0.72px solid color-mix(in srgb, var(--nyan-divider) 36%, transparent)",
      padding: "12px 14px",
      cursor: onPress ? "pointer" : "default",
    }}
  >
    <div style={{ font: "500 10.5px/1.2 var(--font-ui)", color: "var(--nyan-primary-deep)", marginBottom: 6, letterSpacing: "0.2px", textTransform: "uppercase" }}>{label}</div>
    <div style={{ font: "400 14px/1.45 var(--font-ui)", color: "var(--nyan-text)", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical", overflow: "hidden", marginBottom: note ? 8 : 0 }}>{excerpt}</div>
    {note && (
      <div style={{ display: "flex", gap: 7, alignItems: "flex-start", marginTop: 6, paddingTop: 6, borderTop: "0.5px solid color-mix(in srgb, var(--nyan-divider) 34%, transparent)" }}>
        <div style={{ height: 20, padding: "0 7px", borderRadius: 999, background: "color-mix(in srgb, var(--nyan-primary) 10%, var(--nyan-surface-muted))", border: "0.5px solid color-mix(in srgb, var(--nyan-primary) 18%, transparent)", display: "flex", alignItems: "center", flexShrink: 0 }}>
          <span style={{ font: "500 10px/1 var(--font-ui)", color: "var(--nyan-primary-deep)" }}>Note</span>
        </div>
        <div style={{ font: "400 13px/1.38 var(--font-ui)", color: "var(--nyan-text-secondary)", flex: 1 }}>{note}</div>
      </div>
    )}
  </div>
);


/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, { NyanBookGridCard, NyanContinueReadingCard, NyanBookmarkCard });
