/* ============================================================================
   Nyan Read — Screens: U4 Reader Menu · U5 Text Selection Menu · U7 Splash · U8 Reader Error
   ----------------------------------------------------------------------------
   Full-screen compositions assembled from components/*. Extracted verbatim from
   the bundle gallery so Claude Code can read/edit one screen without the HTML.
   Self-exports to window; the bundle HTML imports this then renders the gallery.
   ============================================================================ */

const { useState, useRef, useEffect } = React;

/* ── shared helpers ──────────────────────────────────────────────────── */


/* ──────────────────────────────────────────────────────────────────────
   U4 · READER MENU — strictly the One Paper reader dock, grown into the
   Reading Settings sheet. Renders the SHARED ReaderSettingsBody (the same
   Display / Text / Theme controls the live kit dock uses), under the dock
   header, with the dock footer (progress + chapter stepper + 3 actions)
   pinned below and the page receded under a warm scrim + blur.
   Replaces the old bespoke Pill + DisplayPanel + TextPanel + ThemePanel +
   ReaderMenuSheet — all of that now lives once, in components.jsx.
   ────────────────────────────────────────────────────────────────────── */
/* Per-tab factory defaults for the Reading Settings sheet. The header "Reset"
   control restores only the fields owned by the tab you're looking at — Display
   resets brightness/warmth/page-turn, Text resets size/spacing/family, Theme
   resets the reading theme. There is no separate footer "Reset to defaults"
   button under the Theme options; the header per-tab reset is the only reset. */
const U4_DEFAULTS = (dark) => ({
  brightness: 70, autoBrightness: true, warmth: "low", pageTurn: "tap",
  fontSize: 18, lineHeight: 1.75, serif: false, readerTheme: dark ? "sumi" : "cream",
});
const U4_TAB_FIELDS = [
  ["brightness", "autoBrightness", "warmth", "pageTurn"], // Display
  ["fontSize", "lineHeight", "serif"],                    // Text
  ["readerTheme"],                                        // Theme
];
const U4_TAB_NAMES = ["Display", "Text", "Theme"];

const ResetTabButton = ({ tab, onReset }) => (
  <button
    onClick={onReset}
    title={`Reset ${U4_TAB_NAMES[tab]} settings to defaults`}
    style={{
      all: "unset", cursor: "pointer", boxSizing: "border-box",
      display: "inline-flex", alignItems: "center", gap: 5,
      height: 30, padding: "0 2px", borderRadius: "var(--r-chip)",
      background: "transparent",
      color: "var(--nyan-primary-deep)", font: "500 12.5px/1 var(--font-ui)",
      transition: "opacity 160ms var(--ease-paper)",
    }}
  >
    <i className="ph ph-arrow-counter-clockwise" style={{ fontSize: 14 }} />
    Reset {U4_TAB_NAMES[tab]}
  </button>
);

const U4ReaderDock = ({ dark, initTab = 0 }) => {
  const [t, setT] = useState({
    brightness: 62, autoBrightness: false, warmth: "medium", pageTurn: "tap",
    fontSize: 18, lineHeight: 1.75, serif: false, readerTheme: dark ? "sumi" : "cream",
  });
  const [tab, setTab] = useState(initTab);
  const [curIndex, setCurIndex] = useState(3);
  const TOTAL = 18;
  const resetCurrentTab = () => {
    const defaults = U4_DEFAULTS(dark);
    const fields = U4_TAB_FIELDS[tab];
    setT((prev) => {
      const next = { ...prev };
      fields.forEach((f) => { next[f] = defaults[f]; });
      return next;
    });
  };
  return (
    <React.Fragment>
      <div style={{ position: "absolute", inset: 0, zIndex: 8, background: "var(--scrim)",
        backdropFilter: "blur(var(--scrim-blur))", WebkitBackdropFilter: "blur(var(--scrim-blur))" }} />
      <OnePaperDock
        visible
        sheetOpen
        title="Reading Settings"
        meta={<ResetTabButton tab={tab} onReset={resetCurrentTab} />}
        maxSheetHeight={470}
        chapterIndex={curIndex}
        chapterCount={TOTAL}
        progress={0.42}
        activeAction="settings"
        onAction={() => {}}
        onPrevChapter={() => setCurIndex((i) => Math.max(0, i - 1))}
        onNextChapter={() => setCurIndex((i) => Math.min(TOTAL - 1, i + 1))}
        onStopProp={false}
      >
        <ReaderSettingsBody t={t} setT={setT} tab={tab} setTab={setTab} />
      </OnePaperDock>
    </React.Fragment>
  );
};

