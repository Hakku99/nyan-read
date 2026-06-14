/* ============================================================================
   Nyan Read — Screens: U1 Brightness · U2 Highlight Note Dialog · U3 Chapters (reader dock)
   ----------------------------------------------------------------------------
   Full-screen compositions assembled from components/*. Extracted verbatim from
   the bundle gallery so Claude Code can read/edit one screen without the HTML.
   Self-exports to window; the bundle HTML imports this then renders the gallery.
   ============================================================================ */

    const { useState, useEffect, useRef } = React;

    /* ─────────────────────────────────────────────────────────────────
       SHARED HELPERS
    ───────────────────────────────────────────────────────────────── */


    /* Simulated reader page — flat paper bg with prose */

    /* Applies data-theme="sumi" so all --nyan-* vars cascade correctly */


    /* ─────────────────────────────────────────────────────────────────
       U1 · BRIGHTNESS — One Paper model (two affordances, no glass HUD)
       The old centred frosted card is gone. Brightness now lives in:
         (a) an EDGE GESTURE — vertical drag on the left third of the page,
             surfacing a slim floating capsule (the daily, immersive path)
         (b) a TOP-BAR SUN POPOVER — discoverable affordance hung off the
             floating top bar; one inline NyanSlider, no full settings sheet
       Both use One Paper chrome: --nyan-surface, lightCard lift, --chrome-edge
       hairline, matcha fill, ring thumb.
    ───────────────────────────────────────────────────────────────── */

    /* (a) Edge-gesture capsule — a vertical fill on the left third */
    const BrightnessGestureHUD = ({ initVal = 0.65, dark = false }) => {
      const [val, setVal]       = useState(initVal);
      const [dragging, setDrag] = useState(false);
      const trackRef            = useRef(null);
      const clamped = Math.max(0.04, Math.min(1, val));
      const pct     = Math.round(clamped * 100);

      const seek = (e) => {
        if (!trackRef.current) return;
        const r = trackRef.current.getBoundingClientRect();
        const cy = e.touches ? e.touches[0].clientY : e.clientY;
        setVal(Math.max(0, Math.min(1, 1 - (cy - r.top) / r.height)));
      };
      useEffect(() => {
        if (!dragging) return;
        const mm = (e) => seek(e), mu = () => setDrag(false);
        window.addEventListener("mousemove", mm); window.addEventListener("mouseup", mu);
        window.addEventListener("touchmove", mm, { passive: true }); window.addEventListener("touchend", mu);
        return () => { window.removeEventListener("mousemove", mm); window.removeEventListener("mouseup", mu); window.removeEventListener("touchmove", mm); window.removeEventListener("touchend", mu); };
      }, [dragging]);

      return (
        <div style={{ position: "absolute", inset: 0 }}>
          {/* gesture affordance hint along the left third */}
          <div style={{ position: "absolute", left: 0, top: 0, bottom: 0, width: "33%",
            background: dark ? "rgba(169,182,144,0.05)" : "rgba(110,122,85,0.04)",
            borderRight: "1px dashed color-mix(in srgb, var(--nyan-primary) 22%, transparent)" }} />
          <div style={{ position: "absolute", left: 12, top: "50%", transform: "translateY(-50%)",
            display: "flex", flexDirection: "column", alignItems: "center", gap: 12,
            background: "var(--nyan-surface)", border: "1px solid var(--chrome-edge)",
            borderRadius: "var(--r-dock)", boxShadow: "var(--shadow-light-card)", padding: "16px 12px" }}>
            <i className="ph ph-sun" style={{ fontSize: 18, color: "var(--nyan-primary-deep)" }} />
            <div ref={trackRef} onMouseDown={(e) => { setDrag(true); seek(e); }} onTouchStart={(e) => { setDrag(true); seek(e); }}
              style={{ position: "relative", width: 8, height: 150, borderRadius: 999, cursor: "pointer", touchAction: "none",
                background: "color-mix(in srgb, var(--nyan-text) 12%, transparent)", overflow: "hidden" }}>
              <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: `${clamped * 100}%`,
                background: "var(--nyan-primary)", borderRadius: 999, transition: dragging ? "none" : "height 90ms ease" }} />
            </div>
            <i className="ph ph-moon" style={{ fontSize: 16, color: "var(--nyan-text-muted)" }} />
            <div style={{ font: "600 14px/1 var(--font-mono)", color: "var(--nyan-primary-deep)", fontVariantNumeric: "tabular-nums" }}>{pct}%</div>
          </div>
        </div>
      );
    };

    /* (b) Top-bar sun → centered Brightness dialog over a glass overlay.
       The dialog no longer hangs off the floating header — it lifts to the
       centre of the viewport, and the page behind recedes under a warm
       glassmorphism scrim (blur + saturate). The top bar stays as dimmed
       context with its sun control lit. */
    const BrightnessPopover = ({ initVal = 0.65, dark = false }) => {
      const [val, setVal] = useState(Math.round(initVal * 100));
      return (
        <div style={{ position: "absolute", inset: 0 }}>
          {/* floating top bar (inset, r-dock, lightCard) — context behind the glass */}
          <div style={{ position: "absolute", top: 52, left: "var(--inset)", right: "var(--inset)",
            background: "var(--nyan-surface)", border: "1px solid var(--chrome-edge)",
            borderRadius: "var(--r-dock)", boxShadow: "var(--shadow-light-card)",
            display: "flex", alignItems: "center", gap: 6, padding: "9px 8px" }}>
            <button style={{ all: "unset", cursor: "pointer", width: 40, height: 40, borderRadius: "var(--r-control)", display: "grid", placeItems: "center" }}><Icon name="arrow_back" size={21} /></button>
            <div style={{ flex: 1, minWidth: 0, padding: "0 2px" }}>
              <div style={{ font: "600 14px/1.2 var(--font-ui)", color: "var(--nyan-text)" }}>The Stillwater Diaries</div>
              <div style={{ font: "400 11.5px/1.2 var(--font-ui)", color: "var(--nyan-text-muted)" }}>Kana Mori</div>
            </div>
            {/* sun = active/lit */}
            <button style={{ all: "unset", cursor: "pointer", width: 40, height: 40, borderRadius: "var(--r-control)", display: "grid", placeItems: "center",
              background: "color-mix(in srgb, var(--nyan-primary) 14%, transparent)" }}><Icon name="wb_sunny" size={21} color="var(--nyan-primary-deep)" /></button>
            <button style={{ all: "unset", cursor: "pointer", width: 40, height: 40, borderRadius: "var(--r-control)", display: "grid", placeItems: "center" }}><Icon name="more_horiz" size={21} /></button>
          </div>

          {/* Glassmorphism overlay — warm-tinted, blurred + saturated, centres the dialog */}
          <div style={{ position: "absolute", inset: 0, zIndex: 20,
            background: dark
              ? "color-mix(in srgb, var(--nyan-bg) 42%, transparent)"
              : "color-mix(in srgb, var(--nyan-bg) 46%, transparent)",
            backdropFilter: "blur(13.6px) saturate(1.15)", WebkitBackdropFilter: "blur(13.6px) saturate(1.15)",
            display: "flex", alignItems: "center", justifyContent: "center", padding: 24 }}>

            {/* Centered brightness dialog */}
            <div style={{ width: "100%", maxWidth: 320,
              background: dark
                ? "color-mix(in srgb, var(--nyan-surface) 88%, transparent)"
                : "color-mix(in srgb, var(--nyan-surface) 82%, transparent)",
              border: "1px solid color-mix(in srgb, var(--nyan-surface) 70%, var(--chrome-edge))",
              borderRadius: "var(--r-sheet)", boxShadow: "var(--shadow-light-card)",
              backdropFilter: "blur(6px)", WebkitBackdropFilter: "blur(6px)",
              padding: 22 }}>

              {/* Header: sun badge + title */}
              <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 18 }}>
                <div style={{ width: 38, height: 38, borderRadius: "var(--r-control)", flexShrink: 0,
                  background: "color-mix(in srgb, var(--nyan-primary) 14%, transparent)",
                  display: "grid", placeItems: "center" }}>
                  <Icon name="wb_sunny" size={20} color="var(--nyan-primary-deep)" />
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ font: "600 17px/1.15 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.1px" }}>Brightness</div>
                  <div style={{ font: "400 12.5px/1.2 var(--font-ui)", color: "var(--nyan-text-muted)", marginTop: 2 }}>Adjust the reading light.</div>
                </div>
                <span style={{ font: "600 18px/1 var(--font-mono)", color: "var(--nyan-primary-deep)", fontVariantNumeric: "tabular-nums" }}>{val}%</span>
              </div>

              {/* Slider row */}
              <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                <Icon name="moon" size={18} color="var(--nyan-text-muted)" />
                <div style={{ flex: 1 }}><NyanSlider value={val} min={0} max={100} onChange={setVal} /></div>
                <Icon name="wb_sunny" size={18} color="var(--nyan-text-muted)" />
              </div>
            </div>
          </div>
        </div>
      );
    };

    const U1Artboard = ({ initVal, dark, mode }) => (
      <ThemeWrap dark={dark}>
        <ReaderBg dark={dark}>
          {mode === "popover"
            ? <BrightnessPopover initVal={initVal} dark={dark} />
            : <BrightnessGestureHUD initVal={initVal} dark={dark} />}
        </ReaderBg>
      </ThemeWrap>
    );


    /* ─────────────────────────────────────────────────────────────────
       U2 · HIGHLIGHT NOTE DIALOG
       Layout: color-badge title row · excerpt preview card ·
               5-swatch picker pill · multiline note input · Cancel / Save
    ───────────────────────────────────────────────────────────────── */
    const HL_SWATCHES = [
      { fill: "#F2E58A", ink: "#B89A2C", label: "Yellow" },
      { fill: "#A8D18D", ink: "#4E8A2D", label: "Green"  },
      { fill: "#9EC5E8", ink: "#2E6B96", label: "Blue"   },
      { fill: "#E8A0BF", ink: "#A84070", label: "Pink"   },
      { fill: "#F2BE7E", ink: "#B8662A", label: "Orange" },
    ];

    const EXCERPT_TEXT = "He set the lacquer cup down on the low table and looked, again, at the calligraphy hanging in the alcove.";
    const NOTE_TEXT    = "This moment of stillness mirrors the opening scene — the bell, the rain, and now the cup. A deliberate circularity.";

    const HighlightNoteDialog = ({ initColor = 0, initNote = "", dark = false }) => {
      const [ci,      setCi]      = useState(initColor);
      const [note,    setNote]    = useState(initNote);
      const [focused, setFocused] = useState(false);
      const [deleted, setDeleted] = useState(false);
      const restoreRef = useRef("");
      const sel = HL_SWATCHES[ci];

      const deleteNote = () => {
        restoreRef.current = note;
        setNote("");
        setFocused(false);
        setDeleted(true);
      };
      const undoDelete = () => {
        setNote(restoreRef.current);
        setDeleted(false);
      };

      const inputBorder = focused
        ? "1px solid color-mix(in srgb, var(--nyan-primary) 30%, transparent)"
        : "1px solid color-mix(in srgb, var(--nyan-divider) 42%, transparent)";

      return (
        <div style={{ position: "relative", width: "100%", maxWidth: 350 }}>
        <div style={{
          width: "100%",
          background: "var(--nyan-surface)",
          borderRadius: "var(--r-dock)",
          border: "1px solid var(--chrome-edge)",
          boxShadow: "var(--shadow-light-card)",
          padding: 18,
          display: "flex",
          flexDirection: "column",
        }}>

          {/* ── Title row ── */}
          <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 10 }}>
            {/* Color identity badge */}
            <div style={{
              width: 24, height: 24, borderRadius: "50%",
              background: `color-mix(in srgb, ${sel.ink} 12%, var(--nyan-surface))`,
              border: `1px solid color-mix(in srgb, ${sel.ink} 10%, transparent)`,
              display: "grid", placeItems: "center", flexShrink: 0,
              transition: "background 180ms ease",
            }}>
              <i className="ph ph-pencil-line" style={{ fontSize: 12, color: `color-mix(in srgb, ${sel.ink} 88%, var(--nyan-text))` }} />
            </div>
            <div style={{ flex: 1, font: "600 18px/1.16 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.1px" }}>
              Edit Note
            </div>
            {/* Delete — plain icon button (no boxed chrome), One Paper style */}
            <button onClick={deleteNote} aria-label="Delete note" style={{ all: "unset", cursor: "pointer", width: 40, height: 40, borderRadius: "var(--r-control)", display: "grid", placeItems: "center" }}>
              <i className="ph ph-trash" style={{ fontSize: 19, color: "var(--nyan-text-muted)" }} />
            </button>
          </div>

          {/* ── Excerpt preview card ── */}
          <div style={{
            background: `color-mix(in srgb, ${sel.ink} 6%, var(--nyan-surface-muted))`,
            border: `1px solid color-mix(in srgb, ${sel.ink} 14%, var(--nyan-divider))`,
            borderRadius: 16,
            padding: "9px 14px",
            display: "flex",
            alignItems: "flex-start",
            gap: 10,
            marginBottom: 12,
            minHeight: 48,
            transition: "background 200ms ease, border-color 200ms ease",
          }}>
            <div style={{
              width: 2.5, alignSelf: "stretch", flexShrink: 0, borderRadius: 99,
              background: `color-mix(in srgb, ${sel.ink} 65%, transparent)`,
              marginTop: 2, transition: "background 200ms ease",
            }} />
            <div style={{
              flex: 1, font: "500 13.5px/1.38 var(--font-ui)",
              color: "var(--nyan-text)", opacity: 0.88,
              display: "-webkit-box", WebkitLineClamp: 2,
              WebkitBoxOrient: "vertical", overflow: "hidden",
            }}>
              {EXCERPT_TEXT}
            </div>
          </div>

          {/* ── Color picker — clean filled swatches, matcha selection ring ── */}
          <div style={{
            background: "var(--nyan-surface-muted)",
            borderRadius: 16,
            padding: "10px 14px",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 16,
            marginBottom: 12,
          }}>
            {HL_SWATCHES.map((c, i) => {
              const active = i === ci;
              return (
                <button
                  key={i}
                  onClick={() => setCi(i)}
                  title={c.label}
                  style={{
                    all: "unset", cursor: "pointer",
                    width: 26, height: 26, borderRadius: "50%",
                    display: "grid", placeItems: "center",
                    background: c.fill,
                    boxShadow: active
                      ? "0 0 0 2px var(--nyan-surface-muted), 0 0 0 3px var(--nyan-primary-deep)"
                      : "inset 0 0 0 1px color-mix(in srgb, " + c.ink + " 20%, transparent)",
                    transition: "box-shadow 160ms var(--ease-paper)",
                  }}
                >
                </button>
              );
            })}
          </div>

          {/* ── Note textarea ── */}
          <div style={{
            background: "color-mix(in srgb, var(--nyan-surface-muted) 88%, var(--nyan-surface))",
            borderRadius: 16,
            border: inputBorder,
            padding: "12px 15px",
            minHeight: 82,
            marginBottom: 14,
            transition: "border-color 160ms ease",
          }}>
            <textarea
              value={note}
              onChange={(e) => setNote(e.target.value)}
              onFocus={() => setFocused(true)}
              onBlur={() => setFocused(false)}
              placeholder="Add a note…"
              style={{
                all: "unset",
                display: "block",
                width: "100%",
                minHeight: 58,
                font: "400 15px/1.42 var(--font-ui)",
                color: "var(--nyan-text)",
                resize: "none",
                boxSizing: "border-box",
              }}
            />
          </div>

          {/* ── Action row ── */}
          <div style={{ display: "flex", gap: 10, justifyContent: "flex-end" }}>
            <NyanPrimaryButton label="Cancel" variant="ghost" size="lg" />
            <NyanPrimaryButton label="Save" variant="primary" size="lg" />
          </div>
        </div>

        {/* ── Deletion notification — non-blocking toast, delete → undo ── */}
        {deleted && (
          <div style={{ position: "absolute", left: 0, right: 0, top: "calc(100% + 12px)" }}>
            <NyanResponse
              status="success"
              title="Note deleted"
              description="The highlight colour is kept on the passage."
              action={{ label: "Undo", onPress: undoDelete }}
              onDismiss={() => setDeleted(false)}
            />
          </div>
        )}
        </div>
      );
    };

    const U2Artboard = ({ initColor, initNote, dark }) => (
      <ThemeWrap dark={dark}>
        <ReaderBg dark={dark}>
          <div style={{
            position: "absolute", inset: 0,
            background: "var(--scrim)",
            backdropFilter: "blur(var(--scrim-blur))", WebkitBackdropFilter: "blur(var(--scrim-blur))",
            display: "flex", alignItems: "center", justifyContent: "center",
            padding: 20,
          }}>
            <HighlightNoteDialog initColor={initColor} initNote={initNote} dark={dark} />
          </div>
        </ReaderBg>
      </ThemeWrap>
    );


    /* ─────────────────────────────────────────────────────────────────
       U3 · CHAPTERS — strictly the One Paper reader dock, grown into a sheet.
       The dock footer (progress + chapter stepper + 3 actions) stays pinned;
       the page behind recedes under a warm scrim + blur. A "Jump to current
       chapter" button sits between the sort toggle and the list, scrolling the
       sheet back to the chapter you're reading.
    ───────────────────────────────────────────────────────────────── */
    const TOC_DATA = [
      "The Threshold", "What the Bell Knows", "A Cup of Still Water", "The Calligraphy",
      "Late Spring Evening", "Wisteria in Rain", "The Gate Across the River", "Honest Sounds",
      "A Name Long Forgotten", "Second Strike", "The Lacquer Tray", "Folding the Page",
      "Three Hundred Readings", "The Open Shoji", "What Each Petal Meant", "The Quiet Occasion",
      "Across the River", "The Rest of the Night",
    ];

    const ChapterDockSheet = ({ dark = false }) => {
      const [asc, setAsc]           = useState(true);
      const [curIndex, setCurIndex] = useState(2);
      const listWrapRef = useRef(null);
      const jumpToCurrent = () => {
        const wrap = listWrapRef.current;
        if (!wrap) return;
        const row = wrap.querySelector('[data-current="true"]');
        if (!row) return;
        // walk up to the nearest scrollable ancestor (the grown sheet body)
        let sc = wrap.parentElement;
        while (sc && !(sc.scrollHeight > sc.clientHeight + 1)) sc = sc.parentElement;
        if (!sc) return;
        const delta = row.getBoundingClientRect().top - sc.getBoundingClientRect().top;
        sc.scrollTop += delta - 12;
      };
      return (
        <React.Fragment>
          {/* page recede + warm scrim + blur */}
          <div style={{ position: "absolute", inset: 0, zIndex: 8, background: "var(--scrim)",
            backdropFilter: "blur(var(--scrim-blur))", WebkitBackdropFilter: "blur(var(--scrim-blur))" }} />
          <OnePaperDock
            visible
            sheetOpen
            title="Chapters"
            meta={`${TOC_DATA.length} chapters`}
            maxSheetHeight={dark ? 430 : 430}
            chapterIndex={curIndex}
            chapterCount={TOC_DATA.length}
            progress={(curIndex + 0.4) / TOC_DATA.length}
            activeAction="chapters"
            onAction={() => {}}
            onPrevChapter={() => setCurIndex((i) => Math.max(0, i - 1))}
            onNextChapter={() => setCurIndex((i) => Math.min(TOC_DATA.length - 1, i + 1))}
            onStopProp={false}
          >
            <SegmentedTabControl
              tabs={[{ label: "Ascending" }, { label: "Descending" }]}
              selected={asc ? 0 : 1}
              onChange={(i) => setAsc(i === 0)}
              style="subtle"
            />
            <div ref={listWrapRef} style={{ marginTop: 10, paddingBottom: 4 }}>
              <ReaderChapterList chapters={TOC_DATA} currentIndex={curIndex} ascending={asc} onSelect={setCurIndex} />
            </div>
            {/* Floating "Jump to current" — an extended FAB in the system's
               floating-action language (NyanFAB): deep-matcha fill, surface glyph,
               --r-dock radius, --shadow-light-card lift. Sticks to the bottom-RIGHT
               of the scrolling sheet so it stays reachable while browsing chapters;
               the wrapper ignores pointer events so list rows underneath stay tappable. */}
            <div style={{ position: "sticky", bottom: 10, display: "flex", justifyContent: "flex-end", pointerEvents: "none", zIndex: 3 }}>
              <button
                onClick={jumpToCurrent}
                style={{ all: "unset", boxSizing: "border-box", cursor: "pointer", pointerEvents: "auto", height: 44, padding: "0 18px", borderRadius: "var(--r-dock)", display: "inline-flex", alignItems: "center", gap: 8, background: "var(--nyan-primary-deep)", color: "var(--nyan-surface)", boxShadow: "var(--shadow-light-card)" }}
              >
                <i className="ph ph-crosshair-simple" style={{ fontSize: 17, color: "var(--nyan-surface)" }} />
                <span style={{ font: "600 13.5px/1 var(--font-ui)", color: "var(--nyan-surface)" }}>Jump to current</span>
              </button>
            </div>
          </OnePaperDock>
        </React.Fragment>
      );
    };

    const U3Artboard = ({ dark }) => (
      <ThemeWrap dark={dark}>
        <ReaderBg dark={dark}>
          <ChapterDockSheet dark={dark} />
        </ReaderBg>
      </ThemeWrap>
    );


    /* ─────────────────────────────────────────────────────────────────
       DESIGN CANVAS
    ───────────────────────────────────────────────────────────────── */

/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, { BrightnessGestureHUD, BrightnessPopover, U1Artboard, HL_SWATCHES, EXCERPT_TEXT, NOTE_TEXT, HighlightNoteDialog, U2Artboard, TOC_DATA, ChapterDockSheet, U3Artboard });
