/* ============================================================================
   Nyan Read — TextField
   Compiled into the DS bundle; consume as window.<Namespace>.TextField.
   Props contract: ./TextField.d.ts
   ============================================================================ */

import { Icon } from "./Icon.jsx";

const { useState } = React;

/* ── Text field ───────────────────────────────────────────────────────────────
   The general single-line / multi-line text input (rename a book, write a note,
   go-to-page). Optional label above, optional leading icon, matcha focus ring,
   and an error state in the warm-clay error tones. Multiline renders a <textarea>.
   Controlled — pass `value` + `onChange`. */
const TextField = ({ value = "", onChange, label, placeholder, icon, multiline = false, rows = 3, error, disabled = false, onSubmit, style }) => {
  const [focused, setFocused] = useState(false);
  const ringColor = error ? "var(--error-primary)" : "var(--nyan-primary)";
  const borderColor = error
    ? "color-mix(in srgb, var(--error-primary) 55%, transparent)"
    : focused ? ringColor : "color-mix(in srgb, var(--nyan-divider) 55%, transparent)";
  const common = {
    all: "unset", flex: 1, minWidth: 0, boxSizing: "border-box",
    font: "400 15px/1.5 var(--font-ui)", color: "var(--nyan-text)", width: "100%",
  };
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 6, ...style }}>
      {label && <span style={{ font: "500 12px/1 var(--font-ui)", color: "var(--nyan-text-secondary)", letterSpacing: "0.1px" }}>{label}</span>}
      <div style={{
        display: "flex", alignItems: multiline ? "flex-start" : "center", gap: 9,
        padding: multiline ? "11px 12px" : "0 12px", minHeight: 44,
        background: disabled ? "var(--nyan-surface-muted)" : "var(--nyan-surface)",
        borderRadius: "var(--r-control)",
        border: `1.5px solid ${borderColor}`,
        boxShadow: focused && !error ? `0 0 0 3px color-mix(in srgb, ${ringColor} 12%, transparent)` : "none",
        transition: "border-color 140ms var(--ease-paper), box-shadow 140ms var(--ease-paper)",
        opacity: disabled ? 0.55 : 1,
      }}>
        {icon && <Icon name={icon} size={18} color={focused ? ringColor : "var(--nyan-text-muted)"} style={{ flexShrink: 0, marginTop: multiline ? 3 : 0 }} />}
        {multiline ? (
          <textarea
            value={value} rows={rows} placeholder={placeholder} disabled={disabled}
            onFocus={() => setFocused(true)} onBlur={() => setFocused(false)}
            onChange={(e) => onChange && onChange(e.target.value)}
            style={{ ...common, resize: "none" }}
          />
        ) : (
          <input
            value={value} placeholder={placeholder} disabled={disabled}
            onFocus={() => setFocused(true)} onBlur={() => setFocused(false)}
            onChange={(e) => onChange && onChange(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter" && onSubmit) onSubmit(value); }}
            style={common}
          />
        )}
      </div>
      {error && typeof error === "string" && (
        <span style={{ font: "400 12px/1.3 var(--font-ui)", color: "var(--error-primary)" }}>{error}</span>
      )}
    </div>
  );
};

export { TextField };
