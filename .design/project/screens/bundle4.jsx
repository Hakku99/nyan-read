/* ============================================================================
   Nyan Read — Screens: U14 Settings · U15 Reader Progress · U16 Privacy PIN · U17 Read Aloud · U18 Admin · U19 Shelf Toolbar
   ----------------------------------------------------------------------------
   Full-screen compositions assembled from components/*. Extracted verbatim from
   the bundle gallery so Claude Code can read/edit one screen without the HTML.
   Self-exports to window; the bundle HTML imports this then renders the gallery.
   ============================================================================ */

const { useState, useRef, useEffect } = React;

/* Screen scaffold helpers (PageHdr / SectionHdr / RowGroup / ListRow / NyanToggle)
   are shared from screens/_chrome.jsx. */

/* ──────────────────────────────────────────────────────────────────────
   U14 · SETTINGS PAGE
   Appearance / Reading / Data Management / Pro / About
   ────────────────────────────────────────────────────────────────────── */
const SettingsPage = ({ dark, reminderOn, isPro }) => {
  const [reminder, setReminder] = useState(reminderOn);
  return (
    <Shell dark={dark}>
      <PageHdr title="Settings" />
      <div style={{ flex: 1, overflowY: "auto", padding: "0 16px 32px" }}>

        <SectionHdr label="Appearance" />
        <RowGroup>
          <ListRow icon="palette" title="Theme Preset" subtitle={dark ? "Sumi Dark" : "Cream Light"} chevron />
          <ListRow icon="translate" title="Language" subtitle="English" chevron />
        </RowGroup>

        <SectionHdr label="Reading" />
        <RowGroup>
          <ListRow icon="book-open" title="Page Turn Mode" subtitle="Left & Right" chevron />
          <ListRow icon="bell" title="Rest Reminder" subtitle="Nudge me to take a break while reading" trailing={<NyanToggle on={reminder} />} />
          {reminder && (
            <ListRow indent title="Rest Interval" subtitle="Every 30 min" chevron />
          )}
          <ListRow icon="trash" title="Delete Files on Remove" subtitle="Remove source files when deleting a book" trailing={<NyanToggle on={false} />} />
        </RowGroup>

        <SectionHdr label="Data Management" />
        <RowGroup>
          <ListRow icon="export" title="Export Data" subtitle="Save to device or share" chevron />
          <ListRow icon="cloud-arrow-down" title="Import Data" subtitle="Restore from a backup file" chevron />
        </RowGroup>

        {isPro && (
          <>
            <SectionHdr label="Admin" />
            <RowGroup>
              <ListRow icon="wrench" title="Admin Panel" subtitle="Feature flags & privacy controls" chevron />
            </RowGroup>
          </>
        )}

        <SectionHdr label="About" />
        <div style={{ background: "var(--nyan-surface)", borderRadius: 16, border: "0.72px solid color-mix(in srgb, var(--nyan-divider) 36%, transparent)", padding: "16px" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
            <div style={{ width: 56, height: 56, borderRadius: "var(--r-card-nested)", background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface-muted))", display: "grid", placeItems: "center", flexShrink: 0 }}>
              <i className="ph ph-book-open" style={{ fontSize: 26, color: "var(--nyan-primary)" }} />
            </div>
            <div>
              <div style={{ font: "600 18px/1.2 var(--font-ui)", color: "var(--nyan-text)" }}>Nyan Read</div>
              <div style={{ font: "400 13px/1.3 var(--font-ui)", color: "var(--nyan-text-secondary)", marginTop: 2 }}>v1.0.0 · ฅ^•ﻌ•^ฅ</div>
            </div>
          </div>
        </div>
      </div>
    </Shell>
  );
};


/* ── U14 picker overlays — the option sheets that open from each settings row.
   Theme Preset / Language / Page Turn / Reminder Interval are single-select
   radio sheets; Export Data is an action sheet. Composed over the live
   SettingsPage so the picker reads in its real context. ──────────────────── */
const SETTINGS_PICKERS = {
  theme: {
    title: "Theme Preset", subtitle: "How Nyan Read looks while you read.", selected: 0,
    options: [
      { label: "Cream Light", hint: "Warm paper — the default", swatch: "#F7F5EF" },
      { label: "Sumi Dark", hint: "Ink night for low light", swatch: "#262422" },
      { label: "Match System", hint: "Follow your device setting", swatch: "linear-gradient(135deg, #F7F5EF 50%, #262422 50%)" },
    ],
  },
  language: {
    title: "Language", subtitle: "App display language.", selected: 0,
    options: [
      { label: "English", hint: "English" },
      { label: "中文", hint: "Chinese · 简体中文" },
    ],
  },
  pageturn: {
    title: "Page Turn Mode", subtitle: "The direction pages move as you read.", selected: 0,
    options: [
      { label: "Left & Right", hint: "Turn pages horizontally", icon: "arrows-horizontal" },
      { label: "Up & Down", hint: "Turn pages vertically", icon: "arrows-vertical" },
    ],
  },
  reminder: {
    title: "Rest Interval", subtitle: "How long to read before we suggest a break.", selected: 1,
    options: ["Every 15 minutes", "Every 30 minutes", "Every 45 minutes", "Every hour", "Every 90 minutes"],
  },
  export: {
    title: "Export Data", subtitle: "Choose where your reading data goes.", variant: "action",
    options: [
      { label: "Save to Device", hint: "Store a JSON backup in your Files", icon: "download-simple" },
      { label: "Share…", hint: "Send via Gmail, Drive or another app", icon: "share-network" },
    ],
  },
};

const SettingsWithPicker = ({ dark, picker }) => {
  const cfg = SETTINGS_PICKERS[picker] || SETTINGS_PICKERS.theme;
  return (
    <div data-theme={dark ? "sumi" : undefined} style={{ position: "relative", width: "100%", height: "100%", overflow: "hidden" }}>
      <SettingsPage dark={dark} reminderOn={picker === "reminder"} isPro={false} />
      <NyanOptionSheet
        title={cfg.title}
        subtitle={cfg.subtitle}
        options={cfg.options}
        selected={cfg.selected || 0}
        variant={cfg.variant || "radio"}
        onClose={() => {}}
      />
    </div>
  );
};


/* ──────────────────────────────────────────────────────────────────────
   U15 · READER PROGRESS & CHAPTER NAV
   In One Paper there is no standalone progress card — progress and chapter
   navigation live in the DOCK FOOTER (thin progress bar + chapter stepper +
   the 3 actions). This shows the resting dock (collapsed, footer only) over
   a reader page. Tap the ‹ › stepper to move chapters.
   ────────────────────────────────────────────────────────────────────── */
const ReaderCanvasBg = ({ dark, children }) => (
  <div style={{ position: "relative", width: "100%", height: "100%", background: dark ? "#262422" : "#F7F5EF", overflow: "hidden" }}>
    <div style={{ position: "absolute", inset: 0, padding: "44px 28px 24px", pointerEvents: "none" }}>
      <div style={{ font: "400 13.5px/1.85 var(--font-ui)", color: dark ? "#E5DED3" : "#4A453E", opacity: 0.55, textIndent: "2em" }}>
        The cat sat on the threshold for a long while, watching the rain darken the stones and the wisteria release its scent into the late spring evening.
      </div>
    </div>
    {children}
  </div>
);

const U15Artboard = ({ dark, startIndex = 2 }) => {
  const [ci, setCi] = useState(startIndex);
  const TOTAL = 18;
  return (
    <div data-theme={dark ? "sumi" : undefined} style={{ width: "100%", height: "100%" }}>
      <ReaderCanvasBg dark={dark}>
        <OnePaperDock
          visible
          sheetOpen={false}
          chapterIndex={ci}
          chapterCount={TOTAL}
          progress={(ci + 0.4) / TOTAL}
          activeAction={null}
          onAction={() => {}}
          onPrevChapter={() => setCi((i) => Math.max(0, i - 1))}
          onNextChapter={() => setCi((i) => Math.min(TOTAL - 1, i + 1))}
          onStopProp={false}
        />
      </ReaderCanvasBg>
    </div>
  );
};


/* ──────────────────────────────────────────────────────────────────────
   U16 · PRIVACY PIN OVERLAY (FULL-SCREEN)
   Corrective: Colors.black @ 0.95 → #1D211E (ink-night)
               W300 → W400 (minimum weight in design system)
   Modes: setup · verify (error) · change
   ────────────────────────────────────────────────────────────────────── */
const PinDots = ({ count, hasError, fill, ring, errorColor }) => (
  <div style={{ display: "flex", gap: 17, justifyContent: "center", animation: hasError ? "pin-shake 360ms var(--ease-paper)" : "none" }}>
    {[0,1,2,3].map(i => {
      const on = i < count;
      const c = hasError ? errorColor : fill;
      return (
        <div key={i} style={{ position: "relative", width: 13, height: 13, display: "grid", placeItems: "center" }}>
          {/* soft halo blooms as the digit lands */}
          <div style={{ position: "absolute", inset: -6, borderRadius: "50%",
            background: `color-mix(in srgb, ${c} 16%, transparent)`,
            transform: on ? "scale(1)" : "scale(0.4)", opacity: on ? 1 : 0,
            transition: "transform 220ms var(--ease-paper), opacity 220ms ease" }} />
          <div style={{ position: "relative", width: 13, height: 13, borderRadius: "50%",
            background: on ? c : "transparent",
            border: `1.5px solid ${on ? c : ring}`,
            transform: on ? "scale(1)" : "scale(0.8)",
            transition: "background 160ms var(--ease-paper), border-color 160ms ease, transform 160ms var(--ease-paper)" }} />
        </div>
      );
    })}
  </div>
);

const NumPad = ({ onDigit, onDelete, showBiometric }) => {
  const keys = [[1,2,3],[4,5,6],[7,8,9],["bio",0,"del"]];
  const ghost = { all: "unset", cursor: "pointer", width: 74, height: 74, borderRadius: "50%",
    display: "grid", placeItems: "center", color: "var(--nyan-text-muted)" };
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 15, alignItems: "center" }}>
      {keys.map((row, ri) => (
        <div key={ri} style={{ display: "flex", gap: 20 }}>
          {row.map((k) => {
            if (k === "bio") {
              return showBiometric ? (
                <button key="bio" onClick={() => onDigit(1)} className="nyan-pinkey-ghost" style={ghost} aria-label="Unlock with biometrics">
                  <i className="ph ph-fingerprint" style={{ fontSize: 27, color: "var(--nyan-primary)" }} />
                </button>
              ) : <div key="bio" style={{ width: 74, height: 74 }} />;
            }
            if (k === "del") {
              return (
                <button key="del" onClick={onDelete} className="nyan-pinkey-ghost" style={ghost} aria-label="Delete">
                  <i className="ph ph-backspace" style={{ fontSize: 24 }} />
                </button>
              );
            }
            return (
              <button key={k} onClick={() => onDigit(k)} className="nyan-pinkey"
                style={{ all: "unset", cursor: "pointer", width: 74, height: 74, borderRadius: "50%",
                  background: "var(--nyan-surface)", boxShadow: "var(--shadow-subtle)",
                  display: "grid", placeItems: "center",
                  font: "500 27px/1 var(--font-ui)", color: "var(--nyan-text)" }}>
                {k}
              </button>
            );
          })}
        </div>
      ))}
    </div>
  );
};

