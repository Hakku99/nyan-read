/* ============================================================================
   Nyan Read — NyanSwitch
   Compiled into the DS bundle; consume as window.<Namespace>.NyanSwitch.
   Props contract: ./NyanSwitch.d.ts
   ============================================================================ */

/* ── Switch (Material-ish, Nyan-tinted) ──────────────────────────────────────
   The visible track is 44×26, but the hit area is padded out to a full 44px
   square so it clears the minimum tap target. Keyboard: Space / Enter toggle. */
const NyanSwitch = ({ value, onChange, disabled = false, "aria-label": ariaLabel }) => (
  <button
    type="button"
    role="switch"
    aria-checked={value}
    aria-label={ariaLabel}
    aria-disabled={disabled || undefined}
    onClick={() => !disabled && onChange(!value)}
    style={{
      all: "unset",
      boxSizing: "border-box",
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      minWidth: 44, minHeight: 44,
      cursor: disabled ? "default" : "pointer",
      opacity: disabled ? 0.4 : 1,
      flexShrink: 0,
    }}
  >
    <span style={{
      width: 44, height: 26, borderRadius: 999,
      background: value ? "var(--nyan-primary)" : "var(--nyan-divider)",
      position: "relative", transition: "background 150ms ease",
      display: "block", flexShrink: 0,
    }}>
      <span style={{
        position: "absolute", top: 3, left: value ? 21 : 3,
        width: 20, height: 20, background: "var(--nyan-surface)", borderRadius: "50%",
        boxShadow: "0 1px 2px rgba(0,0,0,0.08)", transition: "left 200ms ease",
      }} />
    </span>
  </button>
);

export { NyanSwitch };
