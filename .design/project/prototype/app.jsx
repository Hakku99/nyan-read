/* ============================================================================
   Nyan Read — Interactive Reader Prototype (app)
   Assembles the compiled design-system kit (incl. the new P2 components) into a
   working multi-screen reader: Bookshelf → Reader → selection / highlight,
   the One Paper dock (chapters · settings · TTS), a confirm dialog, and the
   full-screen privacy-PIN gate. Everything reads from window.<Namespace>,
   flattened onto window by the host page.
   ============================================================================ */
const { useState, useEffect, useRef } = React;

/* ── Sample content ─────────────────────────────────────────────────────── */
const BOOKS = [
  { id: 1, title: "The Stillwater Diaries", author: "Matsuno Eri", fmt: "EPUB", pct: 42 },
  { id: 2, title: "Borrowed Light", author: "Yuen Lai-Ying", fmt: "TXT", pct: 0 },
  { id: 3, title: "A Long Slope Down", author: "Park Hyun-joo", fmt: "PDF", pct: 88 },
  { id: 4, title: "Sand and Memoir", author: "Aria Okonkwo", fmt: "EPUB", pct: 12 },
  { id: 5, title: "The Paper Garden", author: "Lin Shuhua", fmt: "EPUB", pct: 0 },
  { id: 6, title: "Quiet as Kept", author: "Devorah Reyes", fmt: "TXT", pct: 64 },
];
const CHAPTERS = [
  "I · The Threshold", "II · A Cup of Still Water", "III · The Bell and the Rain",
  "IV · Lacquer and Alcove", "V · Wisteria", "VI · The Long Slope",
  "VII · Borrowed Light", "VIII · What the River Kept",
];
const PROSE = [
  "The cat sat on the threshold for a long while, watching the rain decide what kind of evening it would be. Inside, the kettle had gone quiet, and the lamp made a small amber country of the desk.",
  "She would sometimes say that of all the noises in the city, only the bell and the rain felt honest. The trams, the merchants, the cries of the gulls upriver — all of them were asking for something.",
  "He set the lacquer cup down on the low table and looked, again, at the calligraphy hanging in the alcove. It had been there so long he no longer read it; it had become a kind of weather.",
  "Some things are better held at arm's length, like a wet umbrella indoors. She turned the page the way one steps onto old wood — slowly, listening for what it would say.",
];

/* readerTheme id → [background, ink, sumi-scope?] */
const READER_THEME = {
  cream:    ["var(--reader-bg-cream)", "var(--reader-ink)", false],
  sepia:    ["var(--reader-bg-sepia)", "var(--reader-ink-sepia)", false],
  sumi:     ["var(--reader-bg-sumi)", "var(--reader-ink-sumi)", true],
  charcoal: ["var(--reader-bg-charcoal)", "var(--reader-ink-charcoal)", true],
};

const DEFAULT_PREFS = {
  brightness: 78, autoBrightness: false, warmth: "low", pageTurn: "tap",
  fontSize: 18, lineHeight: 1.75, serif: true, readerTheme: "cream",
};

const STORE = "nyan-proto-v1";
const load = () => { try { return JSON.parse(localStorage.getItem(STORE)) || {}; } catch (e) { return {}; } };
const save = (patch) => { try { localStorage.setItem(STORE, JSON.stringify({ ...load(), ...patch })); } catch (e) {} };

