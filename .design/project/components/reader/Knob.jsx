/* ============================================================================
   Nyan Read — Knob
   Compiled into the DS bundle; consume as window.<Namespace>.Knob.
   Props contract: ./Knob.d.ts
   ============================================================================ */

/* Concentric nested card — recessed muted fill at radius 16, one step inside
   the radius-28 sheet (arc parallel to the parent). The only knob style. */

const Knob = ({ label, hint, children }) => (
  <div style={{ background: "var(--nyan-overlay-field)", borderRadius: "var(--r-card-nested)", padding: 14 }}>
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 11 }}>
      <div style={{ font: "600 15px/1.2 var(--font-ui)", color: "var(--nyan-text)" }}>{label}</div>
      {hint && <div className="nyan-meta">{hint}</div>}
    </div>
    {children}
  </div>
);

export { Knob };
