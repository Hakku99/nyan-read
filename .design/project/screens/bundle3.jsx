/* ============================================================================
   Nyan Read — Screens: U9 Bookshelf · U10 Book Details · U11 Import Sheet · U12 Bookmarks · U13 Notes & Highlights
   ----------------------------------------------------------------------------
   Full-screen compositions assembled from components/*. Extracted verbatim from
   the bundle gallery so Claude Code can read/edit one screen without the HTML.
   Self-exports to window; the bundle HTML imports this then renders the gallery.
   ============================================================================ */

const { useState } = React;

/* Screen scaffold helpers (PageHdr / SectionHdr / RowGroup / ListRow) and the
   reader/app wrappers are shared from screens/_chrome.jsx. */

/* ──────────────────────────────────────────────────────────────────────
   U9 · BOOKSHELF HOME SCREEN
   ────────────────────────────────────────────────────────────────────── */
const BOOKS = [
  { id: 1, title: "The Stillwater Diaries", author: "Matsuno Eri", fmt: "EPUB", pct: 42, isPrivate: false },
  { id: 2, title: "Borrowed Light", author: "Yuen Lai-Ying", fmt: "TXT", pct: 0, isPrivate: false },
  { id: 3, title: "A Long Slope Down", author: "Park Hyun-joo", fmt: "PDF", pct: 88, isPrivate: false },
  { id: 4, title: "Sand and Memoir", author: "Unknown", fmt: "EPUB", pct: 12, isPrivate: false },
];

