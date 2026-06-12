/* ============================================================================
   Nyan Read — DisplayPanel
   Compiled into the DS bundle; consume as window.<Namespace>.DisplayPanel.
   Props contract: ./DisplayPanel.d.ts
   ============================================================================ */

import { Knob } from "./Knob.jsx";
import { NyanSlider } from "../primitives/NyanSlider.jsx";
import { NyanSwitch } from "../primitives/NyanSwitch.jsx";
import { PillButton } from "../primitives/PillButton.jsx";

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

export { DisplayPanel };
