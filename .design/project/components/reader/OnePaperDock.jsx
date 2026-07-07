/* ============================================================================
   Nyan Read — OnePaperDock
   Compiled into the DS bundle; consume as window.<Namespace>.OnePaperDock.
   Props contract: ./OnePaperDock.d.ts
   ============================================================================ */

import { DockFooter } from "./DockFooter.jsx";

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
      background: "var(--nyan-surface-raised)",
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

export { OnePaperDock };