const BookCard = ({ book, dark }) => (
  <div style={{ display: "flex", flexDirection: "column", gap: 6, cursor: "pointer" }}>
    {/* Cover */}
    <div style={{ width: "100%", aspectRatio: "120/156", borderRadius: 12, background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))", border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)", display: "grid", placeItems: "center", position: "relative", overflow: "hidden" }}>
      <i className="ph ph-book-open" style={{ fontSize: 26, color: "var(--nyan-primary)" }} />
      {/* Format chip */}
      <div style={{ position: "absolute", top: 6, right: 6, height: 17, padding: "0 6px", borderRadius: 999, background: "color-mix(in srgb, var(--nyan-surface) 88%, transparent)", border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)", display: "flex", alignItems: "center" }}>
        <span style={{ font: "600 9px/1 var(--font-ui)", color: "var(--nyan-primary-deep)" }}>{book.fmt}</span>
      </div>
    </div>
    {/* Progress bar */}
    {book.pct > 0 && (
      <div style={{ height: 3, borderRadius: 999, background: "color-mix(in srgb, var(--nyan-primary) 16%, var(--nyan-surface))", overflow: "hidden" }}>
        <div style={{ width: `${book.pct}%`, height: "100%", borderRadius: 999, background: "var(--nyan-primary)" }} />
      </div>
    )}
    {/* Title + author */}
    <div>
      <div style={{ font: "600 12.5px/1.25 var(--font-ui)", color: "var(--nyan-text)", overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical" }}>{book.title}</div>
      <div style={{ font: "400 11px/1.3 var(--font-ui)", color: "var(--nyan-text-muted)", marginTop: 2, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{book.author}</div>
    </div>
  </div>
);

const ContinueCard = ({ book, dark, initOpen = true }) => {
  const [open, setOpen] = useState(initOpen);
  return (
    <div style={{ background: "var(--nyan-surface)", borderRadius: 16, border: "0.72px solid color-mix(in srgb, var(--nyan-divider) 36%, transparent)", boxShadow: "var(--shadow-subtle)", overflow: "hidden" }}>
      {/* Header — always visible, tap to collapse/expand */}
      <div onClick={() => setOpen(o => !o)} style={{ display: "flex", alignItems: "center", gap: 10, padding: open ? "12px 12px 8px" : "11px 12px", cursor: "pointer" }}>
        <i className="ph ph-book-open-text" style={{ fontSize: 15, color: "var(--nyan-primary)", flexShrink: 0 }} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ font: "500 11px/1.2 var(--font-ui)", color: "var(--nyan-text-muted)", letterSpacing: "0.2px" }}>Continue Reading</div>
          {!open && (
            <div style={{ font: "600 13px/1.3 var(--font-ui)", color: "var(--nyan-text)", marginTop: 2, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{book.title}</div>
          )}
        </div>
        {!open && (
          <span style={{ font: "600 11px/1 var(--font-ui)", color: "var(--nyan-primary-deep)", fontVariantNumeric: "tabular-nums", flexShrink: 0 }}>{book.pct}%</span>
        )}
        <i className="ph ph-caret-down" style={{ fontSize: 15, color: "var(--nyan-text-muted)", flexShrink: 0, transform: open ? "rotate(180deg)" : "none", transition: "transform 200ms var(--ease-paper)" }} />
      </div>

      {/* Body — collapses away */}
      {open && (
        <div style={{ padding: "0 12px 12px" }}>
          <div style={{ display: "flex", gap: 12 }}>
            <div style={{ width: 56, height: 72, borderRadius: 14, background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface-muted))", border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)", flexShrink: 0, display: "grid", placeItems: "center" }}>
              <i className="ph ph-book-open" style={{ fontSize: 22, color: "var(--nyan-primary)" }} />
            </div>
            <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", justifyContent: "center", gap: 8 }}>
              <div>
                <div style={{ font: "600 14px/1.3 var(--font-ui)", color: "var(--nyan-text)", overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical" }}>{book.title}</div>
                <div style={{ font: "400 12px/1.3 var(--font-ui)", color: "var(--nyan-text-muted)", marginTop: 2, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{book.author}</div>
              </div>
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <div style={{ flex: 1, height: 3, borderRadius: 999, background: "color-mix(in srgb, var(--nyan-primary) 16%, var(--nyan-surface-muted))", overflow: "hidden" }}>
                  <div style={{ width: `${book.pct}%`, height: "100%", borderRadius: 999, background: "var(--nyan-primary)" }} />
                </div>
                <span style={{ font: "600 11px/1 var(--font-ui)", color: "var(--nyan-primary-deep)", fontVariantNumeric: "tabular-nums" }}>{book.pct}%</span>
              </div>
            </div>
          </div>
          {/* Enter-book CTA */}
          <button style={{ all: "unset", boxSizing: "border-box", cursor: "pointer", marginTop: 12, width: "100%", height: 44, borderRadius: 14, background: "var(--nyan-primary)", display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }}>
            <i className="ph ph-book-open" style={{ fontSize: 17, color: "var(--nyan-surface)" }} />
            <span style={{ font: "600 14px/1 var(--font-ui)", color: "var(--nyan-surface)" }}>Continue Reading</span>
          </button>
        </div>
      )}
    </div>
  );
};

const BookListRow = ({ book }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "10px 12px", minHeight: 44, cursor: "pointer" }}>
    {/* small cover */}
    <div style={{ width: 44, height: 58, flexShrink: 0, borderRadius: "var(--r-chip)", background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))", border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)", display: "grid", placeItems: "center" }}>
      <i className="ph ph-book-open" style={{ fontSize: 20, color: "var(--nyan-primary)" }} />
    </div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ font: "600 14px/1.25 var(--font-ui)", color: "var(--nyan-text)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{book.title}</div>
      <div style={{ font: "400 12px/1.3 var(--font-ui)", color: "var(--nyan-text-muted)", marginTop: 1, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{book.author}</div>
      {book.pct > 0 && (
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 7 }}>
          <div style={{ flex: 1, height: 3, borderRadius: 999, background: "color-mix(in srgb, var(--nyan-primary) 16%, var(--nyan-surface-muted))", overflow: "hidden" }}>
            <div style={{ width: `${book.pct}%`, height: "100%", borderRadius: 999, background: "var(--nyan-primary)" }} />
          </div>
          <span style={{ font: "500 11px/1 var(--font-mono)", color: "var(--nyan-text-muted)" }}>{book.pct}%</span>
        </div>
      )}
    </div>
    {/* format chip */}
    <div style={{ height: 18, padding: "0 7px", flexShrink: 0, borderRadius: 999, background: "var(--nyan-surface-muted)", border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)", display: "flex", alignItems: "center" }}>
      <span style={{ font: "600 9px/1 var(--font-ui)", color: "var(--nyan-primary-deep)" }}>{book.fmt}</span>
    </div>
    <i className="ph ph-caret-right" style={{ fontSize: 15, color: "var(--nyan-text-muted)", flexShrink: 0 }} />
  </div>
);

const SHELF_SORT_FIELDS = [
  { label: "Last read", asc: "Oldest opened first", desc: "Recently opened first" },
  { label: "Title", asc: "A → Z", desc: "Z → A" },
  { label: "Added", asc: "Oldest first", desc: "Newest first" },
];

/* Sort-by sheet — three sort fields + the canonical Ascending/Descending
   segmented control (the one sort-direction track used across the kit). */
const ShelfSortSheet = ({ field = 0, asc = true, onField, onDir, onClose, animateIn = true }) => (
  <div style={{ position: "absolute", inset: 0, zIndex: 50 }}>
    <style>{"@keyframes nyanFade { from { opacity: 0; } to { opacity: 1; } } @keyframes nyanSlideUp { from { transform: translateY(120%); } to { transform: translateY(0); } }"}</style>
    <div onClick={onClose} style={{ position: "absolute", inset: 0, background: "var(--scrim)",
      backdropFilter: "blur(var(--scrim-blur))", WebkitBackdropFilter: "blur(var(--scrim-blur))", animation: animateIn ? "nyanFade 220ms ease-out" : "none" }} />
    <div style={{ position: "absolute", left: "var(--inset)", right: "var(--inset)", bottom: "var(--inset)",
      background: "var(--nyan-surface)", border: "1px solid var(--chrome-edge)", borderRadius: "var(--r-sheet)",
      boxShadow: "var(--shadow-light-card)", overflow: "hidden", animation: animateIn ? "nyanSlideUp 280ms cubic-bezier(0.33,0.9,0.36,1)" : "none" }}>
      {/* grabber */}
      <div style={{ paddingTop: 10, display: "flex", justifyContent: "center" }}>
        <div style={{ width: 40, height: 5, borderRadius: 999, background: "var(--grabber)" }} />
      </div>
      {/* header */}
      <div style={{ padding: "12px 20px 4px" }}>
        <div style={{ font: "600 18px/1.2 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.1px" }}>Sort shelf by</div>
      </div>
      {/* direction — canonical Ascending / Descending track */}
      <div style={{ padding: "8px 20px 6px" }}>
        <SegmentedTabControl
          style="subtle"
          tabs={[{ label: "Ascending" }, { label: "Descending" }]}
          selected={asc ? 0 : 1}
          onChange={(i) => onDir && onDir(i === 0)}
        />
      </div>
      {/* fields */}
      <div style={{ padding: "4px 12px 16px", display: "flex", flexDirection: "column" }}>
        {SHELF_SORT_FIELDS.map((o, i) => {
          const isSel = i === field;
          return (
            <button key={o.label} onClick={() => { if (onField) onField(i); }} style={{ all: "unset", cursor: "pointer", boxSizing: "border-box",
              display: "flex", alignItems: "center", gap: 12, padding: "12px 12px", minHeight: 56, borderRadius: "var(--r-card-nested)",
              background: isSel ? "color-mix(in srgb, var(--nyan-primary) 8%, transparent)" : "transparent" }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ font: `${isSel ? 600 : 500} 15px/1.2 var(--font-ui)`, color: isSel ? "var(--nyan-primary-deep)" : "var(--nyan-text)" }}>{o.label}</div>
                <div style={{ font: "400 12.5px/1.3 var(--font-ui)", color: "var(--nyan-text-secondary)", marginTop: 2 }}>{asc ? o.asc : o.desc}</div>
              </div>
              {isSel && <i className="ph-fill ph-arrow-up" style={{ fontSize: 15, color: "var(--nyan-primary)", flexShrink: 0, transform: asc ? "none" : "scaleY(-1)" }} />}
              <div style={{ width: 22, height: 22, borderRadius: "50%", flexShrink: 0, display: "grid", placeItems: "center",
                border: `2px solid ${isSel ? "var(--nyan-primary)" : "color-mix(in srgb, var(--nyan-divider) 80%, transparent)"}` }}>
                {isSel && <div style={{ width: 11, height: 11, borderRadius: "50%", background: "var(--nyan-primary)" }} />}
              </div>
            </button>
          );
        })}
      </div>
    </div>
  </div>
);

const BookshelfHome = ({ dark, empty, view: initView, continueCollapsed, isPro = false, sort: initSort, sortOpen: initSortOpen = false, sortField: initSortField = 0, sortAsc: initSortAsc = true, sortAnimate = true }) => {
  const [tab, setTab] = useState(0);
  const [view, setView] = useState(initView || "grid");
  const [sortOpen, setSortOpen] = useState(!!initSortOpen || !!initSort);
  const [sortField, setSortField] = useState(initSortField);
  const [sortAsc, setSortAsc] = useState(initSortAsc);
  return (
    <Shell dark={dark}>
      {/* Shelf Toolbar — shared header action cluster (search · sort · view · privacy) */}
      <ShelfToolbar
        view={view} onToggleView={() => setView(v => v === "grid" ? "list" : "grid")}
        sort={sortOpen} onToggleSort={() => setSortOpen(s => !s)}
        isPro={isPro}
        onSearch={() => {}}
      />
      {/* Tabs */}
      <div style={{ padding: "0 16px 10px", flexShrink: 0 }}>
        <div style={{ display: "flex", background: "var(--nyan-surface-muted)", borderRadius: 14, padding: 3, gap: 2 }}>
          {["Public Shelf", "Private Shelf"].map((t, i) => (
            <button key={t} onClick={() => setTab(i)} style={{ all: "unset", cursor: "pointer", flex: 1, height: 34, borderRadius: 11, background: tab === i ? "var(--nyan-surface)" : "transparent", boxShadow: tab === i ? "0 1px 3px rgba(0,0,0,0.06)" : "none", font: `${tab === i ? 600 : 500} 14px/1 var(--font-ui)`, color: tab === i ? "var(--nyan-text)" : "var(--nyan-text-muted)", display: "grid", placeItems: "center", transition: "background 160ms ease" }}>
              {t}
            </button>
          ))}
        </div>
      </div>
      {/* Body */}
      <div style={{ flex: 1, overflowY: "auto", padding: "0 16px 88px" }}>
        {empty || tab === 1 ? (
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", height: "100%", gap: 14, textAlign: "center" }}>
            <div style={{ width: 80, height: 80, borderRadius: "50%", background: "color-mix(in srgb, var(--nyan-primary) 7%, var(--nyan-surface))", border: "0.7px solid color-mix(in srgb, var(--nyan-divider) 18%, transparent)", display: "grid", placeItems: "center" }}>
              <i className="ph ph-books" style={{ fontSize: 34, color: "var(--nyan-primary)", opacity: 0.78 }} />
            </div>
            <div>
              <div style={{ font: "600 18px/1.25 var(--font-ui)", color: "var(--nyan-text)", opacity: 0.84, marginBottom: 8 }}>Bookshelf is waiting for stories</div>
              <div style={{ font: "400 14px/1.4 var(--font-ui)", color: "var(--nyan-text-secondary)", opacity: 0.74 }}>Import a book to start reading</div>
            </div>
          </div>
        ) : (
          <>
            <ContinueCard book={BOOKS[0]} dark={dark} initOpen={!continueCollapsed} />
            <div style={{ height: 16 }} />
            {view === "grid" ? (
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: "16px 12px" }}>
                {BOOKS.concat(BOOKS).slice(0, 9).map((b, i) => <BookCard key={i} book={b} dark={dark} />)}
              </div>
            ) : (
              <div style={{ background: "var(--nyan-surface)", borderRadius: 16, border: "1px solid var(--chrome-edge)", boxShadow: "var(--shadow-grouped)", overflow: "hidden" }}>
                {BOOKS.concat(BOOKS).slice(0, 6).map((b, i) => (
                  <React.Fragment key={i}>
                    {i > 0 && <div style={{ height: "0.5px", background: "color-mix(in srgb, var(--nyan-divider) 34%, transparent)", margin: "0 12px" }} />}
                    <BookListRow book={b} />
                  </React.Fragment>
                ))}
              </div>
            )}
          </>
        )}
      </div>
      {/* FAB */}
      <div style={{ position: "absolute", right: 16, bottom: 24 }}>
        <button style={{ all: "unset", cursor: "pointer", width: 54, height: 54, borderRadius: 16, background: "var(--nyan-primary-deep)", display: "grid", placeItems: "center", boxShadow: "var(--shadow-light-card)" }}>
          <i className="ph ph-plus" style={{ fontSize: 24, color: "var(--nyan-surface)" }} />
        </button>
      </div>
      {/* Sort-by sheet — opens from the toolbar Sort tool */}
      {sortOpen && (
        <ShelfSortSheet
          field={sortField}
          asc={sortAsc}
          animateIn={sortAnimate}
          onField={(i) => setSortField(i)}
          onDir={(a) => setSortAsc(a)}
          onClose={() => setSortOpen(false)}
        />
      )}
    </Shell>
  );
};

