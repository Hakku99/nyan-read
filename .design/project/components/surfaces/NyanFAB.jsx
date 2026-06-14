/* ============================================================================
   Nyan Read — NyanFAB
   Compiled into the DS bundle; consume as window.<Namespace>.NyanFAB.
   Props contract: ./NyanFAB.d.ts
   ============================================================================ */

import { Icon } from "../primitives/Icon.jsx";

/* ── Floating action button ─────────────────────────────────────────────── */
const NyanFAB = ({ icon = "add", onPress, style }) => (
  <button onClick={onPress} style={{
    all: "unset", cursor: "pointer",
    width: 56, height: 56,
    background: "var(--nyan-primary-deep)",
    color: "var(--nyan-surface)",
    borderRadius: "var(--r-dock)",
    display: "grid", placeItems: "center",
    boxShadow: "var(--shadow-light-card)",
    position: "absolute", right: "var(--inset)", bottom: "var(--inset)",
    ...style,
  }}>
    <Icon name={icon} size={26} color="var(--nyan-surface)" />
  </button>
);

export { NyanFAB };