/* ── Bookshelf screen ───────────────────────────────────────────────────── */
function Bookshelf({ onOpenBook, onLock, onImport }) {
  const persisted = load();
  const [query, setQuery] = useState("");
  const [view, setView] = useState(persisted.view || "grid");
  const [collapsed, setCollapsed] = useState(false);
  const [confirmBook, setConfirmBook] = useState(null);
  const [toast, setToast] = useState(null);

  useEffect(() => { save({ view }); }, [view]);

  const q = query.trim().toLowerCase();
  const list = q ? BOOKS.filter(b => (b.title + " " + b.author).toLowerCase().includes(q)) : BOOKS;
  const cont = BOOKS[0];

  return (
    <div className="screen">
      <NyanPageHeader
        title="Bookshelf"
        subtitle={`${BOOKS.length} books · sorted by recent`}
        actions={
          <div style={{ display: "flex", gap: 4 }}>
            <Icon name="lock" size={20} color="var(--nyan-text)" aria-label="Privacy shelf" onClick={onLock} />
          </div>
        }
      />
      <div style={{ padding: "0 16px 12px", display: "flex", flexDirection: "column", gap: 12 }}>
        <SearchField value={query} onChange={setQuery} placeholder="Search your shelf" />
        <SegmentedTabControl
          style="subtle"
          selected={view === "grid" ? 0 : 1}
          onChange={(i) => setView(i === 0 ? "grid" : "list")}
          tabs={[{ label: "Grid" }, { label: "List" }]}
        />
      </div>

      <div style={{ flex: 1, overflowY: "auto", padding: "0 16px 96px" }}>
        {!q && (
          <div style={{ marginBottom: 16 }}>
            <NyanContinueReadingCard
              book={{ title: cont.title, author: cont.author, progress: cont.pct / 100 }}
              collapsed={collapsed}
              onToggleCollapse={() => setCollapsed(c => !c)}
              onContinue={() => onOpenBook(cont)}
            />
          </div>
        )}
        {list.length === 0 ? (
          <NyanEmptyState icon="search" title={`No books match “${query.trim()}”`} description="Try a different title or author name." />
        ) : view === "grid" ? (
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: "16px 12px" }}>
            {list.map(b => (
              <NyanBookGridCard key={b.id} book={b} onPress={() => onOpenBook(b)} onLongPress={() => setConfirmBook(b)} />
            ))}
          </div>
        ) : (
          <NyanRowGroup>
            {list.map(b => <BookListRow key={b.id} book={b} onPress={() => onOpenBook(b)} />)}
          </NyanRowGroup>
        )}
      </div>

      <div style={{ position: "absolute", right: 16, bottom: 26, zIndex: 20 }}>
        <NyanFAB icon="add" onPress={() => { onImport ? onImport() : setToast("import"); }} />
      </div>

      {toast === "import" && (
        <NyanResponse
          placement="bottom" status="info" title="Import a book"
          description="Browse .txt, .epub or .pdf from your device."
          action={{ label: "Done", onPress: () => setToast(null) }}
          onDismiss={() => setToast(null)}
        />
      )}

      <NyanDialog
        open={!!confirmBook}
        tone="danger"
        icon="delete"
        title="Delete this book?"
        message={confirmBook ? `“${confirmBook.title}” will be removed from this device.` : ""}
        confirmLabel="Delete"
        onClose={() => setConfirmBook(null)}
        onCancel={() => setConfirmBook(null)}
        onConfirm={() => setConfirmBook(null)}
      />
    </div>
  );
}