/* ──────────────────────────────────────────────────────────────────────
   U6 · BOOKSHELF SEARCH
   Full-screen search over the shelf. Opens from the toolbar Search tool.
   States: idle (recent + suggestions) · results · no-match. Reuses BookListRow.
   ────────────────────────────────────────────────────────────────────── */
const SEARCH_RECENT = ["Stillwater", "Matsuno Eri", "essays"];
const SEARCH_SUGGEST = ["Recently added", "In progress", "Finished", "PDF files"];

const SearchField = ({ query, focused }) => (
  <div style={{ flex: 1, height: 44, display: "flex", alignItems: "center", gap: 10, padding: "0 12px",
    borderRadius: "var(--r-control)", background: "var(--nyan-surface)",
    border: `1.5px solid ${focused ? "var(--nyan-primary)" : "color-mix(in srgb, var(--nyan-divider) 50%, transparent)"}`,
    boxShadow: focused ? "0 0 0 3px color-mix(in srgb, var(--nyan-primary) 12%, transparent)" : "none",
    transition: "border-color 140ms var(--ease-paper)" }}>
    <i className="ph ph-magnifying-glass" style={{ fontSize: 18, color: query ? "var(--nyan-primary)" : "var(--nyan-text-muted)", flexShrink: 0 }} />
    <div style={{ flex: 1, minWidth: 0, display: "flex", alignItems: "center", font: "400 15px/1 var(--font-ui)", color: query ? "var(--nyan-text)" : "var(--nyan-text-muted)", whiteSpace: "nowrap", overflow: "hidden" }}>
      {query || "Search title or author"}
      {focused && <span style={{ width: 1.5, height: 18, marginLeft: 1, background: "var(--nyan-primary)", animation: "nyan-caret 1100ms steps(1) infinite" }} />}
    </div>
    {query && (
      <button style={{ all: "unset", cursor: "pointer", width: 22, height: 22, borderRadius: "50%", background: "color-mix(in srgb, var(--nyan-text) 12%, transparent)", display: "grid", placeItems: "center", flexShrink: 0 }}>
        <i className="ph ph-x" style={{ fontSize: 12, color: "var(--nyan-surface)" }} />
      </button>
    )}
  </div>
);

const SearchChip = ({ icon, label }) => (
  <div style={{ height: 34, padding: "0 12px", borderRadius: "var(--r-chip)", display: "inline-flex", alignItems: "center", gap: 7,
    background: "var(--nyan-surface-muted)", border: "1px solid color-mix(in srgb, var(--nyan-divider) 40%, transparent)", cursor: "pointer" }}>
    <i className={`ph ph-${icon}`} style={{ fontSize: 14, color: "var(--nyan-text-muted)" }} />
    <span style={{ font: "500 13px/1 var(--font-ui)", color: "var(--nyan-text-secondary)" }}>{label}</span>
  </div>
);

const BookshelfSearch = ({ dark, query = "", focused = true, initView = "list" }) => {
  const q = query.trim().toLowerCase();
  const results = q ? BOOKS.filter(b => b.title.toLowerCase().includes(q) || b.author.toLowerCase().includes(q)) : [];
  const [resultView, setResultView] = useState(initView);
  return (
    <Shell dark={dark}>
      {/* Search bar row — back + field */}
      <div style={{ padding: "14px 12px 12px", display: "flex", alignItems: "center", gap: 8, flexShrink: 0 }}>
        <button style={{ all: "unset", cursor: "pointer", width: 40, height: 40, borderRadius: "var(--r-control)", display: "grid", placeItems: "center", flexShrink: 0 }}>
          <i className="ph ph-arrow-left" style={{ fontSize: 21, color: "var(--nyan-text)" }} />
        </button>
        <SearchField query={query} focused={focused} />
      </div>

      {/* Body */}
      <div style={{ flex: 1, overflowY: "auto", padding: "4px 16px 28px" }}>
        {!q ? (
          /* Idle — recent + suggestions */
          <>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "8px 4px 10px" }}>
              <span style={{ font: "500 11px/1 var(--font-ui)", color: "var(--nyan-primary-deep)", letterSpacing: "0.22px", textTransform: "uppercase" }}>Recent</span>
              <span style={{ font: "500 12px/1 var(--font-ui)", color: "var(--nyan-text-muted)", cursor: "pointer" }}>Clear</span>
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
              {SEARCH_RECENT.map(r => (
                <div key={r} style={{ display: "flex", alignItems: "center", gap: 12, padding: "11px 6px", cursor: "pointer", minHeight: 44 }}>
                  <i className="ph ph-clock-counter-clockwise" style={{ fontSize: 18, color: "var(--nyan-text-muted)", flexShrink: 0 }} />
                  <span style={{ flex: 1, font: "400 15px/1.2 var(--font-ui)", color: "var(--nyan-text)" }}>{r}</span>
                  <i className="ph ph-arrow-up-left" style={{ fontSize: 16, color: "var(--nyan-text-muted)", flexShrink: 0 }} />
                </div>
              ))}
            </div>
            <SectionHdr label="Quick filters" />
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
              {[["sparkle", "Recently added"], ["book-open-text", "In progress"], ["check-circle", "Finished"], ["file-pdf", "PDF files"]].map(([ic, l]) => <SearchChip key={l} icon={ic} label={l} />)}
            </div>
          </>
        ) : results.length ? (
          /* Results */
          <>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 8, padding: "8px 4px 12px" }}>
              <span style={{ font: "500 12px/1 var(--font-ui)", color: "var(--nyan-text-muted)" }}>
                {results.length} {results.length === 1 ? "result" : "results"} for "{query.trim()}"
              </span>
              <div style={{ display: "flex", gap: 2, padding: 3, borderRadius: 10, background: "var(--nyan-surface-muted)", flexShrink: 0 }}>
                {[["list", "list"], ["grid", "squares-four"]].map(([v, ic]) => (
                  <button key={v} onClick={() => setResultView(v)} title={v === "list" ? "List view" : "Grid view"}
                    style={{ all: "unset", cursor: "pointer", width: 30, height: 26, borderRadius: 8, display: "grid", placeItems: "center",
                      background: resultView === v ? "var(--nyan-surface)" : "transparent",
                      boxShadow: resultView === v ? "var(--shadow-subtle)" : "none" }}>
                    <i className={`ph ph-${ic}`} style={{ fontSize: 15, color: resultView === v ? "var(--nyan-primary-deep)" : "var(--nyan-text-muted)" }} />
                  </button>
                ))}
              </div>
            </div>
            {resultView === "list" ? (
              <div style={{ background: "var(--nyan-surface)", borderRadius: 16, border: "1px solid var(--chrome-edge)", boxShadow: "var(--shadow-grouped)", overflow: "hidden" }}>
                {results.map((b, i) => (
                  <React.Fragment key={b.id}>
                    {i > 0 && <div style={{ height: "0.5px", background: "color-mix(in srgb, var(--nyan-divider) 34%, transparent)", margin: "0 12px" }} />}
                    <BookListRow book={b} />
                  </React.Fragment>
                ))}
              </div>
            ) : (
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: "16px 12px" }}>
                {results.map(b => <BookCard key={b.id} book={b} dark={dark} />)}
              </div>
            )}
          </>
        ) : (
          /* No match */
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", textAlign: "center", height: "100%", gap: 14, paddingBottom: 40 }}>
            <div style={{ width: 80, height: 80, borderRadius: "50%", background: "color-mix(in srgb, var(--nyan-primary) 6%, var(--nyan-surface))", border: "0.7px solid color-mix(in srgb, var(--nyan-divider) 18%, transparent)", display: "grid", placeItems: "center" }}>
              <i className="ph ph-magnifying-glass" style={{ fontSize: 32, color: "var(--nyan-primary)", opacity: 0.7 }} />
            </div>
            <div>
              <div style={{ font: "600 17px/1.25 var(--font-ui)", color: "var(--nyan-text)", opacity: 0.84, marginBottom: 8 }}>No books match "{query.trim()}"</div>
              <div style={{ font: "400 14px/1.4 var(--font-ui)", color: "var(--nyan-text-secondary)", opacity: 0.74 }}>Try a different title or author name.</div>
            </div>
          </div>
        )}
      </div>
    </Shell>
  );
};

/* ──────────────────────────────────────────────────────────────────────
   U10 · BOOK DETAILS PAGE
   ────────────────────────────────────────────────────────────────────── */
