/* ============================================================================
   Nyan Read — Reader chrome — One Paper dock & settings body
   ----------------------------------------------------------------------------
   The reader paragraph, settings knobs/panels, shared ReaderSettingsBody, chapter list, dock footer, and the OnePaperDock shell (dock that grows into a sheet).
   Part of the split component library. Exports go to window so other Babel
   <script> blocks (galleries, screens, the live prototype) can use them.
   ============================================================================ */

const { useState, useEffect, useRef, useCallback, useMemo } = React;

/* ── Reading text body (inside reader canvas) ───────────────────────────── */
const ReaderParagraph = ({ children, serif = false, fontSize = 18, lineHeight = 1.75, color }) => (
  <p style={{
    font: `400 ${fontSize}px/${lineHeight} ${serif ? "var(--font-serif)" : "var(--font-ui)"}`,
    color: color || "var(--reader-ink)",
    margin: "0 0 1.2em 0",
    textIndent: "2em",
    textAlign: "justify",
    textWrap: "pretty",
  }}>{children}</p>
);

/* ════════════════════════════════════════════════════════════════════════
   ONE PAPER · shared reader chrome
   --------------------------------------------------------------------------
   The dock that grows into a sheet, the dock footer (progress + chapter
   stepper + 3 actions), and the reader sheet bodies. Extracted here so the
   live kit reader AND the spec bundles render the EXACT same chrome — one
   source of truth, no drift.
   ════════════════════════════════════════════════════════════════════════ */

/* Concentric nested card — recessed muted fill at radius 16, one step inside
   the radius-28 sheet (arc parallel to the parent). The only knob style. */

const Knob = ({ label, hint, children }) => (
  <div style={{ background: "var(--nyan-surface-muted)", borderRadius: "var(--r-card-nested)", padding: 14 }}>
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 11 }}>
      <div style={{ font: "600 15px/1.2 var(--font-ui)", color: "var(--nyan-text)" }}>{label}</div>
      {hint && <div className="nyan-meta">{hint}</div>}
    </div>
    {children}
  </div>
);


const DisplayPanel = ({ t, setT }) => (
  <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
    <Knob label="Brightness" hint="Adjust the reading light">
      <NyanSlider value={t.brightness} min={0} max={100} onChange={(v) => setT({ ...t, brightness: v })} />
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 10 }}>
        <div className="nyan-meta">Follow system brightness</div>
        <NyanSwitch value={t.autoBrightness} onChange={(v) => setT({ ...t, autoBrightness: v })} />
      </div>
    </Knob>
    <Knob label="Warmth" hint="Reduce glare at night">
      <NyanSlider value={{ low: 10, medium: 50, high: 90 }[t.warmth]} onChange={(v) => setT({ ...t, warmth: v < 33 ? "low" : v < 66 ? "medium" : "high" })} color="var(--hl-orange)" />
      <div style={{ display: "flex", gap: 8, marginTop: 12 }}>
        {["low", "medium", "high"].map((w) => (
          <PillButton key={w} label={w[0].toUpperCase() + w.slice(1)} selected={t.warmth === w} onPress={() => setT({ ...t, warmth: w })} style={{ flex: 1 }} />
        ))}
      </div>
    </Knob>
    <Knob label="Page Turn Mode">
      <div style={{ display: "flex", gap: 8 }}>
        {["tap", "swipe", "disabled"].map((m) => (
          <PillButton key={m} label={m[0].toUpperCase() + m.slice(1)} selected={t.pageTurn === m} onPress={() => setT({ ...t, pageTurn: m })} style={{ flex: 1 }} />
        ))}
      </div>
    </Knob>
  </div>
);