const PinOverlay = ({ mode = "verify", hasError, dark = true }) => {
  const [digits, setDigits] = useState(hasError ? [1,2,3,4] : []);
  const titles = { setup: "Set a PIN", verify: "Enter your PIN", change: "New PIN", confirm: "Confirm your PIN" };
  const subs = {
    setup:   "Choose a 4-digit code to keep your private shelf for your eyes only.",
    verify:  "Enter your code to open your private shelf.",
    change:  "Choose a new 4-digit code.",
    confirm: "Re-enter the code once more to confirm.",
  };

  const onDigit = (d) => setDigits(p => p.length < 4 ? [...p, d] : p);
  const onDelete = () => setDigits(p => p.slice(0,-1));

  // One Paper takeover — themed entirely by tokens (data-theme drives Sumi).
  return (
    <div data-theme={dark ? "sumi" : undefined} style={{ width: "100%", height: "100%", background: "var(--nyan-bg)", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", position: "relative", padding: "max(54px, env(safe-area-inset-top)) 28px max(18px, env(safe-area-inset-bottom))", overflow: "hidden" }}>
      <style>{`
        .nyan-pinkey { transition: transform 150ms var(--ease-paper), box-shadow 200ms ease, background 150ms ease; }
        .nyan-pinkey:hover { transform: translateY(-1px); box-shadow: var(--shadow-light-card); }
        .nyan-pinkey:active { transform: scale(0.93); box-shadow: var(--shadow-grouped); background: color-mix(in srgb, var(--nyan-primary) 16%, var(--nyan-surface)); }
        .nyan-pinkey-ghost { transition: color 150ms ease, transform 150ms var(--ease-paper); }
        .nyan-pinkey-ghost:hover { color: var(--nyan-text-secondary); }
        .nyan-pinkey-ghost:active { transform: scale(0.9); }
        .nyan-pin-cancel { transition: background 150ms ease; }
        .nyan-pin-cancel:hover { background: color-mix(in srgb, var(--nyan-text) 7%, transparent); }
        .nyan-pin-link { transition: color 150ms ease; }
        .nyan-pin-link:hover { color: var(--nyan-primary); }
      `}</style>

      {/* Soft matcha bloom behind the medallion — paper-warm, very low alpha */}
      <div style={{ position: "absolute", top: "13%", left: "50%", transform: "translateX(-50%)", width: 360, height: 360, borderRadius: "50%", pointerEvents: "none",
        background: "radial-gradient(circle, color-mix(in srgb, var(--nyan-primary) 15%, transparent) 0%, transparent 68%)" }} />

      <div style={{ position: "relative", display: "flex", flexDirection: "column", alignItems: "center", width: "100%" }}>
        {/* Lock medallion — concentric tile, matcha ring + fill glyph */}
        <div style={{ position: "relative", width: 76, height: 76, marginBottom: 22, display: "grid", placeItems: "center" }}>
          <div style={{ position: "absolute", inset: 0, borderRadius: "var(--radius-card)", background: "color-mix(in srgb, var(--nyan-primary) 11%, var(--nyan-surface))", boxShadow: "var(--shadow-light-card)" }} />
          <div style={{ position: "absolute", inset: 0, borderRadius: "var(--radius-card)", border: "1px solid color-mix(in srgb, var(--nyan-primary) 26%, transparent)" }} />
          <i className="ph-fill ph-lock-simple" style={{ position: "relative", fontSize: 31, color: "var(--nyan-primary)" }} />
        </div>

        {/* Eyebrow + title + supporting line */}
        <div className="nyan-caption" style={{ marginBottom: 9 }}>Privacy Shelf</div>
        <div style={{ font: "600 22px/1.25 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.2px", marginBottom: 8 }}>
          {titles[mode]}
        </div>
        <div style={{ font: "400 13.5px/1.45 var(--font-ui)", color: "var(--nyan-text-muted)", textAlign: "center", maxWidth: 270, textWrap: "balance", marginBottom: hasError ? 22 : 38 }}>
          {subs[mode]}
        </div>

        {/* PIN dots */}
        <PinDots count={digits.length} hasError={hasError}
          fill="var(--nyan-primary)"
          ring="color-mix(in srgb, var(--nyan-text) 26%, transparent)"
          errorColor="var(--error-primary)" />

        {/* Error hint */}
        {hasError && (
          <div style={{ display: "flex", alignItems: "center", gap: 6, marginTop: 16, font: "500 13px/1.3 var(--font-ui)", color: "var(--error-primary)" }}>
            <i className="ph-fill ph-warning-circle" style={{ fontSize: 15 }} />
            PINs don’t match — try again
          </div>
        )}

        <div style={{ marginTop: hasError ? 28 : 42 }}>
          <NumPad onDigit={onDigit} onDelete={onDelete} showBiometric={mode === "verify"} />
        </div>

        {/* Footer — contextual: forgot link (verify) or device-only reassurance (setup/confirm) */}
        <div style={{ marginTop: 22, minHeight: 18, display: "flex", alignItems: "center", justifyContent: "center", gap: 18 }}>
          {mode === "verify" ? (
            <React.Fragment>
              <button className="nyan-pin-link" style={{ all: "unset", cursor: "pointer", font: "500 13px/1 var(--font-ui)", color: "var(--nyan-text-muted)" }}>
                Cancel
              </button>
              <div style={{ width: "1px", height: 13, background: "color-mix(in srgb, var(--nyan-divider) 70%, transparent)" }} />
              <button className="nyan-pin-link" style={{ all: "unset", cursor: "pointer", font: "500 13px/1 var(--font-ui)", color: "var(--nyan-primary-deep)" }}>
                Forgot PIN?
              </button>
            </React.Fragment>
          ) : (
            <div style={{ display: "flex", alignItems: "center", gap: 6, font: "400 12px/1 var(--font-ui)", color: "var(--nyan-text-muted)" }}>
              <i className="ph ph-shield-check" style={{ fontSize: 14, color: "var(--nyan-primary)" }} />
              Stored on this device only
            </div>
          )}
        </div>
      </div>
    </div>
  );
};


/* ──────────────────────────────────────────────────────────────────────
   U17 · TTS SHEET (DESIGNED — source is a stub)
   Bottom sheet: voice chip · speed selector · play/pause · skip · progress
   ────────────────────────────────────────────────────────────────────── */
const TTS_SPEEDS = ["0.75×","1.0×","1.25×","1.5×"];

const TTSSheet = ({ dark }) => {
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState(1);
  const [progress, setProgress] = useState(0.3);
  const trackRef = useRef(null);
  const dragging = useRef(false);

  const seek = (e) => {
    if (!trackRef.current) return;
    const rect = trackRef.current.getBoundingClientRect();
    const cx = e.touches ? e.touches[0].clientX : e.clientX;
    setProgress(Math.max(0, Math.min(1, (cx - rect.left) / rect.width)));
  };
  useEffect(() => {
    const mm = (e) => { if (dragging.current) seek(e); };
    const mu = () => { dragging.current = false; };
    window.addEventListener("mousemove", mm);
    window.addEventListener("mouseup", mu);
    return () => { window.removeEventListener("mousemove", mm); window.removeEventListener("mouseup", mu); };
  }, []);

  return (
    <div data-theme={dark ? "sumi" : undefined}
      style={{ position: "relative", width: "100%", height: "100%", background: dark ? "#262422" : "#F7F5EF", overflow: "hidden" }}>
      {/* reader prose behind */}
      <div style={{ position: "absolute", inset: 0, padding: "44px 28px 24px", pointerEvents: "none" }}>
        <div style={{ font: "400 13.5px/1.85 var(--font-ui)", color: dark ? "#E5DED3" : "#4A453E", opacity: 0.5, textIndent: "2em" }}>
          The cat sat on the threshold for a long while, watching the rain darken the stones and the wisteria release its scent into the late spring evening.
        </div>
      </div>
      {/* warm-ink scrim + gentle blur */}
      <div style={{ position: "absolute", inset: 0, background: "var(--scrim)", backdropFilter: "blur(var(--scrim-blur))", WebkitBackdropFilter: "blur(var(--scrim-blur))" }} />
      {/* floating sheet — inset all sides, all four corners, one soft lift */}
      <div style={{ position: "absolute", left: "var(--inset)", right: "var(--inset)", bottom: "var(--inset)", background: "var(--nyan-surface)", border: "1px solid var(--chrome-edge)", borderRadius: "var(--r-sheet)", boxShadow: "var(--shadow-light-card)", overflow: "hidden" }}>
        {/* Matcha grabber */}
        <div style={{ paddingTop: 10, display: "flex", justifyContent: "center" }}>
          <div style={{ width: 40, height: 5, borderRadius: 999, background: "var(--grabber)" }} />
        </div>
        <div style={{ padding: "14px 20px 28px", display: "flex", flexDirection: "column", gap: 16 }}>
          {/* Header row */}
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <div>
              <div style={{ font: "600 17px/1.2 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.1px" }}>Read Aloud</div>
              <div style={{ font: "400 13px/1.3 var(--font-ui)", color: "var(--nyan-text-secondary)", marginTop: 2 }}>Chapter 3 — A Cup of Still Water</div>
            </div>
            {/* Voice chip */}
            <div style={{ height: 34, padding: "0 12px", borderRadius: 999, background: "color-mix(in srgb, var(--nyan-primary) 10%, var(--nyan-surface-muted))", border: "1px solid color-mix(in srgb, var(--nyan-primary) 18%, transparent)", display: "flex", alignItems: "center", gap: 6, cursor: "pointer" }}>
              <i className="ph ph-user-sound" style={{ fontSize: 14, color: "var(--nyan-primary)" }} />
              <span style={{ font: "500 13px/1 var(--font-ui)", color: "var(--nyan-primary-deep)" }}>System Voice</span>
            </div>
          </div>
          {/* Progress track + times */}
          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            <div ref={trackRef} onMouseDown={(e) => { dragging.current = true; seek(e); }}
              style={{ position: "relative", height: 12, cursor: "pointer" }}>
              <div style={{ position: "absolute", inset: 0, borderRadius: 8, background: "color-mix(in srgb, var(--nyan-divider) 30%, var(--nyan-surface-muted))" }} />
              <div style={{ position: "absolute", top: 0, left: 0, height: "100%", width: `${Math.round(progress * 100)}%`, borderRadius: 8, background: "var(--nyan-primary)" }} />
              <div style={{ position: "absolute", top: -1, left: `calc(${Math.round(progress * 100)}% - 7px)`, width: 14, height: 14, borderRadius: 8, background: "var(--nyan-primary)", border: "1.2px solid color-mix(in srgb, var(--nyan-surface) 82%, transparent)" }} />
            </div>
            <div style={{ display: "flex", justifyContent: "space-between" }}>
              <span style={{ font: "400 12px/1 var(--font-ui)", color: "var(--nyan-text-muted)", fontVariantNumeric: "tabular-nums" }}>2:14</span>
              <span style={{ font: "400 12px/1 var(--font-ui)", color: "var(--nyan-text-muted)", fontVariantNumeric: "tabular-nums" }}>7:30</span>
            </div>
          </div>
          {/* Speed pills */}
          <div style={{ display: "flex", background: "var(--nyan-surface-muted)", borderRadius: 14, padding: 3, gap: 2 }}>
            {TTS_SPEEDS.map((s, i) => (
              <button key={s} onClick={() => setSpeed(i)} style={{ all: "unset", cursor: "pointer", flex: 1, height: 32, borderRadius: 11, background: speed === i ? "var(--nyan-surface)" : "transparent", boxShadow: speed === i ? "0 1px 3px rgba(0,0,0,0.06)" : "none", font: `${speed === i ? 600 : 500} 13px/1 var(--font-ui)`, color: speed === i ? "var(--nyan-text)" : "var(--nyan-text-muted)", display: "grid", placeItems: "center", transition: "background 160ms ease" }}>{s}</button>
            ))}
          </div>
          {/* Playback controls */}
          <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 12 }}>
            {["skip-back","rewind","play"].map((ic, i) => {
              const isPlay = i === 2;
              return (
                <button key={ic} onClick={isPlay ? () => setPlaying(p => !p) : undefined}
                  style={{ all: "unset", cursor: "pointer",
                    width: isPlay ? 60 : 48, height: isPlay ? 60 : 48,
                    borderRadius: isPlay ? 18 : 14,
                    background: isPlay ? "var(--nyan-primary)" : "var(--nyan-surface-muted)",
                    border: isPlay ? "none" : "1px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)",
                    display: "grid", placeItems: "center" }}>
                  <i className={`ph ph-${isPlay ? (playing ? "pause" : "play") : ic}`}
                    style={{ fontSize: isPlay ? 28 : 22, color: isPlay ? "var(--nyan-surface)" : "var(--nyan-primary)" }} />
                </button>
              );
            })}
            {["fast-forward","skip-forward"].map((ic) => (
              <button key={ic} style={{ all: "unset", cursor: "pointer", width: 48, height: 48, borderRadius: 14, background: "var(--nyan-surface-muted)", border: "1px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)", display: "grid", placeItems: "center" }}>
                <i className={`ph ph-${ic}`} style={{ fontSize: 22, color: "var(--nyan-primary)" }} />
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

/* ── U17 (active) · Reading aloud — the state AFTER TTS starts ─────────────
   The setup sheet collapses to a slim floating mini-player; the book content
   stays visible and auto-scrolls so the spoken sentence is highlighted in
   matcha. The mini-player speaks the One Paper dock language (inset, rounded,
   lightCard) and carries the essential transport: play/pause + stop. */
const TTS_PARAS = [
  ["She would sometimes say that of all the noises in the city, only the bell and the rain felt honest.", false],
  ["The trams, the merchants, the cries of the gulls upriver — all of them wanted something.", false],
  ["The bell never did. It simply marked the hour and let you fold the page however you liked.", true],
  ["He set the lacquer cup down on the low table and looked, again, at the calligraphy in the alcove.", false],
  ["An old hand, careful and not particularly clever; he had read it perhaps three hundred times.", false],
];

const TTSActiveReading = ({ dark }) => {
  const [playing, setPlaying] = useState(true);
  const ink = dark ? "#E5DED3" : "#4A453E";
  return (
    <div data-theme={dark ? "sumi" : undefined}
      style={{ position: "relative", width: "100%", height: "100%", background: dark ? "#262422" : "#F7F5EF", overflow: "hidden" }}>
      {/* Auto-scrolling prose; the spoken sentence is highlighted in matcha */}
      <div style={{ position: "absolute", inset: 0, padding: "52px 26px 120px", overflow: "hidden" }}>
        <div style={{ font: `400 12px/1.4 ${"var(--font-ui)"}`, color: ink, opacity: 0.5, marginBottom: 20, letterSpacing: 0.4 }}>Chapter 3 · A Cup of Still Water</div>
        {TTS_PARAS.map(([text, active], i) => (
          <p key={i} style={{
            font: "400 16px/1.72 var(--font-serif)",
            color: active ? "var(--nyan-primary-deep)" : ink,
            opacity: active ? 1 : 0.66,
            background: active ? "color-mix(in srgb, var(--nyan-primary) 15%, transparent)" : "transparent",
            borderRadius: active ? 10 : 0,
            padding: active ? "6px 10px" : "0",
            margin: active ? "0 -10px 16px" : "0 0 16px",
            transition: "background 200ms var(--ease-paper)",
          }}>{text}</p>
        ))}
      </div>

      {/* Floating mini-player — slim dock, inset, lightCard */}
      <div style={{ position: "absolute", left: "var(--inset)", right: "var(--inset)", bottom: "var(--inset)",
        background: "var(--nyan-surface)", border: "1px solid var(--chrome-edge)", borderRadius: "var(--r-dock)",
        boxShadow: "var(--shadow-light-card)", overflow: "hidden" }}>
        {/* speaking progress hairline */}
        <div style={{ height: 3, background: "color-mix(in srgb, var(--nyan-text) 11%, transparent)" }}>
          <div style={{ width: "46%", height: "100%", background: "var(--nyan-primary)" }} />
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "10px 12px" }}>
          {/* speaking indicator */}
          <div style={{ width: 38, height: 38, flex: "none", borderRadius: 12, background: "color-mix(in srgb, var(--nyan-primary) 12%, transparent)", display: "grid", placeItems: "center" }}>
            <i className="ph ph-waveform" style={{ fontSize: 20, color: "var(--nyan-primary-deep)" }} />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ font: "600 13.5px/1.2 var(--font-ui)", color: "var(--nyan-text)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>Reading aloud</div>
            <div style={{ font: "400 11.5px/1.2 var(--font-ui)", color: "var(--nyan-text-muted)" }}>System Voice · 1.0× · 2:14 / 7:30</div>
          </div>
          {/* transport: play/pause (matcha) + stop */}
          <button onClick={() => setPlaying(p => !p)} style={{ all: "unset", cursor: "pointer", width: 44, height: 44, flex: "none", borderRadius: 14, background: "var(--nyan-primary)", display: "grid", placeItems: "center" }}>
            <i className={`ph-fill ph-${playing ? "pause" : "play"}`} style={{ fontSize: 20, color: "var(--nyan-surface)" }} />
          </button>
          <button style={{ all: "unset", cursor: "pointer", width: 44, height: 44, flex: "none", borderRadius: 14, background: "var(--nyan-surface-muted)", border: "1px solid var(--nyan-divider)", display: "grid", placeItems: "center" }}>
            <i className="ph-fill ph-stop" style={{ fontSize: 18, color: "var(--nyan-text-secondary)" }} />
          </button>
        </div>
      </div>
    </div>
  );
};
const FlagBadge = ({ on, dark }) => {
  const accent = on ? "var(--nyan-primary-deep)" : "var(--nyan-text-secondary)";
  return (
    <div style={{ height: 28, padding: "0 12px", borderRadius: "var(--r-chip)",
      background: `color-mix(in srgb, ${accent} ${on ? 10 : 8}%, var(--nyan-surface-muted))`,
      border: `1px solid color-mix(in srgb, ${accent} ${on ? 30 : 22}%, transparent)`,
      display: "flex", alignItems: "center" }}>
      <span style={{ font: "500 12px/1 var(--font-ui)", color: accent }}>{on ? "On" : "Off"}</span>
    </div>
  );
};

const AdminPanel = ({ dark, isPro }) => {
  const [proOn, setPro] = useState(isPro);
  const [unlocked, setUnlocked] = useState(false);
  const [forcePro, setForcePro] = useState(true);
  const flags = { Ads: true, Privacy: isPro, TTS: false };
  return (
    <Shell dark={dark}>
      <PageHdr title="Admin Panel" />
      <div style={{ flex: 1, overflowY: "auto", padding: "0 16px 32px" }}>
        {/* Mode section */}
        <SectionHdr label="Mode" />
        <RowGroup>
          <div style={{ padding: "12px 16px" }}>
            <div style={{ display: "flex", alignItems: "flex-start", gap: 12 }}>
              <div style={{ flex: 1 }}>
                <div style={{ font: "600 15px/1.2 var(--font-ui)", color: "var(--nyan-text)", marginBottom: 4 }}>Pro Mode Enabled</div>
                <div style={{ font: "400 13px/1.3 var(--font-ui)", color: "var(--nyan-text-secondary)" }}>Unlocks all Pro features in this session.</div>
              </div>
              <div onClick={() => setPro(p => !p)}><NyanToggle on={proOn} /></div>
            </div>
          </div>
          {proOn && (
            <>
              <div style={{ height: "0.5px", background: "color-mix(in srgb, var(--nyan-divider) 34%, transparent)", margin: "0 16px" }} />
              <div style={{ padding: "12px 16px" }}>
                <div style={{ display: "flex", alignItems: "flex-start", gap: 12 }}>
                  <div style={{ flex: 1 }}>
                    <div style={{ font: "600 15px/1.2 var(--font-ui)", color: "var(--nyan-text)", marginBottom: 4 }}>Force Unlock Privacy Shelf</div>
                    <div style={{ font: "400 13px/1.3 var(--font-ui)", color: "var(--nyan-text-secondary)" }}>Bypass PIN for this session.</div>
                  </div>
                  <div onClick={() => setUnlocked(p => !p)}><NyanToggle on={unlocked} /></div>
                </div>
              </div>
              <div style={{ height: "0.5px", background: "color-mix(in srgb, var(--nyan-divider) 34%, transparent)", margin: "0 16px" }} />
              <div style={{ padding: "12px 16px" }}>
                <div style={{ display: "flex", alignItems: "flex-start", gap: 12 }}>
                  <div style={{ flex: 1 }}>
                    <div style={{ font: "600 15px/1.2 var(--font-ui)", color: "var(--nyan-text)", marginBottom: 4 }}>Force Pro Nudge</div>
                    <div style={{ font: "400 13px/1.3 var(--font-ui)", color: "var(--nyan-text-secondary)" }}>Show the Pro upgrade card in the ad slot.</div>
                  </div>
                  <div onClick={() => setForcePro(p => !p)}><NyanToggle on={forcePro} /></div>
                </div>
              </div>
            </>
          )}
        </RowGroup>

        {/* Feature flags */}
        <SectionHdr label="Feature Flags" />
        <RowGroup>
          {Object.entries(flags).map(([name, on], i) => (
            <div key={name} style={{ display: "flex", alignItems: "center", padding: "12px 16px", minHeight: 44 }}>
              <div style={{ flex: 1, font: "500 15px/1.2 var(--font-ui)", color: "var(--nyan-text)" }}>{name}</div>
              <FlagBadge on={on} dark={dark} />
            </div>
          ))}
        </RowGroup>

        {/* Hint card */}
        <div style={{ marginTop: 12, background: "color-mix(in srgb, var(--nyan-primary) 5%, var(--nyan-surface))", borderRadius: 16, border: "0.72px solid color-mix(in srgb, var(--nyan-primary-deep) 22%, transparent)", padding: "14px 16px", display: "flex", gap: 10, alignItems: "flex-start" }}>
          <i className="ph ph-info" style={{ fontSize: 18, color: "var(--nyan-primary-deep)", flexShrink: 0, marginTop: 1 }} />
          <div style={{ flex: 1 }}>
            <div style={{ font: "600 14px/1.2 var(--font-ui)", color: "var(--nyan-text)", marginBottom: 4 }}>For testing only</div>
            <div style={{ font: "400 13px/1.35 var(--font-ui)", color: "var(--nyan-text-secondary)" }}>Changes here affect only this session. Restart the app to reset to defaults.</div>
          </div>
        </div>
      </div>
    </Shell>
  );
};


/* ──────────────────────────────────────────────────────────────────────
   U19 · BOOKSHELF SHELF TOOLBAR (PINNED HEADER)
   Recessed segmented track (canonical, matches U9) + sort/view actions above
   ────────────────────────────────────────────────────────────────────── */
const BOOKS_SHELF = [
  { id: 1, title: "The Stillwater Diaries", author: "Matsuno Eri", fmt: "EPUB", pct: 42 },
  { id: 2, title: "Borrowed Light", author: "Yuen Lai-Ying", fmt: "TXT", pct: 0 },
  { id: 3, title: "A Long Slope Down", author: "Park Hyun-joo", fmt: "PDF", pct: 88 },
  { id: 4, title: "Sand and Memoir", author: "Unknown", fmt: "EPUB", pct: 12 },
];

const SmallBookCard = ({ book }) => (
  <div style={{ display: "flex", flexDirection: "column", cursor: "pointer" }}>
    <div style={{ width: "100%", aspectRatio: "120/156", borderRadius: 12, background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))", border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 28%, transparent)", display: "grid", placeItems: "center", marginBottom: 6 }}>
      <i className="ph ph-book-open" style={{ fontSize: 26, color: "var(--nyan-primary)" }} />
    </div>
    {book.pct > 0 && <div style={{ height: 2.5, borderRadius: 999, background: "color-mix(in srgb, var(--nyan-primary) 16%, var(--nyan-surface))", marginBottom: 6 }}><div style={{ width: `${book.pct}%`, height: "100%", borderRadius: 999, background: "var(--nyan-primary)" }} /></div>}
    <div style={{ font: "600 12.5px/1.25 var(--font-ui)", color: "var(--nyan-text)", overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical", marginBottom: 2 }}>{book.title}</div>
    <div style={{ font: "400 11px/1.3 var(--font-ui)", color: "var(--nyan-text-muted)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{book.author}</div>
  </div>
);

const ShelfToolbarScreen = ({ dark, sort, isPro = false }) => {
  const [tab, setTab] = useState(0);
  return (
    <Shell dark={dark}>
      {/* Shared Shelf Toolbar — search · sort · view · privacy unlock (Pro only) */}
      <ShelfToolbar sort={sort} isPro={isPro} unlocked={isPro} onSearch={() => {}} />

      {/* Pinned shelf toolbar — canonical recessed segmented track (matches U9).
          Soft downward shadow lifts the pinned header above the scrolling list. */}
      <div style={{ padding: "0 16px 0", flexShrink: 0,
        position: "relative", zIndex: 2,
        boxShadow: "0 6px 14px -8px rgba(40,36,30,0.22)",
        borderBottom: "1px solid color-mix(in srgb, var(--nyan-divider) 22%, transparent)",
        background: "var(--nyan-bg)" }}>
        <div style={{ display: "flex", background: "var(--nyan-surface-muted)", borderRadius: 14, padding: 3, gap: 2, marginBottom: 10 }}>
          {["Public Shelf", "Private Shelf"].map((t, i) => (
            <button key={t} onClick={() => setTab(i)} style={{ all: "unset", cursor: "pointer", flex: 1, height: 34, borderRadius: 11, background: tab === i ? "var(--nyan-surface)" : "transparent", boxShadow: tab === i ? "0 1px 3px rgba(0,0,0,0.06)" : "none", font: `${tab === i ? 600 : 500} 14px/1 var(--font-ui)`, color: tab === i ? "var(--nyan-text)" : "var(--nyan-text-muted)", display: "grid", placeItems: "center", transition: "background 160ms ease" }}>
              {t}
            </button>
          ))}
        </div>
      </div>

      {/* Book grid below the toolbar */}
      <div style={{ flex: 1, overflowY: "auto", padding: "14px 16px 32px" }}>
        {tab === 1 ? (
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", height: "100%", gap: 14, textAlign: "center", paddingTop: 40 }}>
            <div style={{ width: 80, height: 80, borderRadius: "50%", background: "color-mix(in srgb, var(--nyan-primary) 7%, var(--nyan-surface))", border: "0.7px solid color-mix(in srgb, var(--nyan-divider) 18%, transparent)", display: "grid", placeItems: "center" }}>
              <i className="ph ph-lock" style={{ fontSize: 32, color: "var(--nyan-primary)", opacity: 0.72 }} />
            </div>
            <div>
              <div style={{ font: "600 17px/1.25 var(--font-ui)", color: "var(--nyan-text)", opacity: 0.82, marginBottom: 8 }}>This private space is empty.</div>
              <div style={{ font: "400 14px/1.5 var(--font-ui)", color: "var(--nyan-text-secondary)", opacity: 0.72, maxWidth: 260, margin: "0 auto" }}>Select books from the public shelf and tap the Lock icon to move them here.</div>
            </div>
          </div>
        ) : (
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: "16px 12px" }}>
            {BOOKS_SHELF.concat(BOOKS_SHELF).slice(0, 9).map((b, i) => <SmallBookCard key={i} book={b} />)}
          </div>
        )}
      </div>
    </Shell>
  );
};


/* ──────────────────────────────────────────────────────────────────────
   DESIGN CANVAS
   ────────────────────────────────────────────────────────────────────── */

/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, { SettingsPage, SETTINGS_PICKERS, SettingsWithPicker, ReaderCanvasBg, U15Artboard, PinDots, NumPad, PinOverlay, TTS_SPEEDS, TTSSheet, TTS_PARAS, TTSActiveReading, FlagBadge, AdminPanel, BOOKS_SHELF, SmallBookCard, ShelfToolbarScreen });