const BookDetails = ({ dark, unavailable }) => (
  <Shell dark={dark}>
    <PageHdr dark={dark} title="Book Details" />
    <div style={{ flex: 1, overflowY: "auto", padding: "0 16px 32px" }}>
      {/* Hero cover */}
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 10, marginBottom: 16 }}>
        <div style={{ width: 120, height: 156, borderRadius: 16, background: unavailable ? "var(--nyan-surface-muted)" : "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))", border: unavailable ? "1px solid color-mix(in srgb, var(--error-primary) 22%, transparent)" : "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)", display: "grid", placeItems: "center", position: "relative" }}>
          {unavailable
            ? <i className="ph ph-warning-circle" style={{ fontSize: 40, color: "var(--error-primary)" }} />
            : <i className="ph ph-book-open" style={{ fontSize: 44, color: "var(--nyan-primary)" }} />}
        </div>
        <div style={{ font: "600 20px/1.3 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.1px", textAlign: "center" }}>The Stillwater Diaries</div>
        <div style={{ font: "400 13px/1.3 var(--font-ui)", color: "var(--nyan-text-secondary)", textAlign: "center" }}>Matsuno Eri</div>
        {/* CTA row */}
        <div style={{ display: "flex", gap: 8, width: "100%" }}>
          <button style={{ all: "unset", cursor: unavailable ? "not-allowed" : "pointer", flex: 1, height: 50, borderRadius: 16, background: unavailable ? "color-mix(in srgb, var(--nyan-primary) 42%, var(--nyan-surface-muted))" : "var(--nyan-primary)", font: "600 16px/1 var(--font-ui)", color: "var(--nyan-surface)", display: "grid", placeItems: "center", opacity: unavailable ? 0.55 : 1 }}>
            {unavailable ? "File unavailable" : "Continue Reading"}
          </button>
          <button style={{ all: "unset", cursor: "pointer", width: 50, height: 50, borderRadius: 16, background: "var(--nyan-surface)", border: "1px solid color-mix(in srgb, var(--nyan-divider) 60%, transparent)", display: "grid", placeItems: "center", flexShrink: 0 }}>
            <i className="ph ph-export" style={{ fontSize: 20, color: "var(--nyan-text)" }} />
          </button>
        </div>
        {unavailable && (
          <div style={{ width: "100%", background: "var(--error-bg)", borderRadius: 12, border: "1px solid color-mix(in srgb, var(--error-accent) 60%, transparent)", padding: "10px 12px", display: "flex", gap: 8, alignItems: "flex-start" }}>
            <i className="ph ph-info" style={{ fontSize: 15, color: "var(--error-primary)", flexShrink: 0, marginTop: 1 }} />
            <div style={{ font: "400 13px/1.4 var(--font-ui)", color: "var(--error-primary)" }}>This book seems to have lost its way. The file cannot be found.</div>
          </div>
        )}
      </div>
      {/* Overview section */}
      <SectionHdr label="Overview" />
      <RowGroup>
        {[["Title","The Stillwater Diaries"],["Author","Matsuno Eri"],["Format","EPUB"],["Privacy","Public Shelf"],["Reading Progress","42%"],["Added","2025-11-04"]].map(([l,v]) => (
          <div key={l} style={{ display: "flex", alignItems: "center", padding: "12px 16px", minHeight: 44 }}>
            <span style={{ font: "500 13px/1.2 var(--font-ui)", color: "var(--nyan-text-secondary)", flex: 1 }}>{l}</span>
            <span style={{ font: "500 14px/1.2 var(--font-ui)", color: "var(--nyan-text)", textAlign: "right" }}>{v}</span>
          </div>
        ))}
      </RowGroup>
      <div style={{ height: 24 }} />
      {/* Source section */}
      <SectionHdr label="Source" />
      <RowGroup>
        <ListRow icon="folder-open" title="Original Path" subtitle={unavailable ? "File not found" : "stillwater_diaries.epub"} />
        <ListRow icon="copy" title="Copy Path" />
        <ListRow icon="clock" title="Last Opened" subtitle="2025-11-28 14:22:09" />
      </RowGroup>
      <div style={{ height: 24 }} />
      {/* Highlights section */}
      <SectionHdr label="Highlights & Notes" />
      <RowGroup>
        <ListRow icon="bookmark" title="Highlights & Notes" subtitle="No highlights yet" chevron />
      </RowGroup>
    </div>
  </Shell>
);

/* ──────────────────────────────────────────────────────────────────────
   U11 · IMPORT BOOK SHEET
   `importing` swaps the format-picker body for a live import-progress card:
   per-file status (done / importing / waiting) under an overall counter.
   ────────────────────────────────────────────────────────────────────── */
const IMPORT_QUEUE = [
  { name: "stillwater_diaries.epub", fmt: "EPUB", state: "done" },
  { name: "borrowed_light.txt",      fmt: "TXT",  state: "importing" },
  { name: "a_long_slope_down.pdf",   fmt: "PDF",  state: "waiting" },
];

