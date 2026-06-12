/* ============================================================================
   Nyan Read — ProgressBar
   Compiled into the DS bundle; consume as window.<Namespace>.ProgressBar.
   Props contract: ./ProgressBar.d.ts
   ============================================================================ */

/* ── Progress bar ────────────────────────────────────────────────────────────
   The ONE reading-progress track for the whole system — replaces the five
   inline copies that lived in BookCard / BookListRow / ContinueCard / ImportRow
   / the dock. A matcha fill on a matcha-tint trough. `value` is 0–1; pass a
   `label` ("42%") to show a trailing tabular-nums caption. `height` defaults to
   the 3px shelf thickness; the dock uses 4–6. */
const ProgressBar = ({ value = 0, height = 3, label, color = "var(--nyan-primary)", style }) => {
  const pct = Math.max(0, Math.min(100, Math.round(value * 100)));
  const track = (
    <div
      role="progressbar"
      aria-valuenow={pct}
      aria-valuemin={0}
      aria-valuemax={100}
      style={{ flex: 1, height, borderRadius: 999, background: `color-mix(in srgb, ${color} 16%, var(--nyan-surface-muted))`, overflow: "hidden" }}
    >
      <div style={{ width: `${pct}%`, height: "100%", borderRadius: 999, background: color, transition: "width 320ms var(--ease-paper)" }} />
    </div>
  );
  if (label == null) return <div style={style}>{track}</div>;
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 8, ...style }}>
      {track}
      <span style={{ font: "600 11px/1 var(--font-ui)", color: "var(--nyan-primary-deep)", fontVariantNumeric: "tabular-nums", flexShrink: 0 }}>
        {label === true ? `${pct}%` : label}
      </span>
    </div>
  );
};

export { ProgressBar };
