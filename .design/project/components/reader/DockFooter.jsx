/* ============================================================================
   Nyan Read — DockFooter
   Compiled into the DS bundle; consume as window.<Namespace>.DockFooter.
   Props contract: ./DockFooter.d.ts
   ============================================================================ */

import { Icon } from "../primitives/Icon.jsx";

/* Dock footer — the persistent base of the One Paper panel:
   a chapter stepper flanking the progress bar, then the 3 actions.
   Stepper carets are the ONLY chapter-nav affordance in the model. */

const DockFooter = ({ chapterIndex, chapterCount, progress, activeAction, onAction, onPrevChapter, onNextChapter, sheetOpen, actions, labels }) => {
  const L = {
    chapters: "Chapters", bookmarks: "Bookmarks", highlights: "Highlights", settings: "Settings",
    prevChapter: "Previous chapter", nextChapter: "Next chapter",
    // (index, count) => string
    chapterStatus: (i, n) => `Chapter ${i + 1} of ${n}`,
    ...labels,
  };
  const acts = actions || [
    { key: "chapters", icon: "format_list_bulleted", label: L.chapters },
    { key: "bookmarks", icon: "bookmark_border", label: L.bookmarks },
    { key: "highlights", icon: "highlighter", label: L.highlights },
    { key: "settings", icon: "title", label: L.settings },
  ];
  const atStart = chapterIndex <= 0;
  const atEnd = chapterIndex >= chapterCount - 1;
  const step = (disabled) => ({ all: "unset", cursor: disabled ? "default" : "pointer", width: 44, height: 44, flex: "none", borderRadius: "var(--r-chip)", display: "grid", placeItems: "center", opacity: disabled ? 0.32 : 1 });
  return (
    <div style={{ borderTop: sheetOpen ? "1px solid var(--nyan-divider)" : "1px solid transparent", transition: "border-color 200ms var(--ease-paper)" }}>
      {/* Progress + chapter stepper — the dock's resting context. Folds away when
         a sheet is open: the sheet shows its own title/meta, so the stepper here
         would be redundant. The 3 actions stay, keeping it "one object." */}
      {!sheetOpen && (
        <div style={{ display: "flex", alignItems: "center", gap: 6, padding: "11px 10px 3px" }}>
          <button onClick={atStart ? undefined : onPrevChapter} disabled={atStart} aria-label={L.prevChapter} style={step(atStart)} title={L.prevChapter}><Icon name="chevron_left" size={20} color="var(--nyan-text-secondary)" /></button>
          <div style={{ flex: 1 }}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 8 }}>
              <span style={{ font: "400 12px/1 var(--font-ui)", color: "var(--nyan-text-muted)" }}>{L.chapterStatus(chapterIndex, chapterCount)}</span>
              <span style={{ font: "500 12px/1 var(--font-mono)", color: "var(--nyan-text-secondary)" }}>{Math.round(progress * 100)}%</span>
            </div>
            <div style={{ height: 4, borderRadius: 999, background: "color-mix(in srgb, var(--nyan-text) 11%, transparent)", overflow: "hidden" }}>
              <div style={{ width: `${progress * 100}%`, height: "100%", background: "var(--nyan-primary)", borderRadius: 999 }} />
            </div>
          </div>
          <button onClick={atEnd ? undefined : onNextChapter} disabled={atEnd} aria-label={L.nextChapter} style={step(atEnd)} title={L.nextChapter}><Icon name="chevron_right" size={20} color="var(--nyan-text-secondary)" /></button>
        </div>
      )}
      <div style={{ display: "flex", padding: sheetOpen ? "6px 8px 10px" : "8px 8px 12px" }}>
        {acts.map((a) => {
          const on = a.key === activeAction;
          return (
            <button key={a.key} onClick={() => onAction && onAction(a.key)} style={{ all: "unset", cursor: "pointer", flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 5, padding: "8px 4px", borderRadius: 14, background: on ? "color-mix(in srgb, var(--nyan-primary) 12%, transparent)" : "transparent", color: on ? "var(--nyan-primary-deep)" : "var(--nyan-text-secondary)", transition: "background 160ms var(--ease-paper)" }}>
              <Icon name={a.icon} size={24} color={on ? "var(--nyan-primary-deep)" : "var(--nyan-text-secondary)"} />
              <span style={{ font: `${on ? 600 : 500} 12px/1 var(--font-ui)` }}>{a.label}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
};

export { DockFooter };
