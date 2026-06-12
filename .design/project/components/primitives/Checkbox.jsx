/* ============================================================================
   Nyan Read — Checkbox
   Compiled into the DS bundle; consume as window.<Namespace>.Checkbox.
   Props contract: ./Checkbox.d.ts
   ============================================================================ */

/* ── Checkbox ─────────────────────────────────────────────────────────────────
   Square select control (multi-select lists, settings opt-ins). Checked = matcha
   fill + cream tick; unchecked = hairline ring on surface. The hit area is padded
   to a full 44px square so it clears the minimum tap target while the visible box
   stays 22px. Space / Enter toggle. */
const Checkbox = ({ checked = false, onChange, disabled = false, size = 22, "aria-label": ariaLabel }) => (
  <button
    type="button"
    role="checkbox"
    aria-checked={checked}
    aria-label={ariaLabel}
    aria-disabled={disabled || undefined}
    onClick={() => !disabled && onChange && onChange(!checked)}
    style={{
      all: "unset", boxSizing: "border-box",
      display: "inline-flex", alignItems: "center", justifyContent: "center",
      minWidth: 44, minHeight: 44,
      cursor: disabled ? "default" : "pointer",
      opacity: disabled ? 0.4 : 1, flexShrink: 0,
    }}
  >
    <span style={{
      width: size, height: size, borderRadius: 7,
      background: checked ? "var(--nyan-primary)" : "var(--nyan-surface)",
      border: checked ? "1.5px solid var(--nyan-primary)" : "1.5px solid color-mix(in srgb, var(--nyan-text) 28%, transparent)",
      display: "grid", placeItems: "center",
      transition: "background 140ms var(--ease-paper), border-color 140ms var(--ease-paper)",
    }}>
      {checked && (
        <svg width={Math.round(size * 0.62)} height={Math.round(size * 0.62)} viewBox="0 0 24 24" fill="none" stroke="var(--nyan-surface)" strokeWidth="3.4" strokeLinecap="round" strokeLinejoin="round" style={{ display: "block" }}>
          <path d="M5 12.5 L10 17.5 L19 7" />
        </svg>
      )}
    </span>
  </button>
);

export { Checkbox };
