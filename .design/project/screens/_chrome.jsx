/* ============================================================================
   Nyan Read — Screen chrome (shared)
   ----------------------------------------------------------------------------
   Everything the gallery screens share: theme application, the flat-paper
   reader backdrop, the app Shell, the section/page/row scaffold helpers, the
   toggle, and the presentational splash. ONE canonical copy of each — load
   this BEFORE any screens/*.jsx file. Self-exports to window.

   Scaffold helpers (PageHdr / SectionHdr / RowGroup / ListRow) are gallery-
   level compositions, richer than the kit atoms (icon tiles, chevrons, indent).
   Their Flutter equivalents are the kit family: NyanPageHeader /
   NyanSectionHeader / NyanRowGroup + NyanListRow. NyanToggle delegates to the
   kit NyanSwitch so there is a single switch implementation.
   All radii/sizes here are snapped to the One Paper scale (--r-control 14,
   --r-chip 12, eyebrow caption 11px).
   ============================================================================ */

const { useState, useEffect, useRef } = React;

/* Canonical reader sample prose (was READER_SAMPLE / READER_PROSE). */
const READER_SAMPLE = "The cat sat on the threshold for a long while, watching the rain darken the stones and the wisteria release its scent into the late spring evening. She would sometimes say that of all the noises in the city, only the bell and the rain felt honest. He set the lacquer cup down on the low table and looked, again, at the calligraphy hanging in the alcove. It would be tactless, he decided, to mention this to anyone.";
const READER_PROSE = READER_SAMPLE; // back-compat alias

/* Applies data-theme="sumi" so all --nyan-* vars cascade correctly. */
const ThemeWrap = ({ dark, children }) => (
  <div data-theme={dark ? "sumi" : undefined} style={{ width: "100%", height: "100%" }}>
    {children}
  </div>
);

/* Flat-paper reader backdrop with receded prose. Sets its own theme so it
   works with or without an outer ThemeWrap. */
const ReaderBg = ({ dark, children }) => (
  <div data-theme={dark ? "sumi" : undefined}
    style={{ position: "relative", width: "100%", height: "100%",
      background: dark ? "#262422" : "#F7F5EF", overflow: "hidden" }}>
    <div style={{ position: "absolute", inset: 0, padding: "44px 28px 24px", pointerEvents: "none", overflow: "hidden" }}>
      <div style={{ font: "400 13.5px/1.85 var(--font-ui)", color: dark ? "#E5DED3" : "#4A453E", opacity: 0.55, textIndent: "2em" }}>
        {READER_SAMPLE}
      </div>
    </div>
    {children}
  </div>
);

/* Plain themed app surface (column flex). `noPad` accepted for back-compat. */
const Shell = ({ dark, children, noPad }) => (
  <div data-theme={dark ? "sumi" : undefined}
    style={{ width: "100%", height: "100%", background: "var(--nyan-bg)",
      position: "relative",
      display: "flex", flexDirection: "column", overflow: "hidden" }}>
    {children}
  </div>
);

/* ── Page header (back · title · subtitle · actions) ─────────────────────── */
const PageHdr = ({ title, subtitle, actions, back = true }) => (
  <div style={{ padding: "16px 12px 12px", display: "flex", alignItems: subtitle ? "flex-start" : "center", gap: 6, flexShrink: 0 }}>
    {back !== false && (
      <button style={{ all: "unset", cursor: "pointer", width: 40, height: 40, borderRadius: "var(--r-control)", display: "grid", placeItems: "center", flexShrink: 0 }}>
        <i className="ph ph-arrow-left" style={{ fontSize: 21, color: "var(--nyan-text)" }} />
      </button>
    )}
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ font: "600 20px/1.2 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.15px" }}>{title}</div>
      {subtitle && <div style={{ font: "400 13px/1.35 var(--font-ui)", color: "var(--nyan-text-muted)", marginTop: 4 }}>{subtitle}</div>}
    </div>
    {actions && <div style={{ display: "flex", gap: 4 }}>{actions}</div>}
  </div>
);