const TextPanel = ({ t, setT }) => (
  <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
    <Knob label="Font Size" hint="Larger or smaller">
      <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
        <button onClick={() => setT({ ...t, fontSize: Math.max(12, t.fontSize - 1) })} style={stepBtn}><Icon name="remove" size={17} color="var(--nyan-text)" /></button>
        <div style={{ flex: 1 }}><NyanSlider value={t.fontSize} min={12} max={28} onChange={(v) => setT({ ...t, fontSize: v })} /></div>
        <button onClick={() => setT({ ...t, fontSize: Math.min(28, t.fontSize + 1) })} style={stepBtn}><Icon name="add" size={17} color="var(--nyan-text)" /></button>
        <div style={{ font: "500 13px/1 var(--font-mono)", color: "var(--nyan-text-secondary)", minWidth: 34, textAlign: "right" }}>{t.fontSize}pt</div>
      </div>
    </Knob>
    <Knob label="Line Height" hint="Line spacing rhythm">
      <div style={{ display: "flex", gap: 8 }}>
        {[["Compact", 1.45], ["Standard", 1.75], ["Comfortable", 2.05]].map(([lbl, val]) => (
          <PillButton key={lbl} label={lbl} selected={Math.abs(t.lineHeight - val) < 0.05} onPress={() => setT({ ...t, lineHeight: val })} style={{ flex: 1, minWidth: 0, padding: "9px 6px", whiteSpace: "nowrap" }} />
        ))}
      </div>
    </Knob>
    <Knob label="Font Family">
      <div style={{ display: "flex", gap: 8 }}>
        <PillButton label="Sans" selected={!t.serif} onPress={() => setT({ ...t, serif: false })} style={{ flex: 1 }} />
        <PillButton label="Serif" selected={t.serif} onPress={() => setT({ ...t, serif: true })} style={{ flex: 1 }} />
      </div>
      <div style={{ marginTop: 12, padding: 14, background: "var(--nyan-surface)", borderRadius: "var(--r-chip)", font: `400 ${t.fontSize}px/${t.lineHeight} ${t.serif ? "var(--font-serif)" : "var(--font-ui)"}`, color: "var(--nyan-text)" }}>The cat sat on the threshold for a long while. 喵阅</div>
    </Knob>
  </div>
);


