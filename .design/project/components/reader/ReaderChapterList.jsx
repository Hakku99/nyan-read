/* ============================================================================
   Nyan Read — ReaderChapterList
   Compiled into the DS bundle; consume as window.<Namespace>.ReaderChapterList.
   Props contract: ./ReaderChapterList.d.ts
   ============================================================================ */

/* Chapter list — current chapter = matcha badge + primary-deep title + play. */

const ReaderChapterList = ({ chapters, currentIndex, ascending = true, onSelect }) => {
  const order = chapters.map((c, i) => [c, i]);
  const rows = ascending ? order : order.slice().reverse();
  return (
    <div>
      {rows.map(([title, i]) => {
        const cur = i === currentIndex;
        return (
          <div key={i} data-current={cur ? "true" : undefined} onClick={() => onSelect && onSelect(i)} style={{ display: "flex", alignItems: "center", gap: 14, padding: "12px 8px", borderRadius: "var(--r-chip)", cursor: "pointer", background: cur ? "color-mix(in srgb, var(--nyan-primary) 12%, transparent)" : "transparent" }}>
            <div style={{ width: 30, height: 30, flex: "none", borderRadius: "var(--r-chip)", display: "grid", placeItems: "center", background: cur ? "var(--nyan-primary)" : "var(--nyan-surface-muted)", color: cur ? "var(--nyan-surface)" : "var(--nyan-text-muted)", font: `${cur ? 600 : 500} 13px/1 var(--font-mono)` }}>{i + 1}</div>
            <div style={{ flex: 1, minWidth: 0, font: `${cur ? 500 : 400} 15px/1.35 var(--font-ui)`, color: cur ? "var(--nyan-primary-deep)" : "var(--nyan-text)" }}>{title}</div>
            {cur && <i className="ph-fill ph-play" style={{ color: "var(--nyan-primary)", fontSize: 16 }} />}
          </div>
        );
      })}
    </div>
  );
};

export { ReaderChapterList };
