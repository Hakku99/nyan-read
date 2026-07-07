/* ============================================================================
   Nyan Read — NyanOptionSheet
   Compiled into the DS bundle; consume as window.<Namespace>.NyanOptionSheet.
   Props contract: ./NyanOptionSheet.d.ts
   ============================================================================ */

/* ── Option picker sheet (NyanOptionSheet) ────────────────────────────────
   The single bottom-sheet for "pick one of these" (theme preset, language,
   page-turn mode, reminder interval) AND "do one of these" (export data).
   Same floating-chrome doctrine as NyanBottomSheet: warm scrim + blur, inset
   sheet, all four corners, one soft lift. Drops into any position:relative
   frame as a sibling overlay.

   Props:
     title       sheet heading
     subtitle    optional one-line description
     options     array of string | { label, hint, swatch, icon }
     selected    index of the chosen option (radio variant)
     variant     "radio" (default — single-select list) | "action" (icon rows)
     onSelect    (index) => void — fires when an option is tapped
     onClose     dismiss handler (scrim tap + option select)                 */
const NyanOptionSheet = ({ title, subtitle, options = [], selected = 0, variant = "radio", onSelect, onClose, animateIn = true, style }) => (
  <div style={{ position: "absolute", inset: 0, zIndex: 50, ...style }}>
    <style>{"@keyframes nyanFade { from { opacity: 0; } to { opacity: 1; } } @keyframes nyanSlideUp { from { transform: translateY(120%); } to { transform: translateY(0); } }"}</style>
    <div onClick={onClose} style={{ position: "absolute", inset: 0, background: "var(--scrim)",
      backdropFilter: "blur(var(--scrim-blur))", WebkitBackdropFilter: "blur(var(--scrim-blur))", animation: animateIn ? "nyanFade 220ms ease-out" : "none" }} />
    <div style={{ position: "absolute", left: "var(--inset)", right: "var(--inset)", bottom: "var(--inset)",
      background: "var(--nyan-surface-raised)", border: "1px solid var(--chrome-edge)", borderRadius: "var(--r-sheet)",
      boxShadow: "var(--shadow-light-card)", overflow: "hidden", animation: animateIn ? "nyanSlideUp 280ms cubic-bezier(0.33,0.9,0.36,1)" : "none" }}>
      {/* grabber */}
      <div style={{ paddingTop: 10, display: "flex", justifyContent: "center" }}>
        <div style={{ width: 40, height: 5, borderRadius: 999, background: "var(--grabber)" }} />
      </div>
      {/* header — no ✕; dismiss via scrim tap or selecting an option */}
      <div style={{ padding: "12px 20px 8px" }}>
        <div style={{ font: "600 18px/1.2 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.1px" }}>{title}</div>
        {subtitle && <div style={{ font: "400 13px/1.38 var(--font-ui)", color: "var(--nyan-text-secondary)", marginTop: 4 }}>{subtitle}</div>}
      </div>
      {/* options */}
      <div style={{ padding: "4px 12px 16px", display: "flex", flexDirection: "column" }}>
        {options.map((raw, i) => {
          const o = typeof raw === "string" ? { label: raw } : raw;
          const isSel = variant === "radio" && i === selected;
          return (
            <button key={i} onClick={() => { if (onSelect) onSelect(i); if (onClose) onClose(); }} style={{ all: "unset", cursor: "pointer", boxSizing: "border-box",
              display: "flex", alignItems: "center", gap: 12, padding: "12px 12px", minHeight: 56, borderRadius: "var(--r-card-nested)",
              background: isSel ? "color-mix(in srgb, var(--nyan-primary) 8%, transparent)" : "transparent" }}>
              {o.swatch && (
                <div style={{ width: 30, height: 30, borderRadius: "var(--r-chip)", flexShrink: 0, background: o.swatch,
                  border: "1px solid color-mix(in srgb, var(--nyan-divider) 60%, transparent)" }} />
              )}
              {o.icon && (
                <div style={{ width: 36, height: 36, borderRadius: "var(--r-chip)", flexShrink: 0,
                  background: "color-mix(in srgb, var(--nyan-primary) 10%, var(--nyan-surface-muted))", display: "grid", placeItems: "center" }}>
                  <i className={`ph ph-${o.icon}`} style={{ fontSize: 18, color: "var(--nyan-primary)" }} />
                </div>
              )}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ font: `${isSel ? 600 : 500} 15px/1.2 var(--font-ui)`, color: isSel ? "var(--nyan-primary-deep)" : "var(--nyan-text)" }}>{o.label}</div>
                {o.hint && <div style={{ font: "400 12.5px/1.3 var(--font-ui)", color: "var(--nyan-text-secondary)", marginTop: 2 }}>{o.hint}</div>}
              </div>
              {variant === "radio" ? (
                <div style={{ width: 22, height: 22, borderRadius: "50%", flexShrink: 0, display: "grid", placeItems: "center",
                  border: `2px solid ${isSel ? "var(--nyan-primary)" : "color-mix(in srgb, var(--nyan-divider) 80%, transparent)"}` }}>
                  {isSel && <div style={{ width: 11, height: 11, borderRadius: "50%", background: "var(--nyan-primary)" }} />}
                </div>
              ) : (
                <i className="ph ph-caret-right" style={{ fontSize: 16, color: "var(--nyan-text-muted)", flexShrink: 0 }} />
              )}
            </button>
          );
        })}
      </div>
    </div>
  </div>
);

export { NyanOptionSheet };
