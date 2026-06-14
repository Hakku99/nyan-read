/* ============================================================================
   Nyan Read — ReaderSettingsBody
   Compiled into the DS bundle; consume as window.<Namespace>.ReaderSettingsBody.
   Props contract: ./ReaderSettingsBody.d.ts
   ============================================================================ */

import { SegmentedTabControl } from "../primitives/SegmentedTabControl.jsx";
import { DisplayPanel } from "./DisplayPanel.jsx";
import { TextPanel } from "./TextPanel.jsx";
import { ThemePanel } from "./ThemePanel.jsx";

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

export { ReaderSettingsBody };