const U4Artboard = ({ dark, tab }) => (
  <ReaderBg dark={dark}>
    <U4ReaderDock dark={dark} initTab={tab} />
  </ReaderBg>
);


/* ──────────────────────────────────────────────────────────────────────
   U5 · TEXT SELECTION MENU
   Corrective: replaces Material elevation+grey with --nyan-surface card
   ────────────────────────────────────────────────────────────────────── */
const HL_DOTS = ["#D8C06B","#A9C08E","#7FABAC","#CDA2A8","#DBB686"];
const TextSelectionMenu = ({ dark }) => (
  <div data-theme={dark ? "sumi" : undefined} style={{
    display: "inline-flex", alignItems: "center",
    background: "var(--nyan-surface)",
    borderRadius: 16,
    border: "1px solid var(--chrome-edge)",
    boxShadow: "var(--shadow-light-card)",
    padding: "6px 8px",
    gap: 4,
  }}>
    {[["ph-copy","Copy"],["ph-magnifying-glass","Search"]].map(([ic, label]) => (
      <button key={label} style={{ all: "unset", cursor: "pointer", display: "flex", flexDirection: "column", alignItems: "center", gap: 3, padding: "6px 10px", borderRadius: "var(--r-chip)" }}>
        <i className={`ph ${ic}`} style={{ fontSize: 18, color: "var(--nyan-primary)" }} />
        <span style={{ font: "400 10px/1 var(--font-ui)", color: "var(--nyan-text-muted)" }}>{label}</span>
      </button>
    ))}
    <div style={{ width: "0.72px", height: 32, background: "color-mix(in srgb, var(--nyan-divider) 60%, transparent)", flexShrink: 0, margin: "0 2px" }} />
    {HL_DOTS.map((c, i) => (
      <button key={i} title={["Yellow","Green","Blue","Pink","Orange"][i]} style={{ all: "unset", cursor: "pointer", width: 32, height: 32, borderRadius: "50%", display: "grid", placeItems: "center" }}>
        <div style={{ width: 22, height: 22, borderRadius: "50%", background: c, border: "1.5px solid color-mix(in srgb, var(--nyan-surface) 80%, transparent)", boxShadow: "0 1px 3px rgba(0,0,0,0.10)" }} />
      </button>
    ))}
  </div>
);

const U5Artboard = ({ dark }) => (
  <ReaderBg dark={dark}>
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      {/* Highlighted excerpt */}
      <div style={{ maxWidth: 290, font: "400 15px/1.6 var(--font-ui)", color: dark ? "#E2E2E2" : "#4A453E", textAlign: "center" }}>
        <span style={{ background: "#D8C06B80", borderRadius: 3, padding: "1px 0" }}>
          only the bell and the rain felt honest
        </span>
      </div>
      <div style={{ transform: "translateY(-4px)" }}>
        <TextSelectionMenu dark={dark} />
      </div>
    </div>
  </ReaderBg>
);


/* ──────────────────────────────────────────────────────────────────────
   U6 · PIN OVERLAY (SECURE ENTRY DIALOG)
   Corrective: scrim is rgba(0,0,0,0.32) NOT Colors.black87 (0.87)
               No pure black — all surfaces use --nyan tokens
   ────────────────────────────────────────────────────────────────────── */
/* ──────────────────────────────────────────────────────────────────────
   U6 · REMOVED — PIN entry is consolidated into the full-screen privacy gate
   (U16, Bundle 4). A reading-app lock is a security boundary, so it should be
   an unmistakable full-screen takeover, not a dismissible dialog. One PIN UI,
   not two.
   ────────────────────────────────────────────────────────────────────── */

/* ──────────────────────────────────────────────────────────────────────
   U7 · SPLASH PAGE
   Corrective: Colors.white + PNG cover → --nyan-bg cream + logo-line.svg
   ────────────────────────────────────────────────────────────────────── */
/* ──────────────────────────────────────────────────────────────────────
   U7 · SPLASH PAGE  —  rebuilt to speak One Paper
   The launch screen now obeys the reader-chrome doctrine: cream paper page,
   one floating "paper" tile (surface · radius 28 · single soft lift) holding
   the brand mark, matcha as the only raised voice, concentric radii, and the
   paper-soft fade. Nothing is welded to the edge; nothing is pure white.
   ────────────────────────────────────────────────────────────────────── */
const SplashScreen = ({ stage = "loaded", markSrc }) => <NyanSplash loading={stage === "loading"} markSrc={markSrc} />;
const U7Artboard = ({ stage, markSrc }) => <SplashScreen stage={stage} markSrc={markSrc} />;


