/* ============================================================================
   Nyan Read — SearchField
   Compiled into the DS bundle; consume as window.<Namespace>.SearchField.
   Props contract: ./SearchField.d.ts
   ============================================================================ */

import { Icon } from "./Icon.jsx";

const { useRef } = React;

/* ── Search field ────────────────────────────────────────────────────────────
   The shelf / in-book search input. A real <input> (not a faux caret div): the
   leading glass tints matcha once there's a query, and a clear button appears.
   Controlled — pass `value` + `onChange`. 44px tall, --r-control radius, with the
   matcha focus ring shared by every focusable surface. */
const SearchField = ({ value = "", onChange, onClear, onSubmit, placeholder = "Search title or author", autoFocus = false, style }) => {
  const ref = useRef(null);
  const has = value.length > 0;
  return (
    <div style={{
      flex: 1, height: 44, display: "flex", alignItems: "center", gap: 10, padding: "0 12px",
      borderRadius: "var(--r-control)", background: "var(--nyan-surface)",
      border: "1.5px solid color-mix(in srgb, var(--nyan-divider) 50%, transparent)",
      transition: "border-color 140ms var(--ease-paper), box-shadow 140ms var(--ease-paper)",
      ...style,
    }}
      onFocusCapture={(e) => { e.currentTarget.style.borderColor = "var(--nyan-primary)"; e.currentTarget.style.boxShadow = "0 0 0 3px color-mix(in srgb, var(--nyan-primary) 12%, transparent)"; }}
      onBlurCapture={(e) => { e.currentTarget.style.borderColor = "color-mix(in srgb, var(--nyan-divider) 50%, transparent)"; e.currentTarget.style.boxShadow = "none"; }}
    >
      <Icon name="search" size={18} color={has ? "var(--nyan-primary)" : "var(--nyan-text-muted)"} style={{ flexShrink: 0 }} />
      <input
        ref={ref}
        value={value}
        autoFocus={autoFocus}
        placeholder={placeholder}
        onChange={(e) => onChange && onChange(e.target.value)}
        onKeyDown={(e) => { if (e.key === "Enter" && onSubmit) onSubmit(value); }}
        style={{
          all: "unset", flex: 1, minWidth: 0,
          font: "400 15px/1 var(--font-ui)", color: "var(--nyan-text)",
        }}
      />
      {has && (
        <button
          onClick={() => { onClear ? onClear() : onChange && onChange(""); ref.current && ref.current.focus(); }}
          aria-label="Clear search"
          style={{ all: "unset", cursor: "pointer", width: 22, height: 22, borderRadius: "50%", background: "color-mix(in srgb, var(--nyan-text) 12%, transparent)", display: "grid", placeItems: "center", flexShrink: 0 }}
        >
          <Icon name="close" size={12} color="var(--nyan-surface)" />
        </button>
      )}
    </div>
  );
};

export { SearchField };
