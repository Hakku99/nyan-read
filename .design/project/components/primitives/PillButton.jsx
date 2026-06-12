/* ============================================================================
   Nyan Read — PillButton
   Compiled into the DS bundle; consume as window.<Namespace>.PillButton.
   Props contract: ./PillButton.d.ts
   ============================================================================ */

import { Icon } from "./Icon.jsx";

/* ── Pill chip — the outline-on-select signature ──────────────────────────
   One option-chip treatment for the whole system (warmth, line-height, font,
   sort, theme...). Resting: recessed muted fill, no border. Selected: the
   fill drops away and a matcha-deep outline + matcha text takes over — the
   chip "lifts off the track". Radius is --r-chip (12), the deepest-nested
   member of the concentric family. */
const PillButton = ({ label, selected, onPress, icon, disabled = false, style }) => (
  <button
    onClick={disabled ? undefined : onPress}
    disabled={disabled}
    aria-pressed={selected}
    style={{
      all: "unset",
      cursor: disabled ? "default" : "pointer",
      boxSizing: "border-box",
      padding: "9px 16px",
      minWidth: 0,
      minHeight: 36,
      borderRadius: "var(--r-chip)",
      background: selected ? "transparent" : "var(--nyan-surface-muted)",
      color: selected ? "var(--nyan-primary-deep)" : "var(--nyan-text-secondary)",
      border: selected
        ? "1.5px solid var(--nyan-primary-deep)"
        : "1.5px solid transparent",
      font: "500 14px/1 var(--font-ui)",
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      gap: 6,
      opacity: disabled ? 0.4 : 1,
      transition: "color 160ms var(--ease-paper), border-color 160ms var(--ease-paper), background 160ms var(--ease-paper)",
      ...style,
    }}
  >
    {icon && <Icon name={icon} size={16} color={selected ? "var(--nyan-primary-deep)" : "var(--nyan-text-secondary)"} />}
    {label}
  </button>
);

export { PillButton };
