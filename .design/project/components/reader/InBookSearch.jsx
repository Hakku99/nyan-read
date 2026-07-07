/* ============================================================================
   Nyan Read — InBookSearch
   Compiled into the DS bundle; consume as window.<Namespace>.InBookSearch.
   Props contract: ./InBookSearch.d.ts
   ============================================================================ */

import { Icon } from "../primitives/Icon.jsx";
import { SearchField } from "../primitives/SearchField.jsx";

/* ── In-book search bar ───────────────────────────────────────────────────────
   The find-in-book header strip: back, the shared SearchField, and a match
   stepper ("3 / 17" with ‹ ›) that appears once there are hits. A One Paper bar —
   surface, chrome-edge hairline, lightCard — meant to dock at the top of the
   reader. Caller owns the query + match cursor; this is the chrome around them. */
const InBookSearch = ({ value = "", onChange, onClose, matchIndex = 0, matchCount = 0, onPrevMatch, onNextMatch, style }) => {
  const hasMatches = matchCount > 0;
  const stepBtn = (disabled) => ({ all: "unset", cursor: disabled ? "default" : "pointer", width: 36, height: 36, borderRadius: "var(--r-chip)", display: "grid", placeItems: "center", opacity: disabled ? 0.32 : 1 });
  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 8, padding: "10px 12px",
      background: "var(--nyan-surface-raised)", borderBottom: "1px solid var(--chrome-edge)",
      boxShadow: "var(--shadow-subtle)", ...style,
    }}>
      <button onClick={onClose} aria-label="Close search" style={{ all: "unset", cursor: "pointer", width: 40, height: 40, borderRadius: "var(--r-control)", display: "grid", placeItems: "center", flexShrink: 0 }}>
        <Icon name="arrow_back" size={21} color="var(--nyan-text)" />
      </button>
      <SearchField value={value} onChange={onChange} placeholder="Find in book" autoFocus />
      {hasMatches ? (
        <div style={{ display: "flex", alignItems: "center", gap: 2, flexShrink: 0 }}>
          <span style={{ font: "500 12px/1 var(--font-mono)", color: "var(--nyan-text-secondary)", fontVariantNumeric: "tabular-nums", minWidth: 42, textAlign: "center" }}>{matchIndex + 1} / {matchCount}</span>
          <button onClick={onPrevMatch} aria-label="Previous match" style={stepBtn(false)}><Icon name="keyboard_arrow_up" size={18} color="var(--nyan-text-secondary)" /></button>
          <button onClick={onNextMatch} aria-label="Next match" style={stepBtn(false)}><Icon name="keyboard_arrow_down" size={18} color="var(--nyan-text-secondary)" /></button>
        </div>
      ) : value ? (
        <span style={{ font: "400 12px/1 var(--font-ui)", color: "var(--nyan-text-muted)", flexShrink: 0, paddingRight: 4 }}>No matches</span>
      ) : null}
    </div>
  );
};

export { InBookSearch };
