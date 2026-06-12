/* ============================================================================
   Nyan Read — NyanContinueReadingCard
   Compiled into the DS bundle; consume as window.<Namespace>.NyanContinueReadingCard.
   Props contract: ./NyanContinueReadingCard.d.ts
   ============================================================================ */

import { Icon } from "../primitives/Icon.jsx";
import { NyanInfoCard } from "../surfaces/NyanInfoCard.jsx";
import { NyanPrimaryButton } from "../primitives/NyanPrimaryButton.jsx";

/* ── Continue reading card (NyanContinueReadingCard) ───────────────────────
   Latest design (U9): collapsible. Header (book glyph + "Continue Reading"
   eyebrow + caret) is always visible and toggles the body. Expanded shows a
   cover, title/author, a progress row, and a full-width matcha CTA that
   enters the book. Collapsed shrinks to a slim row carrying title + percent. */
const NyanContinueReadingCard = ({ book, onContinue, collapsed = false, onToggleCollapse, eyebrow = "Continue Reading", continueLabel = "Continue Reading" }) => {
  const pct = Math.round(book.progress * 100);
  return (
    <NyanInfoCard padding={0}>
      {/* Header — tap to collapse / expand */}
      <div
        onClick={onToggleCollapse}
        style={{ display: "flex", alignItems: "center", gap: 10, padding: collapsed ? "11px 14px" : "12px 14px 8px", cursor: onToggleCollapse ? "pointer" : "default" }}
      >
        <Icon name="menu_book" size={15} color="var(--nyan-primary)" />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ font: "500 11px/1.2 var(--font-ui)", color: "var(--nyan-text-muted)", letterSpacing: "0.2px" }}>{eyebrow}</div>
          {collapsed && (
            <div style={{ font: "600 13px/1.3 var(--font-ui)", color: "var(--nyan-text)", marginTop: 2, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{book.title}</div>
          )}
        </div>
        {collapsed && (
          <span style={{ font: "600 11px/1 var(--font-ui)", color: "var(--nyan-primary-deep)", flexShrink: 0 }}>{pct}%</span>
        )}
        {onToggleCollapse && (
          <Icon name="keyboard_arrow_down" size={18} color="var(--nyan-text-muted)" style={{ flexShrink: 0, transform: collapsed ? "none" : "rotate(180deg)", transition: "transform 200ms var(--ease-paper)" }} />
        )}
      </div>

      {/* Body — collapses away */}
      {!collapsed && (
        <div style={{ padding: "0 14px 14px" }}>
          <div style={{ display: "flex", gap: 12 }}>
            <div style={{ width: 56, height: 72, borderRadius: 14, background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface-muted))", border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)", flexShrink: 0, display: "grid", placeItems: "center" }}>
              <Icon name="menu_book" size={22} color="var(--nyan-primary)" />
            </div>
            <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", justifyContent: "center", gap: 8 }}>
              <div>
                <div style={{ font: "600 15px/1.3 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.1px", overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical" }}>{book.title}</div>
                {book.author && <div style={{ font: "400 12px/1.3 var(--font-ui)", color: "var(--nyan-text-muted)", marginTop: 2, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{book.author}</div>}
              </div>
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <div style={{ flex: 1, height: 4, borderRadius: 999, background: "color-mix(in srgb, var(--nyan-primary) 16%, var(--nyan-surface-muted))", overflow: "hidden" }}>
                  <div style={{ width: `${pct}%`, height: "100%", borderRadius: 999, background: "var(--nyan-primary)" }} />
                </div>
                <span style={{ font: "600 11px/1 var(--font-ui)", color: "var(--nyan-primary-deep)", flexShrink: 0 }}>{pct}%</span>
              </div>
            </div>
          </div>
          <div style={{ marginTop: 12 }}>
            <NyanPrimaryButton label={continueLabel} icon="menu_book" expanded onPress={onContinue} />
          </div>
        </div>
      )}
    </NyanInfoCard>
  );
};

export { NyanContinueReadingCard };
