/* ============================================================================
   Nyan Read — TextPanel
   Compiled into the DS bundle; consume as window.<Namespace>.TextPanel.
   Props contract: ./TextPanel.d.ts
   ============================================================================ */

import { Knob } from "./Knob.jsx";
import { NyanSlider } from "../primitives/NyanSlider.jsx";
import { PillButton } from "../primitives/PillButton.jsx";
import { Icon } from "../primitives/Icon.jsx";

/* shared stepper button style (font-size − / + ) */
const stepBtn = { all: "unset", cursor: "pointer", width: 44, height: 44, borderRadius: "var(--r-chip)", border: "1px solid var(--nyan-divider)", display: "grid", placeItems: "center", background: "var(--nyan-surface)" };

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
      <div style={{ marginTop: 12, padding: 14, background: "var(--nyan-surface-raised)", borderRadius: "var(--r-chip)", font: `400 ${t.fontSize}px/${t.lineHeight} ${t.serif ? "var(--font-serif)" : "var(--font-ui)"}`, color: "var(--nyan-text)" }}>The cat sat on the threshold for a long while. 喵阅</div>
    </Knob>
  </div>
);

export { TextPanel };
