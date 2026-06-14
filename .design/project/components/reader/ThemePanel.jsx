/* ============================================================================
   Nyan Read — ThemePanel
   Compiled into the DS bundle; consume as window.<Namespace>.ThemePanel.
   Props contract: ./ThemePanel.d.ts
   ============================================================================ */

import { Knob } from "./Knob.jsx";
import { Icon } from "../primitives/Icon.jsx";

const ThemePanel = ({ t, setT }) => {
  const swatches = [
    { id: "cream", name: "Cream", preview: "var(--reader-bg-cream)", ink: "var(--reader-ink)" },
    { id: "sepia", name: "Sepia", preview: "var(--reader-bg-sepia)", ink: "var(--reader-ink-sepia)" },
    { id: "sumi", name: "Sumi", preview: "var(--reader-bg-sumi)", ink: "var(--reader-ink-sumi)" },
    { id: "charcoal", name: "Charcoal", preview: "var(--reader-bg-charcoal)", ink: "var(--reader-ink-charcoal)" },
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

export { ThemePanel };