/* ── Section header (olive eyebrow caption + dot) ────────────────────────── */
const SectionHdr = ({ label, pad = "16px 0 8px" }) => (
  <div style={{ padding: pad, display: "flex", alignItems: "center", gap: 6 }}>
    <div style={{ width: 5, height: 5, borderRadius: "50%", background: "var(--nyan-primary)", flexShrink: 0 }} />
    <span style={{ font: "500 11px/1 var(--font-ui)", color: "var(--nyan-primary-deep)", letterSpacing: "0.22px", textTransform: "uppercase" }}>{label}</span>
  </div>
);

/* ── Grouped row stack — single rounded shell, hairline dividers ─────────── */
const RowGroup = ({ children }) => (
  <div style={{ background: "var(--nyan-surface)", borderRadius: "var(--r-card-nested)", border: "1px solid var(--chrome-edge)", boxShadow: "var(--shadow-grouped)", overflow: "hidden" }}>
    {React.Children.map(children, (child, i) => (
      <React.Fragment key={i}>
        {i > 0 && <div style={{ height: "0.5px", background: "color-mix(in srgb, var(--nyan-divider) 34%, transparent)", margin: "0 16px" }} />}
        {child}
      </React.Fragment>
    ))}
  </div>
);

/* ── List row — icon tile · title/subtitle · trailing · chevron · indent ─── */
const ListRow = ({ icon, title, subtitle, chevron, trailing, indent }) => (
  <div style={{ display: "flex", alignItems: "center", gap: 12, padding: indent ? "12px 16px 12px 52px" : "12px 16px", minHeight: 44, cursor: trailing ? "default" : "pointer" }}>
    {!indent && icon && (
      <div style={{ width: 32, height: 32, borderRadius: "var(--r-chip)", flexShrink: 0, background: "color-mix(in srgb, var(--nyan-primary) 9%, var(--nyan-surface-muted))", display: "grid", placeItems: "center" }}>
        <i className={`ph ph-${icon}`} style={{ fontSize: 16, color: "var(--nyan-primary)" }} />
      </div>
    )}
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ font: "500 15px/1.2 var(--font-ui)", color: "var(--nyan-text)" }}>{title}</div>
      {subtitle && <div style={{ font: "400 13px/1.3 var(--font-ui)", color: "var(--nyan-text-secondary)", marginTop: 2 }}>{subtitle}</div>}
    </div>
    {trailing}
    {chevron && <i className="ph ph-caret-right" style={{ fontSize: 16, color: "var(--nyan-text-muted)", flexShrink: 0 }} />}
  </div>
);

/* ── Toggle — single switch implementation (delegates to kit NyanSwitch) ─── */
const NyanToggle = ({ on, onChange }) => (
  <NyanSwitch value={on} onChange={onChange || (() => {})} />
);

/* ── Shelf Toolbar — the canonical Bookshelf header action cluster ─────────
   ONE toolbar for every shelf surface (U9 Home, U19 pinned header). It is the
   "tools beside the Bookshelf title": Search · Sort · List/Grid · Privacy
   Unlock (the lock only appears when Pro mode is enabled). Each button is the
   40px rounded chrome tile; an "active" tool lifts to a matcha tint + outline.
   Self-driving for galleries (internal state) or fully controllable by props. */
const ShelfToolBtn = ({ icon, active, onClick, label }) => (
  <button onClick={onClick} title={label} aria-label={label} style={{
    all: "unset", cursor: "pointer", width: 44, height: 44, borderRadius: "var(--r-control)",
    background: active ? "color-mix(in srgb, var(--nyan-primary) 13%, var(--nyan-surface))" : "var(--nyan-surface)",
    border: active
      ? "1px solid color-mix(in srgb, var(--nyan-primary) 42%, transparent)"
      : "1px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)",
    display: "grid", placeItems: "center", flexShrink: 0,
    transition: "background 140ms var(--ease-paper), border-color 140ms var(--ease-paper)",
  }}>
    <i className={`ph ph-${icon}`} style={{ fontSize: 18, color: active ? "var(--nyan-primary-deep)" : "var(--nyan-text-secondary)" }} />
  </button>
);