const ThemePanel = ({ t, setT }) => {
  const swatches = [
    { id: "cream", name: "Cream", preview: "#FFFCF5", ink: "#4A453E" },
    { id: "sepia", name: "Sepia", preview: "#F5ECD8", ink: "#5C4F3F" },
    { id: "sumi", name: "Sumi", preview: "#302D2B", ink: "#E5DED3" },
    { id: "charcoal", name: "Charcoal", preview: "#1B1A19", ink: "#F1EBDD" },
  ];
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
      <Knob label="Reading Theme">
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
          {swatches.map((s) => {
            const selected = t.readerTheme === s.id;
            return (
              <div key={s.id} onClick={() => setT({ ...t, readerTheme: s.id })} style={{ cursor: "pointer", padding: 12, background: s.preview, borderRadius: "var(--r-card-nested)", border: selected ? "1.5px solid var(--nyan-primary)" : "1.5px solid transparent", position: "relative", height: 74, display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
                <div style={{ font: "600 14px/1 var(--font-ui)", color: s.ink }}>{s.name}</div>
                <div style={{ font: "400 13px/1 var(--font-serif)", color: s.ink, opacity: 0.72 }}>Aa 永</div>
                {selected && <div style={{ position: "absolute", top: 8, right: 8, width: 22, height: 22, borderRadius: "50%", background: "var(--nyan-primary)", display: "grid", placeItems: "center" }}><Icon name="check" size={13} color="var(--nyan-surface)" /></div>}
              </div>
            );
          })}
        </div>
      </Knob>
    </div>
  );
};

/* Chromeless settings body: tab switcher + active panel. The dock supplies the
   surface, grabber, header, and footer — this is just the controls. */

const ReaderSettingsBody = ({ t, setT, tab, setTab }) => (
  <div>
    <SegmentedTabControl style="subtle" selected={tab} onChange={setTab} tabs={[{ label: "Display" }, { label: "Text" }, { label: "Theme" }]} />
    <div style={{ paddingTop: 14 }}>
      {tab === 0 && <DisplayPanel t={t} setT={setT} />}
      {tab === 1 && <TextPanel t={t} setT={setT} />}
      {tab === 2 && <ThemePanel t={t} setT={setT} />}
    </div>
  </div>
);

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

/* Dock footer — the persistent base of the One Paper panel:
   a chapter stepper flanking the progress bar, then the 3 actions.
   Stepper carets are the ONLY chapter-nav affordance in the model. */

const DockFooter = ({ chapterIndex, chapterCount, progress, activeAction, onAction, onPrevChapter, onNextChapter, sheetOpen, actions }) => {
  const acts = actions || [
    { key: "chapters", icon: "format_list_bulleted", label: "Chapters" },
    { key: "bookmarks", icon: "bookmark_border", label: "Bookmarks" },
    { key: "highlights", icon: "highlighter", label: "Highlights" },
    { key: "settings", icon: "title", label: "Settings" },
  ];
  const atStart = chapterIndex <= 0;
  const atEnd = chapterIndex >= chapterCount - 1;
  const step = (disabled) => ({ all: "unset", cursor: disabled ? "default" : "pointer", width: 36, height: 36, flex: "none", borderRadius: "var(--r-chip)", display: "grid", placeItems: "center", opacity: disabled ? 0.32 : 1 });
  return (
    <div style={{ borderTop: sheetOpen ? "1px solid var(--nyan-divider)" : "1px solid transparent", transition: "border-color 200ms var(--ease-paper)" }}>
      {/* Progress + chapter stepper — the dock's resting context. Folds away when
         a sheet is open: the sheet shows its own title/meta, so the stepper here
         would be redundant. The 3 actions stay, keeping it "one object." */}
      {!sheetOpen && (
        <div style={{ display: "flex", alignItems: "center", gap: 6, padding: "11px 10px 3px" }}>
          <button onClick={atStart ? undefined : onPrevChapter} style={step(atStart)} title="Previous chapter"><Icon name="chevron_left" size={20} color="var(--nyan-text-secondary)" /></button>
          <div style={{ flex: 1 }}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 8 }}>
              <span style={{ font: "400 12px/1 var(--font-ui)", color: "var(--nyan-text-muted)" }}>Chapter {chapterIndex + 1} of {chapterCount}</span>
              <span style={{ font: "500 12px/1 var(--font-mono)", color: "var(--nyan-text-secondary)" }}>{Math.round(progress * 100)}%</span>
            </div>
            <div style={{ height: 4, borderRadius: 999, background: "color-mix(in srgb, var(--nyan-text) 11%, transparent)", overflow: "hidden" }}>
              <div style={{ width: `${progress * 100}%`, height: "100%", background: "var(--nyan-primary)", borderRadius: 999 }} />
            </div>
          </div>
          <button onClick={atEnd ? undefined : onNextChapter} style={step(atEnd)} title="Next chapter"><Icon name="chevron_right" size={20} color="var(--nyan-text-secondary)" /></button>
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

/* OnePaperDock — the floating panel that is a DOCK when collapsed and a SHEET
   when grown. Same width, inset, surface, shadow either way; radius eases
   24 → 28. Provide `sheetOpen` + `title`/`meta`/`children` for the grown body;
   the footer (DockFooter) is always pinned at the base.
   Place inside a position:relative reader frame; pass `visible` for immersive
   toggling. The parent owns the canvas recede + scrim. */

const OnePaperDock = ({ visible = true, sheetOpen = false, title, meta, children, maxSheetHeight = 520, onStopProp = true, ...footer }) => (
  <div
    onClick={onStopProp ? (e) => e.stopPropagation() : undefined}
    style={{
      position: "absolute", zIndex: 9, left: "var(--inset)", right: "var(--inset)", bottom: "var(--inset)",
      background: "var(--nyan-surface)",
      border: "1px solid var(--chrome-edge)",
      borderRadius: sheetOpen ? "var(--r-sheet)" : "var(--r-dock)",
      boxShadow: "var(--shadow-light-card)",
      overflow: "hidden",
      transform: visible ? "none" : "translateY(140%)",
      opacity: visible ? 1 : 0,
      pointerEvents: visible ? "auto" : "none",
      transition: "transform var(--dur-grow) var(--ease-paper), border-radius 260ms var(--ease-paper), opacity var(--dur-chrome) var(--ease-paper)",
    }}
  >
    <div style={{ maxHeight: sheetOpen ? maxSheetHeight : 0, overflow: "hidden", transition: "max-height var(--dur-grow) var(--ease-paper)" }}>
      <div style={{ maxHeight: maxSheetHeight, overflowY: "auto", padding: "0 14px 8px" }}>
        <div style={{ width: 40, height: 5, borderRadius: 999, background: "var(--grabber)", margin: "10px auto 4px" }} />
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between", padding: "6px 2px 12px" }}>
          <div style={{ font: "600 20px/1.2 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.2px" }}>{title}</div>
          {meta && <div className="nyan-meta">{meta}</div>}
        </div>
        {children}
      </div>
    </div>
    <DockFooter sheetOpen={sheetOpen} {...footer} />
  </div>
);


const stepBtn = { all: "unset", cursor: "pointer", width: 34, height: 34, borderRadius: "var(--r-chip)", border: "1px solid var(--nyan-divider)", display: "grid", placeItems: "center", background: "var(--nyan-surface)" };


/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, { ReaderParagraph, Knob, DisplayPanel, TextPanel, ThemePanel, ReaderSettingsBody, ReaderChapterList, DockFooter, OnePaperDock });