const ImportFileRow = ({ file }) => {
  const lead = file.state === "done"
    ? <i className="ph ph-check-circle" style={{ fontSize: 20, color: "var(--nyan-success)" }} />
    : file.state === "importing"
    ? <i className="ph ph-circle-notch" style={{ fontSize: 20, color: "var(--nyan-primary)", animation: "nyan-spin 900ms linear infinite" }} />
    : <i className="ph ph-circle-dashed" style={{ fontSize: 20, color: "var(--nyan-text-muted)", opacity: 0.7 }} />;
  const statusLabel = { done: "Added", importing: "Importing…", waiting: "Waiting" }[file.state];
  const statusColor = file.state === "done" ? "var(--nyan-success)" : file.state === "importing" ? "var(--nyan-primary-deep)" : "var(--nyan-text-muted)";
  return (
    <div style={{ padding: "11px 16px", display: "flex", alignItems: "center", gap: 12, minHeight: 44, opacity: file.state === "waiting" ? 0.7 : 1 }}>
      <div style={{ width: 28, display: "grid", placeItems: "center", flexShrink: 0 }}>{lead}</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ font: "500 14px/1.2 var(--font-ui)", color: "var(--nyan-text)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{file.name}</div>
        {file.state === "importing" ? (
          <div style={{ height: 3, borderRadius: 999, background: "color-mix(in srgb, var(--nyan-primary) 14%, var(--nyan-surface-muted))", overflow: "hidden", marginTop: 7 }}>
            <div style={{ width: "40%", height: "100%", borderRadius: 999, background: "var(--nyan-primary)", animation: "nyan-loadbar 1400ms var(--ease-paper) infinite" }} />
          </div>
        ) : (
          <div style={{ font: "400 12px/1.3 var(--font-ui)", color: statusColor, marginTop: 2 }}>{statusLabel}</div>
        )}
      </div>
      <div style={{ height: 18, padding: "0 7px", flexShrink: 0, borderRadius: 999, background: "var(--nyan-surface-muted)", border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)", display: "flex", alignItems: "center" }}>
        <span style={{ font: "600 9px/1 var(--font-ui)", color: "var(--nyan-primary-deep)" }}>{file.fmt}</span>
      </div>
    </div>
  );
};

const ImportSheet = ({ dark, emptyShelf, importing }) => {
  const doneCount = IMPORT_QUEUE.filter(f => f.state === "done").length;
  const total = IMPORT_QUEUE.length;
  const pct = Math.round((doneCount / total) * 100);
  return (
  <Shell dark={dark}>
    <div style={{ position: "relative", flex: 1 }}>
      {/* warm-ink scrim + gentle blur over the shelf behind */}
      <div style={{ position: "absolute", inset: 0, background: "var(--scrim)", backdropFilter: "blur(var(--scrim-blur))", WebkitBackdropFilter: "blur(var(--scrim-blur))" }} />
      {/* floating sheet — inset on all sides, all four corners, one soft lift */}
      <div style={{ position: "absolute", left: "var(--inset)", right: "var(--inset)", bottom: "var(--inset)", background: "var(--nyan-surface)", border: "1px solid var(--chrome-edge)", borderRadius: "var(--r-sheet)", boxShadow: "var(--shadow-light-card)", overflow: "hidden" }}>
        {/* Matcha grabber */}
        <div style={{ paddingTop: 10, display: "flex", justifyContent: "center" }}>
          <div style={{ width: 40, height: 5, borderRadius: 999, background: "var(--grabber)" }} />
        </div>
        <div style={{ padding: "12px 20px 24px", display: "flex", flexDirection: "column", gap: 14 }}>
          {/* Title */}
          <div>
            <div style={{ font: "600 18px/1.2 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.1px", marginBottom: 4 }}>
              {importing ? "Importing Books" : "Import Books"}
            </div>
            <div style={{ font: "400 13px/1.38 var(--font-ui)", color: "var(--nyan-text-secondary)" }}>
              {importing ? "Adding to your shelf. Keep the app open." : emptyShelf ? "Add your first book to get started." : "Add more books to your shelf."}
            </div>
          </div>
          {/* Shelf badge */}
          <div style={{ display: "inline-flex", alignItems: "center", gap: 8, height: 34, padding: "0 12px", background: "color-mix(in srgb, var(--nyan-primary) 8%, transparent)", border: "1px solid color-mix(in srgb, var(--nyan-divider) 45%, transparent)", borderRadius: 12, alignSelf: "flex-start" }}>
            <i className="ph ph-books" style={{ fontSize: 15, color: "var(--nyan-primary)" }} />
            <span style={{ font: "600 13px/1 var(--font-ui)", color: "var(--nyan-primary)" }}>Public Shelf</span>
          </div>
          {/* Body */}
          {importing ? (
            <RowGroup>
              {/* Overall progress header */}
              <div style={{ padding: "14px 16px 16px" }}>
                <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between", marginBottom: 10 }}>
                  <span style={{ font: "500 13px/1.2 var(--font-ui)", color: "var(--nyan-text-secondary)" }}>Importing {total} files</span>
                  <span style={{ font: "500 13px/1 var(--font-mono)", color: "var(--nyan-primary-deep)" }}>{doneCount} / {total}</span>
                </div>
                <div style={{ height: 6, borderRadius: 999, background: "color-mix(in srgb, var(--nyan-primary) 14%, var(--nyan-surface-muted))", overflow: "hidden" }}>
                  <div style={{ width: `${pct}%`, height: "100%", borderRadius: 999, background: "var(--nyan-primary)", transition: "width 320ms var(--ease-paper)" }} />
                </div>
              </div>
              {IMPORT_QUEUE.map((f, i) => <ImportFileRow key={i} file={f} />)}
            </RowGroup>
          ) : (
          <RowGroup>
            <ListRow icon="file" title="Import Files" subtitle="Browse and open .txt, .epub or .pdf" chevron />
            <div style={{ height: "0.5px", background: "color-mix(in srgb, var(--nyan-divider) 34%, transparent)", margin: "0 16px" }} />
            <div style={{ padding: "12px 16px 16px", display: "flex", gap: 12, alignItems: "flex-start" }}>
              <div style={{ width: 44, height: 44, borderRadius: 12, background: "color-mix(in srgb, var(--nyan-primary) 10%, var(--nyan-surface-muted))", flexShrink: 0, display: "grid", placeItems: "center" }}>
                <i className="ph ph-book" style={{ fontSize: 20, color: "var(--nyan-primary)" }} />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ font: "500 15px/1.2 var(--font-ui)", color: "var(--nyan-text)", marginBottom: 4 }}>Supported Formats</div>
                <div style={{ font: "400 13px/1.3 var(--font-ui)", color: "var(--nyan-text-secondary)", marginBottom: 12 }}>Plain text, e-book, and document files.</div>
                <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                  {["TXT", "EPUB", "PDF"].map(f => (
                    <div key={f} style={{ height: 30, padding: "0 12px", borderRadius: 12, background: "color-mix(in srgb, var(--nyan-primary) 10%, var(--nyan-surface-muted))", border: "1px solid color-mix(in srgb, var(--nyan-divider) 50%, transparent)", display: "flex", alignItems: "center" }}>
                      <span style={{ font: "600 13px/1 var(--font-ui)", color: "var(--nyan-primary)" }}>{f}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </RowGroup>
          )}
        </div>
      </div>
    </div>
  </Shell>
  );
};

/* ──────────────────────────────────────────────────────────────────────
   U12 · BOOKMARK LIST PAGE
   ────────────────────────────────────────────────────────────────────── */
const BOOKMARKS = [
  { id: 1, label: "Bookmark 1", excerpt: "She would sometimes say that of all the noises in the city, only the bell and the rain felt honest.", note: "Opens and closes the chapter — the bell is the thesis.", date: "2025.11.04" },
  { id: 2, label: "Bookmark 2", excerpt: "He set the lacquer cup down on the low table and looked, again, at the calligraphy.", note: null, date: "2025.11.04" },
  { id: 3, label: "Bookmark 3", excerpt: "Some things are better held at arm's length, like a wet umbrella indoors.", note: "Perfect sentence to quote.", date: "2025.11.06" },
];

/* Shared "mid-deletion" row — a card collapsed to a calm Removing… strip with a
   spinner. Used by both the Bookmark and Notes deleting states. */
const RemovingRow = ({ label, excerpt }) => (
  <div style={{ borderRadius: 16, marginBottom: 8, background: "var(--nyan-surface)", border: "0.72px solid color-mix(in srgb, var(--nyan-divider) 36%, transparent)", padding: "14px", display: "flex", alignItems: "center", gap: 11, opacity: 0.92 }}>
    <i className="ph ph-circle-notch" style={{ fontSize: 20, color: "var(--error-primary)", animation: "nyan-spin 900ms linear infinite", flexShrink: 0 }} />
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ font: "600 13px/1.2 var(--font-ui)", color: "var(--nyan-text-secondary)" }}>{label}</div>
      <div style={{ font: "400 13px/1.35 var(--font-ui)", color: "var(--nyan-text-muted)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", marginTop: 2, textDecoration: "line-through", opacity: 0.7 }}>{excerpt}</div>
    </div>
  </div>
);

