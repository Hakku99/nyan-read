/* ============================================================================
   Nyan Read — PdfControls
   Compiled into the DS bundle; consume as window.<Namespace>.PdfControls.
   Props contract: ./PdfControls.d.ts
   ============================================================================ */

import { Icon } from "../primitives/Icon.jsx";

/* ── PDF controls ─────────────────────────────────────────────────────────────
   The PDF-only transport the reflowable reader doesn't need: a zoom stepper and a
   "page X of N" jump control. A floating One Paper pill — inset, rounded, lightCard
   — meant to sit above the dock on PDF books. Steppers are 44px; the page field is
   a tap target that opens a go-to-page prompt (caller handles `onGoToPage`). */
const PdfControls = ({ page = 1, pageCount = 1, zoom = 1, minZoom = 0.5, maxZoom = 3, zoomStep = 0.25, onZoom, onPage, onGoToPage, style }) => {
  const stepBtn = (disabled) => ({ all: "unset", cursor: disabled ? "default" : "pointer", width: 44, height: 44, borderRadius: "var(--r-chip)", display: "grid", placeItems: "center", opacity: disabled ? 0.34 : 1 });
  const zPct = Math.round(zoom * 100);
  return (
    <div style={{
      display: "inline-flex", alignItems: "center", gap: 2,
      background: "var(--nyan-surface-raised)", borderRadius: 999,
      border: "1px solid var(--chrome-edge)", boxShadow: "var(--shadow-light-card)",
      padding: "4px 6px", ...style,
    }}>
      <button onClick={() => zoom > minZoom && onZoom && onZoom(Math.max(minZoom, +(zoom - zoomStep).toFixed(2)))} disabled={zoom <= minZoom} aria-label="Zoom out" style={stepBtn(zoom <= minZoom)}>
        <Icon name="remove" size={18} color="var(--nyan-text)" />
      </button>
      <span style={{ minWidth: 46, textAlign: "center", font: "500 13px/1 var(--font-mono)", color: "var(--nyan-text-secondary)", fontVariantNumeric: "tabular-nums" }}>{zPct}%</span>
      <button onClick={() => zoom < maxZoom && onZoom && onZoom(Math.min(maxZoom, +(zoom + zoomStep).toFixed(2)))} disabled={zoom >= maxZoom} aria-label="Zoom in" style={stepBtn(zoom >= maxZoom)}>
        <Icon name="add" size={18} color="var(--nyan-text)" />
      </button>

      <div style={{ width: "0.72px", height: 24, background: "color-mix(in srgb, var(--nyan-divider) 55%, transparent)", margin: "0 4px", flexShrink: 0 }} />

      <button onClick={() => page > 1 && onPage && onPage(page - 1)} disabled={page <= 1} aria-label="Previous page" style={stepBtn(page <= 1)}>
        <Icon name="chevron_left" size={20} color="var(--nyan-text-secondary)" />
      </button>
      <button onClick={onGoToPage} aria-label="Go to page" style={{ all: "unset", cursor: onGoToPage ? "pointer" : "default", height: 44, padding: "0 10px", borderRadius: "var(--r-chip)", display: "grid", placeItems: "center" }}>
        <span style={{ font: "500 13px/1 var(--font-ui)", color: "var(--nyan-text)", fontVariantNumeric: "tabular-nums" }}>{page} <span style={{ color: "var(--nyan-text-muted)" }}>/ {pageCount}</span></span>
      </button>
      <button onClick={() => page < pageCount && onPage && onPage(page + 1)} disabled={page >= pageCount} aria-label="Next page" style={stepBtn(page >= pageCount)}>
        <Icon name="chevron_right" size={20} color="var(--nyan-text-secondary)" />
      </button>
    </div>
  );
};

export { PdfControls };
