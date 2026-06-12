/* ============================================================================
   Nyan Read — NyanPrimaryButton
   Compiled into the DS bundle; consume as window.<Namespace>.NyanPrimaryButton.
   Props contract: ./NyanPrimaryButton.d.ts
   ============================================================================ */

import { Icon } from "./Icon.jsx";

/* ── Primary button (NyanPrimaryButton) ──────────────────────────────────
   Heights are LOCKED, never grown by padding. Choose by `size`:
     sm = 36px  (in-card CTAs)
     md = 44px  (default body CTA · matches minTapTarget)
     lg = 52px  (hero / sticky bottom CTA only)
   Padding is horizontal only; the label is single-line with ellipsis. */
const NyanPrimaryButton = ({ label, onPress, icon, expanded = false, variant = "primary", size = "md", disabled = false, loading = false, style }) => {
  const height = size === "sm" ? 36 : size === "lg" ? 52 : 44;
  const padX   = size === "sm" ? 14 : size === "lg" ? 28 : 24;
  const fz     = size === "sm" ? 14 : size === "lg" ? 17 : 16;
  const iconSz = size === "sm" ? 16 : 18;
  const bg = variant === "deep" ? "var(--nyan-primary-deep)" : variant === "ghost" ? "transparent" : "var(--nyan-primary)";
  const fg = variant === "ghost" ? "var(--nyan-primary-deep)" : "var(--nyan-surface)";
  const inert = disabled || loading;
  return (
    <button
      onClick={inert ? undefined : onPress}
      disabled={inert}
      aria-busy={loading || undefined}
      style={{
        all: "unset",
        cursor: inert ? "default" : "pointer",
        boxSizing: "border-box",
        height,
        padding: `0 ${padX}px`,
        background: bg,
        color: fg,
        font: `${variant === "ghost" ? 600 : 500} ${fz}px/1 var(--font-ui)`,
        borderRadius: "var(--radius-input)",
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        gap: 6,
        width: expanded ? "100%" : "auto",
        textAlign: "center",
        flexShrink: 0,
        opacity: disabled ? 0.4 : 1,
        ...style,
      }}
    >
      {loading
        ? <span aria-hidden="true" style={{ width: iconSz, height: iconSz, borderRadius: "50%", border: `2px solid ${fg}`, borderTopColor: "transparent", display: "inline-block", animation: "nyanBtnSpin 600ms linear infinite" }} />
        : (icon && <Icon name={icon} size={iconSz} color={fg} />)}
      <span style={{ whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", minWidth: 0 }}>{label}</span>
      <style>{"@keyframes nyanBtnSpin { to { transform: rotate(360deg); } }"}</style>
    </button>
  );
};

export { NyanPrimaryButton };