const ShelfToolbar = ({
  title = "Bookshelf",
  view: viewProp, onToggleView,
  sort: sortProp, onToggleSort,
  isPro = false, unlocked: unlockedProp, onToggleUnlock,
  onSearch, pad = "14px 16px 8px",
}) => {
  const [viewS, setViewS] = useState(viewProp || "grid");
  const [sortS, setSortS] = useState(!!sortProp);
  const [unlockedS, setUnlockedS] = useState(!!unlockedProp);
  const view = viewProp !== undefined ? viewProp : viewS;
  const sort = sortProp !== undefined ? sortProp : sortS;
  const unlocked = unlockedProp !== undefined ? unlockedProp : unlockedS;
  return (
    <div style={{ padding: pad, display: "flex", alignItems: "center", gap: 8, flexShrink: 0 }}>
      <div style={{ flex: 1, minWidth: 0, font: "600 22px/1.15 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.2px", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{title}</div>
      <div style={{ display: "flex", gap: 6 }}>
        <ShelfToolBtn icon="magnifying-glass" onClick={onSearch} label="Search" />
        <ShelfToolBtn icon="arrows-down-up" active={sort}
          onClick={onToggleSort || (() => setSortS(s => !s))} label="Sort order" />
        <ShelfToolBtn icon={view === "grid" ? "rows" : "squares-four"}
          onClick={onToggleView || (() => setViewS(v => v === "grid" ? "list" : "grid"))}
          label={view === "grid" ? "List view" : "Grid view"} />
        {isPro && (
          <ShelfToolBtn icon={unlocked ? "lock-simple-open" : "lock-simple"} active={unlocked}
            onClick={onToggleUnlock || (() => setUnlockedS(u => !u))}
            label={unlocked ? "Privacy shelf unlocked" : "Unlock privacy shelf"} />
        )}
      </div>
    </div>
  );
};

/* ── Presentational splash — the ONE launch composition. markSrc lets each
   host point at the brand mark by its own relative path. The kit's interactive
   SplashScreen wraps this with an auto-advance timer. ───────────────────── */
const NyanSplash = ({ markSrc = "assets/images/nyan_mark_v2.png", loading = false }) => (
  <div style={{ position: "relative", width: "100%", height: "100%", background: "var(--nyan-bg)", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", overflow: "hidden" }}>
    <div style={{ animation: "nyan-fadein 600ms var(--ease-paper) both", display: "flex", flexDirection: "column", alignItems: "center", gap: 26 }}>
      <div style={{ width: 168, height: 168, borderRadius: "var(--r-sheet)", background: "var(--nyan-surface)", border: "1px solid var(--chrome-edge)", boxShadow: "var(--shadow-light-card)", display: "grid", placeItems: "center" }}>
        <img src={markSrc} alt="Nyan Read" style={{ width: 112, height: "auto", display: "block" }} />
      </div>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 7 }}>
        <div style={{ font: "600 13px/1.3 var(--font-ui)", letterSpacing: "3px", color: "color-mix(in srgb, var(--nyan-primary) 92%, transparent)" }}>喵阅</div>
        <div style={{ font: "600 28px/1.1 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.3px" }}>Nyan Read</div>
        <div style={{ font: "400 14px/1.3 var(--font-ui)", color: "var(--nyan-text-muted)" }}>Enjoy reading time</div>
      </div>
    </div>
    {loading && (
      <div style={{ position: "absolute", bottom: 44, left: 0, right: 0, display: "flex", flexDirection: "column", alignItems: "center", gap: 12 }}>
        <div style={{ width: 132, height: 4, borderRadius: 999, background: "color-mix(in srgb, var(--nyan-text) 9%, transparent)", overflow: "hidden" }}>
          <div style={{ width: "55%", height: "100%", background: "var(--nyan-primary)", borderRadius: 999, animation: "nyan-loadbar 1400ms var(--ease-paper) infinite" }} />
        </div>
        <div style={{ font: "400 11.5px/1 var(--font-ui)", color: "var(--nyan-text-muted)", letterSpacing: "0.3px" }}>Opening your shelf…</div>
      </div>
    )}
  </div>
);

Object.assign(window, { READER_SAMPLE, READER_PROSE, ThemeWrap, ReaderBg, Shell, PageHdr, SectionHdr, RowGroup, ListRow, NyanToggle, ShelfToolBtn, ShelfToolbar, NyanSplash });
