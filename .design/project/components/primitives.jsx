/* ============================================================================
   Nyan Read — Primitives — inputs & controls
   ----------------------------------------------------------------------------
   Icon, buttons, switch, segmented control, slider. The atoms everything else is built from.
   Part of the split component library. Exports go to window so other Babel
   <script> blocks (galleries, screens, the live prototype) can use them.
   ============================================================================ */

const { useState, useEffect, useRef, useCallback, useMemo } = React;

/* ── Icon shortcut ───────────────────────────────────────────────────────
   Renders Phosphor Regular icons. Accepts Material-style names (menu_book,
   bookmark, chevron_right, ...) and maps them to Phosphor's kebab-case
   equivalents — so callers stay legible and source-aligned.
   See preview/iconography.html for rationale on the Phosphor swap. */
const MATERIAL_TO_PHOSPHOR = {
  menu_book: "book-open", bookmark: "bookmark-simple",
  bookmark_border: "bookmark-simple", lock: "lock-simple",
  lock_open: "lock-simple-open", add: "plus", remove: "minus",
  settings: "gear-six", search: "magnifying-glass",
  more_horiz: "dots-three", chevron_right: "caret-right", chevron_left: "caret-left", check: "check",
  keyboard_arrow_up: "caret-up", keyboard_arrow_down: "caret-down",
  arrow_back: "arrow-left", close: "x", share: "share-network",
  ios_share: "share-fat", delete: "trash", delete_outline: "trash",
  alarm: "alarm", auto_stories: "books", view_list: "list",
  grid_view: "squares-four", sort: "arrows-down-up", schedule: "clock",
  library_add: "book-bookmark", title: "text-aa", palette: "palette",
  language: "translate", format_size: "text-aa",
  cloud_download: "cloud-arrow-down", cloud_upload: "cloud-arrow-up",
  auto_awesome: "sparkle", folder_open: "folder-open",
  content_copy: "copy", tune: "sliders-horizontal",
  format_list_bulleted: "list-bullets", wb_sunny: "sun", block: "prohibit",
};
const Icon = ({ name, size = 20, color, style, onClick }) => {
  const phName = MATERIAL_TO_PHOSPHOR[name] || name.replace(/_/g, "-");
  const baseClass = name === "bookmark" ? "ph-fill" : "ph";
  return (
    <i
      className={`${baseClass} ph-${phName}`}
      onClick={onClick}
      style={{ fontSize: size, color: color || "var(--nyan-text)", lineHeight: 1, display: "inline-flex", alignItems: "center", justifyContent: "center", ...style }}
    />
  );
};


/* ── Primary button (NyanPrimaryButton) ──────────────────────────────────
   Heights are LOCKED, never grown by padding. Choose by `size`:
     sm = 36px  (in-card CTAs)
     md = 44px  (default body CTA · matches minTapTarget)
     lg = 52px  (hero / sticky bottom CTA only)
   Padding is horizontal only; the label is single-line with ellipsis. */
