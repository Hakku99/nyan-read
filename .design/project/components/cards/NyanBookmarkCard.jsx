/* ============================================================================
   Nyan Read — NyanBookmarkCard
   Compiled into the DS bundle; consume as window.<Namespace>.NyanBookmarkCard.
   Props contract: ./NyanBookmarkCard.d.ts
   ============================================================================ */

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

export { NyanBookmarkCard };