const BookmarkCard = ({ bm, revealed, onReveal }) => (
  <div style={{ position: "relative", borderRadius: 16, overflow: "hidden", marginBottom: 8 }}>
    {/* Delete rail */}
    <div style={{ position: "absolute", right: 0, top: 0, bottom: 0, width: 104, background: "linear-gradient(to right, transparent, color-mix(in srgb, var(--error-bg) 60%, var(--nyan-surface)))", borderRadius: "0 16px 16px 0", border: "0.5px solid color-mix(in srgb, var(--error-accent) 14%, transparent)", display: "flex", alignItems: "center", justifyContent: "flex-end", padding: "0 12px", gap: 6 }}>
      <span style={{ font: "600 12px/1 var(--font-ui)", color: "var(--error-primary)", opacity: 0.62 }}>Delete</span>
      <i className="ph ph-trash" style={{ fontSize: 20, color: "var(--error-primary)", opacity: 0.72 }} />
    </div>
    {/* Card */}
    <div style={{ background: "var(--nyan-surface)", borderRadius: 16, border: "0.72px solid color-mix(in srgb, var(--nyan-divider) 36%, transparent)", padding: "12px 14px", position: "relative", transform: revealed ? "translateX(-80px)" : "none", transition: "transform 220ms ease" }}>
      <div style={{ font: "500 11px/1.2 var(--font-ui)", color: "var(--nyan-primary-deep)", marginBottom: 6, letterSpacing: "0.2px", textTransform: "uppercase", fontSize: 10.5 }}>{bm.label}</div>
      <div style={{ font: "400 14px/1.45 var(--font-ui)", color: "var(--nyan-text)", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical", overflow: "hidden", marginBottom: bm.note ? 8 : 0 }}>{bm.excerpt}</div>
      {bm.note && (
        <div style={{ display: "flex", gap: 7, alignItems: "flex-start", marginTop: 6, paddingTop: 6, borderTop: "0.5px solid color-mix(in srgb, var(--nyan-divider) 34%, transparent)" }}>
          <div style={{ height: 20, padding: "0 7px", borderRadius: 999, background: "color-mix(in srgb, var(--nyan-primary) 10%, var(--nyan-surface-muted))", border: "0.5px solid color-mix(in srgb, var(--nyan-primary) 18%, transparent)", display: "flex", alignItems: "center", flexShrink: 0 }}>
            <span style={{ font: "500 10px/1 var(--font-ui)", color: "var(--nyan-primary-deep)" }}>Note</span>
          </div>
          <div style={{ font: "400 13px/1.38 var(--font-ui)", color: "var(--nyan-text-secondary)", flex: 1 }}>{bm.note}</div>
        </div>
      )}
    </div>
  </div>
);

const BookmarkList = ({ dark, empty, phase }) => {
  const count = empty ? 0 : phase === "deleted" ? BOOKMARKS.length - 1 : BOOKMARKS.length;
  return (
  <Shell dark={dark}>
    <PageHdr dark={dark} title={`Bookmarks (${count})`} subtitle="The Stillwater Diaries" />
    <div style={{ position: "relative", flex: 1, overflow: "hidden" }}>
      <div style={{ position: "absolute", inset: 0, overflowY: "auto", padding: "4px 16px 24px" }}>
      {empty ? (
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", textAlign: "center", height: "100%", gap: 14 }}>
          <div style={{ width: 84, height: 84, borderRadius: "50%", background: "color-mix(in srgb, var(--nyan-primary) 6%, var(--nyan-surface))", border: "0.7px solid color-mix(in srgb, var(--nyan-divider) 18%, transparent)", display: "grid", placeItems: "center" }}>
            <i className="ph ph-bookmark-simple" style={{ fontSize: 36, color: "var(--nyan-primary)", opacity: 0.78 }} />
          </div>
          <div>
            <div style={{ font: "600 18px/1.25 var(--font-ui)", color: "var(--nyan-text)", opacity: 0.84, marginBottom: 8 }}>No bookmarks yet</div>
            <div style={{ font: "400 14px/1.4 var(--font-ui)", color: "var(--nyan-text-secondary)", opacity: 0.74, marginBottom: 10 }}>Passages worth returning to will gather here.</div>
            <div style={{ font: "400 13px/1.38 var(--font-ui)", color: "var(--nyan-text-secondary)", opacity: 0.62 }}>Tap the bookmark while reading to save one.</div>
          </div>
        </div>
      ) : (
        <>
          {/* Context panel — reflects the active gesture when deleting */}
          <div style={{ background: "var(--nyan-surface)", borderRadius: 16, border: "0.6px solid color-mix(in srgb, var(--nyan-divider) 22%, transparent)", padding: "12px", display: "flex", gap: 12, alignItems: "center", marginBottom: 16, boxShadow: "var(--shadow-subtle)" }}>
            <div style={{ width: 32, height: 32, borderRadius: 12, background: "color-mix(in srgb, var(--nyan-primary) 8%, var(--nyan-surface-muted))", display: "grid", placeItems: "center", flexShrink: 0 }}>
              <i className="ph ph-bookmarks" style={{ fontSize: 16, color: "var(--nyan-primary)", opacity: 0.84 }} />
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ font: "600 14px/1.1 var(--font-ui)", color: "var(--nyan-text)", opacity: 0.85 }}>Your bookmarks</div>
              <div style={{ font: "400 12px/1.3 var(--font-ui)", color: "var(--nyan-text-secondary)", marginTop: 3, opacity: 0.74 }}>
                {phase === "reveal" ? "Release to delete, or tap the card to cancel." : "Tap to jump back. Swipe left to delete."}
              </div>
            </div>
          </div>
          {/* Date group */}
          <div style={{ font: "600 11px/1 var(--font-ui)", color: "var(--nyan-text-secondary)", opacity: 0.56, letterSpacing: "0.3px", padding: "0 4px", marginBottom: 8 }}>2025.11.04</div>
          {phase === "deleted"
            ? <BookmarkCard bm={BOOKMARKS[1]} />
            : (
              <>
                {phase === "removing"
                  ? <RemovingRow label="Removing bookmark…" excerpt={BOOKMARKS[0].excerpt} />
                  : <BookmarkCard bm={BOOKMARKS[0]} revealed={phase === "reveal"} />}
                <BookmarkCard bm={BOOKMARKS[1]} />
              </>
            )}
          <div style={{ height: 4 }} />
          <div style={{ font: "600 11px/1 var(--font-ui)", color: "var(--nyan-text-secondary)", opacity: 0.56, letterSpacing: "0.3px", padding: "0 4px", marginBottom: 8 }}>2025.11.06</div>
          <BookmarkCard bm={BOOKMARKS[2]} />
        </>
      )}
      </div>
      {phase === "deleted" && (
        <NyanResponse placement="bottom" status="success" title="Bookmark deleted" action={{ label: "Undo" }} />
      )}
    </div>
  </Shell>
  );
};

/* ──────────────────────────────────────────────────────────────────────
   U13 · NOTES & HIGHLIGHTS LIST PAGE
   ────────────────────────────────────────────────────────────────────── */
const HL_COLORS = ["#D8C06B","#A9C08E","#7FABAC","#CDA2A8","#D8C06B"];
const HIGHLIGHTS = [
  { id: 1, label: "Highlight 1", excerpt: "only the bell and the rain felt honest", note: "Opens and closes the chapter — the bell is the thesis.", color: "#D8C06B", ink: "#B89A2C", para: "Paragraph 4" },
  { id: 2, label: "Highlight 2", excerpt: "He set the lacquer cup down on the low table and looked, again, at the calligraphy hanging in the alcove.", note: null, color: "#9EC5E8", ink: "#2E6B96", para: "Paragraph 12" },
  { id: 3, label: "Highlight 3", excerpt: "Some things are better held at arm's length, like a wet umbrella indoors.", note: "Perfect sentence to quote.", color: "#A8D18D", ink: "#4E8A2D", para: "Paragraph 19" },
];

const HighlightCard = ({ hl, revealed }) => (
  <div style={{ position: "relative", borderRadius: 16, overflow: "hidden", marginBottom: 8 }}>
    {/* Delete rail — revealed on swipe-left */}
    <div style={{ position: "absolute", right: 0, top: 0, bottom: 0, width: 104, background: "linear-gradient(to right, transparent, color-mix(in srgb, var(--error-bg) 60%, var(--nyan-surface)))", borderRadius: "0 16px 16px 0", border: "0.5px solid color-mix(in srgb, var(--error-accent) 14%, transparent)", display: "flex", alignItems: "center", justifyContent: "flex-end", padding: "0 12px", gap: 6 }}>
      <span style={{ font: "600 12px/1 var(--font-ui)", color: "var(--error-primary)", opacity: 0.62 }}>Delete</span>
      <i className="ph ph-trash" style={{ fontSize: 20, color: "var(--error-primary)", opacity: 0.72 }} />
    </div>
    <div style={{ background: "var(--nyan-surface)", borderRadius: 16, border: "0.72px solid color-mix(in srgb, var(--nyan-divider) 36%, transparent)", padding: "12px 14px", display: "flex", gap: 10, position: "relative", transform: revealed ? "translateX(-80px)" : "none", transition: "transform 220ms ease" }}>
    {/* Color strip */}
    <div style={{ width: 3, borderRadius: 99, background: hl.color, flexShrink: 0, alignSelf: "stretch" }} />
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 5 }}>
        <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
          <div style={{ width: 14, height: 14, borderRadius: "50%", background: hl.color, border: "1px solid color-mix(in srgb, var(--nyan-surface) 80%, transparent)" }} />
          <span style={{ font: "500 11px/1 var(--font-ui)", color: `color-mix(in srgb, ${hl.ink} 85%, var(--nyan-text))`, fontSize: 10.5 }}>{hl.label}</span>
        </div>
        <span style={{ font: "400 11px/1 var(--font-ui)", color: "var(--nyan-text-muted)", fontSize: 10.5 }}>{hl.para}</span>
      </div>
      <div style={{ font: "400 14px/1.45 var(--font-ui)", color: "var(--nyan-text)", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical", overflow: "hidden", marginBottom: hl.note ? 8 : 0 }}>{hl.excerpt}</div>
      {hl.note && (
        <div style={{ display: "flex", gap: 7, alignItems: "flex-start", paddingTop: 6, borderTop: "0.5px solid color-mix(in srgb, var(--nyan-divider) 34%, transparent)" }}>
          <div style={{ height: 20, padding: "0 7px", borderRadius: 999, background: "color-mix(in srgb, var(--nyan-primary) 10%, var(--nyan-surface-muted))", border: "0.5px solid color-mix(in srgb, var(--nyan-primary) 18%, transparent)", display: "flex", alignItems: "center", flexShrink: 0 }}>
            <span style={{ font: "500 10px/1 var(--font-ui)", color: "var(--nyan-primary-deep)" }}>Note</span>
          </div>
          <div style={{ font: "400 13px/1.38 var(--font-ui)", color: "var(--nyan-text-secondary)" }}>{hl.note}</div>
        </div>
      )}
    </div>
    </div>
  </div>
);

const NotesList = ({ dark, empty, phase }) => {
  const count = empty ? 0 : phase === "deleted" ? HIGHLIGHTS.length - 1 : HIGHLIGHTS.length;
  const rows = phase === "deleted" ? HIGHLIGHTS.slice(1) : HIGHLIGHTS;
  return (
  <Shell dark={dark}>
    {/* Gradient top tint (from source: primary@5% → background) */}
    <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: 160, background: "linear-gradient(to bottom, color-mix(in srgb, var(--nyan-primary) 5%, var(--nyan-bg)), var(--nyan-bg))", pointerEvents: "none", zIndex: 0 }} />
    <div style={{ position: "relative", zIndex: 1, display: "flex", flexDirection: "column", height: "100%" }}>
      <PageHdr dark={dark} title={`Highlights & Notes (${count})`} subtitle="The Stillwater Diaries" />
      <div style={{ position: "relative", flex: 1, overflow: "hidden" }}>
        <div style={{ position: "absolute", inset: 0, overflowY: "auto", padding: "4px 16px 24px" }}>
        {empty ? (
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", textAlign: "center", height: "100%", gap: 14 }}>
            <div style={{ width: 84, height: 84, borderRadius: "50%", background: "color-mix(in srgb, var(--nyan-primary) 6%, var(--nyan-surface))", border: "0.7px solid color-mix(in srgb, var(--nyan-divider) 18%, transparent)", display: "grid", placeItems: "center" }}>
              <i className="ph ph-highlighter-circle" style={{ fontSize: 36, color: "var(--nyan-primary)", opacity: 0.78 }} />
            </div>
            <div>
              <div style={{ font: "600 18px/1.25 var(--font-ui)", color: "var(--nyan-text)", opacity: 0.84, marginBottom: 8 }}>No reading notes yet</div>
              <div style={{ font: "400 14px/1.4 var(--font-ui)", color: "var(--nyan-text-secondary)", opacity: 0.74, marginBottom: 10 }}>Lines worth returning to will gather here.</div>
              <div style={{ font: "400 13px/1.38 var(--font-ui)", color: "var(--nyan-text-secondary)", opacity: 0.62 }}>Long-press while reading to save a highlight or note.</div>
            </div>
          </div>
        ) : (
          <>
            {/* Context panel — reflects the active gesture when deleting */}
            <div style={{ background: "color-mix(in srgb, var(--nyan-primary) 3.5%, var(--nyan-surface))", borderRadius: 16, border: "0.6px solid color-mix(in srgb, var(--nyan-divider) 16%, transparent)", padding: "12px", display: "flex", gap: 12, alignItems: "center", marginBottom: 8 }}>
              <div style={{ width: 32, height: 32, borderRadius: 12, background: "color-mix(in srgb, var(--nyan-primary) 8%, var(--nyan-surface-muted))", display: "grid", placeItems: "center", flexShrink: 0 }}>
                <i className="ph ph-pencil-line" style={{ fontSize: 15, color: "var(--nyan-primary)", opacity: 0.88 }} />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ font: "600 15px/1.1 var(--font-ui)", color: "var(--nyan-text)", opacity: 0.86 }}>Reading notes</div>
                <div style={{ font: "400 12.5px/1.3 var(--font-ui)", color: "var(--nyan-text-secondary)", marginTop: 3, opacity: 0.72 }}>
                  {phase === "reveal" ? "Release to delete, or tap the card to cancel." : "Tap to return, long-press to edit, swipe left to delete."}
                </div>
              </div>
            </div>
            <div style={{ font: "600 11px/1 var(--font-ui)", color: "var(--nyan-text-secondary)", opacity: 0.56, letterSpacing: "0.9px", padding: "8px 4px 6px", textTransform: "uppercase", fontSize: 10.5 }}>2025.11.06</div>
            {phase === "removing" && <RemovingRow label="Removing highlight…" excerpt={HIGHLIGHTS[0].excerpt} />}
            {rows.map((hl, i) => <HighlightCard key={hl.id} hl={hl} revealed={phase === "reveal" && i === 0} />)}
          </>
        )}
        </div>
        {phase === "deleted" && (
          <NyanResponse placement="bottom" status="success" title="Highlight deleted" action={{ label: "Undo" }} />
        )}
      </div>
    </div>
  </Shell>
  );
};