/* ──────────────────────────────────────────────────────────────────────
   U8 · READER ERROR VIEW
   Uses --error-* tokens; mascot placeholder; expandable tech details
   ────────────────────────────────────────────────────────────────────── */
const ERROR_TYPES = {
  fileNotFound:  { icon: "compass",        title: "This book lost its way",     body: "The file can't be found — it may have been moved or deleted.", retry: false },
  parseFailed:   { icon: "warning-circle", title: "These pages are stuck together", body: "We couldn't open this file. It might be corrupted.",           retry: true  },
  unsupported:   { icon: "file-dashed",    title: "Nyan can't read this format",  body: "This file type isn't supported yet.",                          retry: false },
};

const ErrorView = ({ dark, type = "fileNotFound" }) => {
  const [details, setDetails] = useState(false);
  const e = ERROR_TYPES[type];

  return (
    <div data-theme={dark ? "sumi" : undefined}
      style={{ width: "100%", height: "100%", background: "var(--nyan-bg)", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", textAlign: "center", padding: "32px 28px" }}>

      {/* Calm circular icon-wash — same language as the shelf / bookmarks / notes empty states,
         tinted with the on-brand warm-clay error accent rather than matcha. */}
      <div style={{ width: 84, height: 84, borderRadius: "50%", background: "color-mix(in srgb, var(--error-primary) 8%, var(--nyan-surface))", border: "0.7px solid color-mix(in srgb, var(--error-primary) 22%, transparent)", display: "grid", placeItems: "center", marginBottom: 18 }}>
        <i className={`ph ph-${e.icon}`} style={{ fontSize: 36, color: "var(--error-primary)", opacity: 0.82 }} />
      </div>

      {/* Title + body — ink hierarchy, calm (not alarming red) */}
      <div style={{ font: "600 18px/1.25 var(--font-ui)", color: "var(--nyan-text)", opacity: 0.84, marginBottom: 8 }}>{e.title}</div>
      <div style={{ font: "400 14px/1.5 var(--font-ui)", color: "var(--nyan-text-secondary)", opacity: 0.74, maxWidth: 268, textWrap: "pretty", marginBottom: 26 }}>{e.body}</div>

      {/* Actions — shared buttons: Retry primary (matcha), Back ghost */}
      <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 10 }}>
        <NyanPrimaryButton label="Back to Bookshelf" variant="ghost" icon="arrow_back" />
        {e.retry && <NyanPrimaryButton label="Retry" variant="primary" icon="arrow_clockwise" />}
      </div>

      {/* Report link — quiet ghost */}
      <button style={{ all: "unset", cursor: "pointer", height: 44, marginTop: 6, padding: "0 14px", display: "flex", alignItems: "center", gap: 7, font: "500 13px/1 var(--font-ui)", color: "var(--nyan-text-muted)" }}>
        <i className="ph ph-bug-beetle" style={{ fontSize: 15 }} />
        Report to developer
      </button>

      {/* Tech details */}
      {type === "parseFailed" && (
        <div style={{ marginTop: 10, width: "100%", maxWidth: 320 }}>
          <button onClick={() => setDetails(d => !d)} style={{ all: "unset", cursor: "pointer", font: "400 12px/1.2 var(--font-ui)", color: "var(--nyan-text-muted)", display: "block", textAlign: "center", width: "100%", paddingBottom: 10 }}>
            {details ? "Hide technical details" : "Show technical details"}
          </button>
          {details && (
            <div style={{ background: "var(--nyan-surface-muted)", borderRadius: 12, border: "1px solid var(--nyan-divider)", padding: 12, textAlign: "left" }}>
              <pre style={{ margin: 0, font: "400 10.5px/1.5 var(--font-mono)", color: "var(--nyan-text-secondary)", whiteSpace: "pre-wrap", wordBreak: "break-all" }}>{`EpubException: Unexpected token at byte 0x2F4A\n  at EpubParser.parse (epub_parser.dart:184)\n  at ReaderEngine.loadBook (reader_engine.dart:62)`}</pre>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

const U8Artboard = ({ dark, type }) => <ErrorView dark={dark} type={type} />;


/* ──────────────────────────────────────────────────────────────────────
   DESIGN CANVAS
   ────────────────────────────────────────────────────────────────────── */

/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, { U4ReaderDock, U4Artboard, HL_DOTS, TextSelectionMenu, U5Artboard, SplashScreen, U7Artboard, ERROR_TYPES, ErrorView, U8Artboard });