const NyanPrimaryButton = ({ label, onPress, icon, expanded = false, variant = "primary", size = "md", style }) => {
  const height = size === "sm" ? 36 : size === "lg" ? 52 : 44;
  const padX   = size === "sm" ? 14 : size === "lg" ? 28 : 24;
  const fz     = size === "sm" ? 14 : size === "lg" ? 17 : 16;
  const iconSz = size === "sm" ? 16 : 18;
  const bg = variant === "deep" ? "var(--nyan-primary-deep)" : variant === "ghost" ? "transparent" : "var(--nyan-primary)";
  const fg = variant === "ghost" ? "var(--nyan-primary-deep)" : "var(--nyan-surface)";
  return (
    <button
      onClick={onPress}
      style={{
        all: "unset",
        cursor: "pointer",
        boxSizing: "border-box",
        height,
        padding: `0 ${padX}px`,
        background: bg,
        color: fg,
        font: `${variant === "ghost" ? 600 : 500} ${fz}px/1 var(--font-ui)`,
        borderRadius: "var(--radius-input)",
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        gap: 6,
        width: expanded ? "100%" : "auto",
        textAlign: "center",
        flexShrink: 0,
        ...style,
      }}
    >
      {icon && <Icon name={icon} size={iconSz} color={fg} />}
      <span style={{ whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", minWidth: 0 }}>{label}</span>
    </button>
  );
};


/* ── Pill chip — the outline-on-select signature ──────────────────────────
   One option-chip treatment for the whole system (warmth, line-height, font,
   sort, theme...). Resting: recessed muted fill, no border. Selected: the
   fill drops away and a matcha-deep outline + matcha text takes over — the
   chip "lifts off the track". Radius is --r-chip (12), the deepest-nested
   member of the concentric family. */
const PillButton = ({ label, selected, onPress, icon, style }) => (
  <button
    onClick={onPress}
    style={{
      all: "unset",
      cursor: "pointer",
      boxSizing: "border-box",
      padding: "9px 16px",
      minWidth: 0,
      minHeight: 36,
      borderRadius: "var(--r-chip)",
      background: selected ? "transparent" : "var(--nyan-surface-muted)",
      color: selected ? "var(--nyan-primary-deep)" : "var(--nyan-text-secondary)",
      border: selected
        ? "1.5px solid var(--nyan-primary-deep)"
        : "1.5px solid transparent",
      font: "500 14px/1 var(--font-ui)",
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      gap: 6,
      transition: "color 160ms var(--ease-paper), border-color 160ms var(--ease-paper), background 160ms var(--ease-paper)",
      ...style,
    }}
  >
    {icon && <Icon name={icon} size={16} color={selected ? "var(--nyan-primary-deep)" : "var(--nyan-text-secondary)"} />}
    {label}
  </button>
);


/* ── Switch (Material-ish, Nyan-tinted) ──────────────────────────────────── */
const NyanSwitch = ({ value, onChange }) => (
  <div
    onClick={() => onChange(!value)}
    style={{
      width: 44, height: 26, borderRadius: 999,
      background: value ? "var(--nyan-primary)" : "color-mix(in srgb, var(--nyan-divider) 100%, transparent)",
      position: "relative", cursor: "pointer", transition: "background 150ms ease",
      flexShrink: 0,
    }}
  >
    <div style={{
      position: "absolute", top: 3, left: value ? 21 : 3,
      width: 20, height: 20, background: "var(--nyan-surface)", borderRadius: "50%",
      boxShadow: "0 1px 2px rgba(0,0,0,0.08)", transition: "left 200ms ease",
    }} />
  </div>
);


/* ── Segmented tab control (NyanSegmentedTabControl) ─────────────────────────
   ONE recessed-track style for the whole system — top-level views AND sort.
   The track is recessed by TONE (surface-muted), never a border; the selected
   segment is a floating paper chip (surface + grouped shadow) that slides.
   Selected text is always matcha-deep — the single raised voice.
   `style="subtle"` swaps the white chip for a matcha-tint chip (same family). */
const SegmentedTabControl = ({ tabs, selected, onChange, style = "emphasis" }) => {
  const subtle = style === "subtle";
  return (
    <div style={{
      height: 40,
      background: "var(--nyan-surface-muted)",
      borderRadius: "var(--r-control)",
      padding: 4,
      display: "grid",
      gridTemplateColumns: `repeat(${tabs.length}, 1fr)`,
      position: "relative",
    }}>
      <div style={{
        position: "absolute", top: 4, bottom: 4,
        left: `calc(${(selected / tabs.length) * 100}% + 4px)`,
        width: `calc(${100 / tabs.length}% - 8px)`,
        background: subtle
          ? "color-mix(in srgb, var(--nyan-primary) 16%, transparent)"
          : "var(--nyan-surface)",
        borderRadius: "calc(var(--r-control) - 3px)",
        boxShadow: subtle ? "none" : "var(--shadow-grouped)",
        transition: "left var(--dur-chrome) var(--ease-paper)",
      }} />
      {tabs.map((t, i) => {
        const isSel = i === selected;
        const color = isSel
          ? "var(--nyan-primary-deep)"
          : "var(--nyan-text-secondary)";
        return (
          <button
            key={i}
            onClick={() => onChange(i)}
            style={{
              all: "unset", cursor: "pointer", position: "relative",
              display: "flex", alignItems: "center", justifyContent: "center", gap: 6,
              color, font: "500 14px/1 var(--font-ui)", zIndex: 1, padding: "0 4px",
              textAlign: "center",
            }}
          >
            {t.icon && <Icon name={t.icon} size={16} color={color} />}
            <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{t.label}</span>
          </button>
        );
      })}
    </div>
  );
};


/* ── Slider (used in reader settings) ───────────────────────────────────── */
const NyanSlider = ({ value, min = 0, max = 100, onChange, color = "var(--nyan-primary-deep)" }) => {
  const trackRef = useRef(null);
  const onPointer = (e) => {
    const rect = trackRef.current.getBoundingClientRect();
    const x = (e.touches ? e.touches[0].clientX : e.clientX) - rect.left;
    const pct = Math.max(0, Math.min(1, x / rect.width));
    onChange(Math.round(min + pct * (max - min)));
  };
  const [dragging, setDragging] = useState(false);
  useEffect(() => {
    if (!dragging) return;
    const move = (e) => onPointer(e);
    const up = () => setDragging(false);
    window.addEventListener("mousemove", move);
    window.addEventListener("mouseup", up);
    window.addEventListener("touchmove", move);
    window.addEventListener("touchend", up);
    return () => {
      window.removeEventListener("mousemove", move);
      window.removeEventListener("mouseup", up);
      window.removeEventListener("touchmove", move);
      window.removeEventListener("touchend", up);
    };
  }, [dragging]);
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <div
      ref={trackRef}
      onMouseDown={(e) => { setDragging(true); onPointer(e); }}
      onTouchStart={(e) => { setDragging(true); onPointer(e); }}
      style={{ position: "relative", height: 24, display: "flex", alignItems: "center", cursor: "pointer", touchAction: "none" }}
    >
      <div style={{ position: "absolute", left: 0, right: 0, height: 6, background: "color-mix(in srgb, var(--nyan-text) 12%, transparent)", borderRadius: 999 }} />
      <div style={{ position: "absolute", left: 0, width: `${pct}%`, height: 6, background: color, borderRadius: 999 }} />
      {/* ring thumb — surface fill, matcha ring + soft lift (matches the blueprint) */}
      <div style={{
        position: "absolute", left: `calc(${pct}% - 10px)`,
        width: 20, height: 20, background: "var(--nyan-surface)", borderRadius: "50%",
        boxShadow: `0 1px 4px color-mix(in srgb, var(--shadow-color) 28%, transparent), 0 0 0 1.5px color-mix(in srgb, ${color} 60%, transparent)`,
      }} />
    </div>
  );
};


/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, { Icon, NyanPrimaryButton, PillButton, NyanSwitch, SegmentedTabControl, NyanSlider });