/* ──────────────────────────────────────────────────────────────────────
   DESIGN CANVAS
   ────────────────────────────────────────────────────────────────────── */

/* ──────────────────────────────────────────────────────────────────────
   U9b · BOOKSHELF SELECT & DELETE (MULTI-SELECT EDIT MODE)
   Entered via long-press / “Select” — the Shelf Toolbar becomes a selection bar
   (Cancel · N selected · Select all), every cover/row gains a check, and a
   floating action bar offers Make Private / Export / Delete. Deleting routes
   through a destructive confirm sheet → a Deleting… progress response → an
   undoable “deleted” response. Works in grid + list, Cream + Sumi.
   ────────────────────────────────────────────────────────────────────── */
const SELECT_IDS = [0, 2];

const SelectCheck = ({ on, size = 24 }) => (
  <div style={{ width: size, height: size, borderRadius: "50%", flexShrink: 0, display: "grid", placeItems: "center",
    background: on ? "var(--nyan-select-fill)" : "color-mix(in srgb, var(--nyan-surface) 76%, transparent)",
    border: on ? "1.5px solid var(--nyan-select-fill)" : "1.5px solid color-mix(in srgb, var(--nyan-text) 30%, transparent)",
    boxShadow: on ? "0 1px 4px color-mix(in srgb, var(--nyan-select-fill) 40%, transparent)" : "0 1px 3px rgba(0,0,0,.12)",
    backdropFilter: "blur(3px)", WebkitBackdropFilter: "blur(3px)", transition: "all 140ms ease" }}>
    {on && (
      <svg width={Math.round(size * 0.62)} height={Math.round(size * 0.62)} viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" strokeWidth="3.4" strokeLinecap="round" strokeLinejoin="round" style={{ display: "block" }}>
        <path d="M5 12.5 L10 17.5 L19 7" />
      </svg>
    )}
  </div>
);