/* ── Reader screen ──────────────────────────────────────────────────────── */
function Reader({ book, onExit }) {
  const persisted = load();
  const [prefs, setPrefs] = useState({ ...DEFAULT_PREFS, ...(persisted.prefs || {}) });
  const [chapter, setChapter] = useState(persisted.chapter != null ? persisted.chapter : 1);
  const [immersive, setImmersive] = useState(false);    // true = chrome hidden
  const [sheet, setSheet] = useState(null);             // chapters | settings | highlights | bookmarks
  const [tab, setTab] = useState(2);                    // settings tab (Theme default)
  const [sel, setSel] = useState(null);                 // selected paragraph index
  const [pen, setPen] = useState(null);
  const [tts, setTts] = useState(false);
  const [find, setFind] = useState(false);
  const [findQ, setFindQ] = useState("");
  const [toast, setToast] = useState(null);
  const [playing, setPlaying] = useState(false);
  const [ttsProg, setTtsProg] = useState(0.3);
  const [speed, setSpeed] = useState(1);

  useEffect(() => { save({ prefs }); }, [prefs]);
  useEffect(() => { save({ chapter }); }, [chapter]);

  const [bg, ink, sumi] = READER_THEME[prefs.readerTheme] || READER_THEME.cream;
  const dim = prefs.autoBrightness ? 1 : 0.5 + (prefs.brightness / 100) * 0.5;
  const sheetOpen = !!sheet;

  const sheetTitle = { chapters: "Chapters", settings: "Display", highlights: "Highlights", bookmarks: "Bookmarks" }[sheet];

  const closeAll = () => { setSheet(null); setSel(null); };

  return (
    <div
      data-theme={sumi ? "sumi" : undefined}
      className="screen"
      style={{ background: bg, paddingTop: 0, position: "relative" }}
      onClick={() => { if (sel) setSel(null); else if (!sheetOpen && !tts && !find) setImmersive(v => !v); }}
    >
      {/* brightness veil */}
      <div style={{ position: "absolute", inset: 0, background: "#000", opacity: 1 - dim, pointerEvents: "none", zIndex: 30, transition: "opacity 200ms ease" }} />

      {/* Top bar */}
      {find ? (
        <div style={{ paddingTop: 50, zIndex: 35, position: "relative" }} onClick={e => e.stopPropagation()}>
          <InBookSearch
            value={findQ} onChange={setFindQ}
            matchIndex={2} matchCount={findQ ? 17 : 0}
            onClose={() => { setFind(false); setFindQ(""); }}
          />
        </div>
      ) : (
        <div style={{
          paddingTop: 50, padding: "50px 8px 8px", display: "flex", alignItems: "center", gap: 4,
          opacity: immersive ? 0 : 1, transform: immersive ? "translateY(-8px)" : "none",
          transition: "opacity 240ms var(--ease-paper), transform 240ms var(--ease-paper)",
          pointerEvents: immersive ? "none" : "auto", position: "relative", zIndex: 35,
        }} onClick={e => e.stopPropagation()}>
          <button onClick={onExit} aria-label="Back" style={{ all: "unset", cursor: "pointer", width: 40, height: 40, borderRadius: "var(--r-control)", display: "grid", placeItems: "center" }}>
            <Icon name="arrow_back" size={22} color={ink} />
          </button>
          <div style={{ flex: 1, minWidth: 0, font: "600 14px/1.2 var(--font-ui)", color: ink, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{book ? book.title : "The Stillwater Diaries"}</div>
          <button onClick={() => setFind(true)} aria-label="Find in book" style={{ all: "unset", cursor: "pointer", width: 40, height: 40, borderRadius: "var(--r-control)", display: "grid", placeItems: "center" }}>
            <Icon name="search" size={21} color={ink} />
          </button>
          <button onClick={() => setTts(true)} aria-label="Read aloud" style={{ all: "unset", cursor: "pointer", width: 40, height: 40, borderRadius: "var(--r-control)", display: "grid", placeItems: "center" }}>
            <Icon name="user-sound" size={21} color={ink} />
          </button>
        </div>
      )}

      {/* Canvas */}
      <div style={{ flex: 1, overflowY: "auto", padding: "8px 26px 160px", position: "relative", zIndex: 10 }}>
        <div style={{ font: "500 12px/1 var(--font-ui)", letterSpacing: "1.5px", textTransform: "uppercase", color: ink, opacity: 0.5, margin: "8px 0 20px" }}>{CHAPTERS[chapter]}</div>
        {PROSE.map((p, i) => (
          <div key={i} onClick={(e) => { e.stopPropagation(); setSel(i === sel ? null : i); }} style={{ cursor: "text", borderRadius: 6, background: pen && sel === i ? "transparent" : "transparent" }}>
            <ReaderParagraph serif={prefs.serif} fontSize={prefs.fontSize} lineHeight={prefs.lineHeight} color={ink}>
              {p}
            </ReaderParagraph>
          </div>
        ))}
      </div>

      {/* Selection menu */}
      {sel != null && (
        <div style={{ position: "absolute", left: 0, right: 0, bottom: 150, display: "flex", justifyContent: "center", zIndex: 48 }} onClick={e => e.stopPropagation()}>
          <TextSelectionMenu
            selectedPen={pen}
            onSelectPen={(id) => { setPen(id); setSel(null); setToast("highlight"); }}
            onAction={(k) => { setSel(null); setToast(k); }}
          />
        </div>
      )}

      {/* One Paper dock */}
      <div onClick={e => e.stopPropagation()}>
        <OnePaperDock
          visible={!immersive && !tts}
          sheetOpen={sheetOpen}
          title={sheetTitle}
          meta={sheet === "chapters" ? `${chapter + 1} / ${CHAPTERS.length}` : undefined}
          chapterIndex={chapter}
          chapterCount={CHAPTERS.length}
          progress={(chapter + 0.4) / CHAPTERS.length}
          activeAction={sheet}
          onAction={(k) => setSheet(s => s === k ? null : k)}
          onPrevChapter={() => setChapter(c => Math.max(0, c - 1))}
          onNextChapter={() => setChapter(c => Math.min(CHAPTERS.length - 1, c + 1))}
        >
          {sheet === "chapters" && (
            <ReaderChapterList chapters={CHAPTERS} currentIndex={chapter} onSelect={(i) => { setChapter(i); setSheet(null); }} />
          )}
          {sheet === "settings" && (
            <ReaderSettingsBody t={prefs} setT={setPrefs} tab={tab} setTab={setTab} />
          )}
          {sheet === "highlights" && (
            <div style={{ paddingBottom: 8 }}>
              <NyanBookmarkCard label="Chapter 3 · 42%" excerpt="only the bell and the rain felt honest" note="The hinge of the whole chapter." />
              <div style={{ height: 8 }} />
              <NyanEmptyState icon="highlighter" title="That's everything" description="Long-press any line to add a highlight." />
            </div>
          )}
          {sheet === "bookmarks" && (
            <div style={{ paddingBottom: 8 }}>
              <NyanBookmarkCard label="Chapter 2 · 18%" excerpt="watching the rain decide what kind of evening it would be" />
            </div>
          )}
        </OnePaperDock>
      </div>

      {/* TTS sheet */}
      <NyanBottomSheet open={tts} onClose={() => setTts(false)}>
        <TTSPlayer
          chapter={CHAPTERS[chapter]}
          playing={playing} onTogglePlay={() => setPlaying(p => !p)}
          progress={ttsProg} onSeek={setTtsProg} elapsed="2:14" remaining="7:30"
          speedIndex={speed} onSpeed={setSpeed}
          onSkipBack={() => setChapter(c => Math.max(0, c - 1))}
          onSkipForward={() => setChapter(c => Math.min(CHAPTERS.length - 1, c + 1))}
        />
      </NyanBottomSheet>

      {/* toasts */}
      {toast && (
        <NyanResponse
          placement="bottom"
          status={toast === "highlight" ? "success" : "info"}
          title={toast === "highlight" ? "Highlight saved" : toast === "copy" ? "Copied to clipboard" : "Searching the book"}
          onDismiss={() => setToast(null)}
        />
      )}
      {toast && <Dismisser onDone={() => setToast(null)} />}
    </div>
  );
}

/* auto-dismiss helper for toasts */
function Dismisser({ onDone }) {
  useEffect(() => { const t = setTimeout(onDone, 1900); return () => clearTimeout(t); }, []);
  return null;
}

/* ── Privacy PIN gate ───────────────────────────────────────────────────── */
function PinGate({ onUnlock, onCancel }) {
  const [digits, setDigits] = useState([]);
  const [error, setError] = useState(false);
  const fg = "#E8E1D5";
  useEffect(() => {
    if (digits.length === 4) {
      const ok = digits.join("") === "1234";
      const t = setTimeout(() => { ok ? onUnlock() : (setError(true), setDigits([])); }, 240);
      return () => clearTimeout(t);
    }
  }, [digits]);
  return (
    <div data-theme="sumi" style={{ position: "absolute", inset: 0, zIndex: 90, background: "#1D211E", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", paddingTop: 50 }}>
      <button onClick={onCancel} aria-label="Cancel" style={{ all: "unset", cursor: "pointer", position: "absolute", top: 60, right: 18, width: 44, height: 44, display: "grid", placeItems: "center" }}>
        <Icon name="close" size={22} color="color-mix(in srgb, #E8E1D5 52%, transparent)" />
      </button>
      <div style={{ width: 56, height: 56, borderRadius: "var(--r-card-nested)", background: "color-mix(in srgb, #E8E1D5 12%, transparent)", display: "grid", placeItems: "center", marginBottom: 22 }}>
        <Icon name="lock" size={26} color={fg} />
      </div>
      <div style={{ font: "500 20px/1.2 var(--font-ui)", color: fg, letterSpacing: "0.4px", marginBottom: error ? 16 : 40 }}>Enter PIN</div>
      {error && <div style={{ font: "400 13px/1.3 var(--font-ui)", color: "color-mix(in srgb, #E8E1D5 52%, transparent)", marginBottom: 20 }}>Incorrect PIN — try 1234</div>}
      <div style={{ marginBottom: 44 }}><PinDots count={digits.length} hasError={error} dotColor={fg} /></div>
      <PinPad keyColor={fg}
        onDigit={(d) => setDigits(p => p.length < 4 ? [...p, d] : p)}
        onDelete={() => { setDigits(p => p.slice(0, -1)); setError(false); }} />
    </div>
  );
}

/* ── App shell ──────────────────────────────────────────────────────────── */
function App() {
  const persisted = load();
  const [screen, setScreen] = useState(persisted.screen || "shelf");
  const [book, setBook] = useState(null);
  const [pin, setPin] = useState(false);

  const go = (s) => { setScreen(s); save({ screen: s }); };

  return (
    <div className="phone">
      <div className="notch" />
      <div className="statusbar">
        <span>9:41</span>
        <span className="dnd"><i className="ph ph-moon" style={{ fontSize: 13 }} /> 喵阅</span>
        <span style={{ display: "inline-flex", gap: 5, alignItems: "center" }}>
          <i className="ph ph-cell-signal-full" style={{ fontSize: 15 }} />
          <i className="ph ph-wifi-high" style={{ fontSize: 15 }} />
          <i className="ph-fill ph-battery-medium" style={{ fontSize: 16 }} />
        </span>
      </div>

      {screen === "shelf" && (
        <Bookshelf
          onOpenBook={(b) => { setBook(b); go("reader"); }}
          onLock={() => setPin(true)}
        />
      )}
      {screen === "reader" && (
        <Reader book={book} onExit={() => go("shelf")} />
      )}

      {pin && <PinGate onUnlock={() => setPin(false)} onCancel={() => setPin(false)} />}

      <div className="home-ind" />
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