const SelectBookCard = ({ book, selected }) => (
  <div style={{ display: "flex", flexDirection: "column", gap: 6, cursor: "pointer" }}>
    <div style={{ position: "relative", width: "100%", aspectRatio: "120/156", borderRadius: 12,
      background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))",
      border: selected ? "2px solid var(--nyan-primary)" : "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)",
      boxShadow: selected ? "0 0 0 3px color-mix(in srgb, var(--nyan-primary) 16%, transparent)" : "none",
      display: "grid", placeItems: "center", overflow: "hidden", transition: "box-shadow 140ms ease, border-color 140ms ease" }}>
      <i className="ph ph-book-open" style={{ fontSize: 26, color: "var(--nyan-primary)" }} />
      <div style={{ position: "absolute", top: 6, right: 6, height: 17, padding: "0 6px", borderRadius: 999, background: "color-mix(in srgb, var(--nyan-surface) 88%, transparent)", border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)", display: "flex", alignItems: "center" }}>
        <span style={{ font: "600 9px/1 var(--font-ui)", color: "var(--nyan-primary-deep)" }}>{book.fmt}</span>
      </div>
      {selected && <div style={{ position: "absolute", inset: 0, background: "color-mix(in srgb, var(--nyan-primary) 12%, transparent)" }} />}
      <div style={{ position: "absolute", top: 7, left: 7 }}><SelectCheck on={selected} /></div>
    </div>
    {book.pct > 0 && (
      <div style={{ height: 3, borderRadius: 999, background: "color-mix(in srgb, var(--nyan-primary) 16%, var(--nyan-surface))", overflow: "hidden" }}>
        <div style={{ width: `${book.pct}%`, height: "100%", borderRadius: 999, background: "var(--nyan-primary)" }} />
      </div>
    )}
    <div>
      <div style={{ font: "600 12.5px/1.25 var(--font-ui)", color: "var(--nyan-text)", overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical" }}>{book.title}</div>
      <div style={{ font: "400 11px/1.3 var(--font-ui)", color: "var(--nyan-text-muted)", marginTop: 2, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{book.author}</div>
    </div>
  </div>
);

const SelectBookListRow = ({ book, selected }) => (
  <div style={{ position: "relative", display: "flex", alignItems: "center", gap: 12, padding: "10px 12px", minHeight: 44, cursor: "pointer",
    background: selected ? "color-mix(in srgb, var(--nyan-primary) 7%, transparent)" : "transparent", transition: "background 140ms ease" }}>
    <div style={{ position: "relative", width: 44, height: 58, flexShrink: 0 }}>
      <div style={{ width: "100%", height: "100%", borderRadius: "var(--r-chip)", background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))", border: selected ? "1.5px solid var(--nyan-primary)" : "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)", display: "grid", placeItems: "center" }}>
        <i className="ph ph-book-open" style={{ fontSize: 20, color: "var(--nyan-primary)" }} />
      </div>
      <div style={{ position: "absolute", top: 4, left: 4 }}><SelectCheck on={selected} size={20} /></div>
    </div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ font: "600 14px/1.25 var(--font-ui)", color: "var(--nyan-text)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{book.title}</div>
      <div style={{ font: "400 12px/1.3 var(--font-ui)", color: "var(--nyan-text-muted)", marginTop: 1, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{book.author}</div>
    </div>
    <div style={{ height: 18, padding: "0 7px", flexShrink: 0, borderRadius: 999, background: "var(--nyan-surface-muted)", border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)", display: "flex", alignItems: "center" }}>
      <span style={{ font: "600 9px/1 var(--font-ui)", color: "var(--nyan-primary-deep)" }}>{book.fmt}</span>
    </div>
  </div>
);

const SelectionHeader = ({ count }) => (
  <div style={{ padding: "14px 8px 8px", display: "flex", alignItems: "center", gap: 4, flexShrink: 0 }}>
    <button style={{ all: "unset", cursor: "pointer", width: 40, height: 40, borderRadius: "var(--r-control)", display: "grid", placeItems: "center", flexShrink: 0 }}>
      <i className="ph ph-x" style={{ fontSize: 22, color: "var(--nyan-text)" }} />
    </button>
    <div style={{ flex: 1, minWidth: 0, font: "600 18px/1.15 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.2px" }}>{count} selected</div>
    <button style={{ all: "unset", cursor: "pointer", height: 36, padding: "0 12px", borderRadius: "var(--r-chip)", display: "flex", alignItems: "center", gap: 6, font: "600 13px/1 var(--font-ui)", color: "var(--nyan-primary-deep)", background: "color-mix(in srgb, var(--nyan-primary) 10%, transparent)" }}>
      <i className="ph ph-list-checks" style={{ fontSize: 16 }} />
      Select all
    </button>
  </div>
);

const SelectActionBar = ({ count }) => {
  const actions = [
    { icon: "lock-simple", label: "Make Private" },
    { icon: "export",      label: "Export" },
    { icon: "trash",       label: "Delete", danger: true },
  ];
  const disabled = count === 0;
  return (
    <div style={{ position: "absolute", left: "var(--inset)", right: "var(--inset)", bottom: "var(--inset)",
      background: "var(--nyan-surface)", border: "1px solid var(--chrome-edge)", borderRadius: "var(--r-dock)",
      boxShadow: "var(--shadow-light-card)", padding: "7px 6px", display: "flex", opacity: disabled ? 0.5 : 1, zIndex: 40 }}>
      {actions.map((a, i) => (
        <React.Fragment key={a.label}>
          {i > 0 && <div style={{ width: "0.5px", alignSelf: "stretch", margin: "8px 0", background: "color-mix(in srgb, var(--nyan-divider) 40%, transparent)" }} />}
          <button style={{ all: "unset", cursor: "pointer", flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 5, padding: "8px 4px", borderRadius: 12 }}>
            <i className={`ph ph-${a.icon}`} style={{ fontSize: 22, color: a.danger ? "var(--error-primary)" : "var(--nyan-primary-deep)" }} />
            <span style={{ font: "500 11px/1 var(--font-ui)", color: a.danger ? "var(--error-primary)" : "var(--nyan-text-secondary)" }}>{a.label}</span>
          </button>
        </React.Fragment>
      ))}
    </div>
  );
};

const DeleteConfirmSheet = ({ count }) => (
  <div style={{ position: "absolute", inset: 0, zIndex: 50 }}>
    <div style={{ position: "absolute", inset: 0, background: "var(--scrim)", backdropFilter: "blur(var(--scrim-blur))", WebkitBackdropFilter: "blur(var(--scrim-blur))", animation: "nyanFade 220ms ease-out" }} />
    <div style={{ position: "absolute", left: "var(--inset)", right: "var(--inset)", bottom: "var(--inset)",
      background: "var(--nyan-surface)", border: "1px solid var(--chrome-edge)", borderRadius: "var(--r-sheet)",
      boxShadow: "var(--shadow-light-card)", overflow: "hidden", animation: "nyanSlideUp 280ms cubic-bezier(0.33,0.9,0.36,1)" }}>
      <div style={{ padding: "24px 20px 18px", display: "flex", flexDirection: "column", alignItems: "center", textAlign: "center" }}>
        <div style={{ width: 56, height: 56, borderRadius: "var(--r-card-nested)", background: "var(--error-bg)", border: "0.7px solid color-mix(in srgb, var(--error-primary) 22%, transparent)", display: "grid", placeItems: "center", marginBottom: 14 }}>
          <i className="ph ph-trash" style={{ fontSize: 26, color: "var(--error-primary)" }} />
        </div>
        <div style={{ font: "600 18px/1.25 var(--font-ui)", color: "var(--nyan-text)", marginBottom: 8 }}>Delete {count} books?</div>
        <div style={{ font: "400 13.5px/1.5 var(--font-ui)", color: "var(--nyan-text-secondary)", maxWidth: 282, textWrap: "pretty" }}>Their reading progress, bookmarks and notes are removed too. The source files on your device are kept.</div>
      </div>
      <div style={{ padding: "0 16px 16px", display: "flex", flexDirection: "column", gap: 10 }}>
        <button style={{ all: "unset", cursor: "pointer", boxSizing: "border-box", height: 50, borderRadius: 16, background: "var(--error-primary)", display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }}>
          <i className="ph ph-trash" style={{ fontSize: 18, color: "var(--nyan-surface)" }} />
          <span style={{ font: "600 15px/1 var(--font-ui)", color: "var(--nyan-surface)" }}>Delete {count} books</span>
        </button>
        <button style={{ all: "unset", cursor: "pointer", boxSizing: "border-box", height: 50, borderRadius: 16, background: "var(--nyan-surface-muted)", border: "1px solid var(--nyan-divider)", display: "grid", placeItems: "center", font: "600 15px/1 var(--font-ui)", color: "var(--nyan-text)" }}>Cancel</button>
      </div>
    </div>
  </div>
);

const BookshelfManage = ({ dark, view = "grid", phase = "select" }) => {
  const selecting = phase === "select" || phase === "confirm" || phase === "deleting";
  const items = BOOKS.concat(BOOKS).slice(0, 6).map((b, i) => ({ key: i, book: b, selected: SELECT_IDS.includes(i) }));
  const visible = phase === "deleted" ? items.filter(it => !it.selected) : items;
  const count = SELECT_IDS.length;
  return (
    <Shell dark={dark}>
      <div style={{ position: "relative", flex: 1, display: "flex", flexDirection: "column", minHeight: 0 }}>
        {phase === "deleted"
          ? <ShelfToolbar view={view} sort={false} onSearch={() => {}} />
          : <SelectionHeader count={count} />}
        <div style={{ flex: 1, overflowY: "auto", padding: "6px 16px 104px" }}>
          {view === "grid" ? (
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: "16px 12px" }}>
              {visible.map(it => (
                <div key={it.key} style={{ opacity: phase === "deleting" && it.selected ? 0.4 : 1, transition: "opacity 220ms ease" }}>
                  <SelectBookCard book={it.book} selected={selecting && it.selected} />
                </div>
              ))}
            </div>
          ) : (
            <div style={{ background: "var(--nyan-surface)", borderRadius: 16, border: "1px solid var(--chrome-edge)", boxShadow: "var(--shadow-grouped)", overflow: "hidden" }}>
              {visible.map((it, idx) => (
                <React.Fragment key={it.key}>
                  {idx > 0 && <div style={{ height: "0.5px", background: "color-mix(in srgb, var(--nyan-divider) 34%, transparent)", margin: "0 12px" }} />}
                  <div style={{ opacity: phase === "deleting" && it.selected ? 0.4 : 1, transition: "opacity 220ms ease" }}>
                    <SelectBookListRow book={it.book} selected={selecting && it.selected} />
                  </div>
                </React.Fragment>
              ))}
            </div>
          )}
        </div>
        {phase === "select"   && <SelectActionBar count={count} />}
        {phase === "confirm"  && <DeleteConfirmSheet count={count} />}
        {phase === "deleting" && <NyanResponse placement="bottom" status="loading" title={`Deleting ${count} books…`} />}
        {phase === "deleted"  && <NyanResponse placement="bottom" status="success" title={`${count} books deleted`} action={{ label: "Undo" }} />}
      </div>
    </Shell>
  );
};

/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, { BOOKS, BookCard, ContinueCard, BookListRow, BookshelfHome, SEARCH_RECENT, SEARCH_SUGGEST, SearchField, SearchChip, BookshelfSearch, BookDetails, IMPORT_QUEUE, ImportFileRow, ImportSheet, RemovingRow, BOOKMARKS, BookmarkCard, BookmarkList, HL_COLORS, HIGHLIGHTS, HighlightCard, NotesList, SELECT_IDS, SelectCheck, SelectBookCard, SelectBookListRow, SelectionHeader, SelectActionBar, DeleteConfirmSheet, BookshelfManage });
