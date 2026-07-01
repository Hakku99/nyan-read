/* ============================================================================
   Nyan Read — NyanDialog
   Compiled into the DS bundle; consume as window.<Namespace>.NyanDialog.
   Props contract: ./NyanDialog.d.ts
   ============================================================================ */

import { Icon } from "../primitives/Icon.jsx";
import { NyanPrimaryButton } from "../primitives/NyanPrimaryButton.jsx";

const { useState, useEffect } = React;

/* ── Dialog (NyanDialog) ──────────────────────────────────────────────────────
   The centered confirm / alert dialog — the counterpart to NyanBottomSheet for
   decisions that need a yes/no, not a panel. Warm-ink scrim + blur, a floating
   --r-panel card, an optional tinted icon tile, title, message, and up to two
   actions. `tone="danger"` swaps the icon tile + confirm button to the warm-clay
   error tones (delete book, clear data). Mount/unmount is animated like the sheet. */
const NyanDialog = ({ open, onClose, icon, title, message, tone = "default", confirmLabel = "Confirm", cancelLabel = "Cancel", onConfirm, onCancel, hideCancel = false, children }) => {
  const [render, setRender] = useState(open);
  const [closing, setClosing] = useState(false);
  useEffect(() => {
    if (open) { setRender(true); setClosing(false); return; }
    if (!render) return;
    setClosing(true);
    const id = setTimeout(() => { setRender(false); setClosing(false); }, 200);
    return () => clearTimeout(id);
  }, [open]);
  if (!render) return null;
  const danger = tone === "danger";
  const tileBg = danger ? "var(--error-bg)" : "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))";
  const tileFg = danger ? "var(--error-primary)" : "var(--nyan-primary-deep)";
  return (
    <div style={{ position: "absolute", inset: 0, zIndex: 60, display: "grid", placeItems: "center", padding: 24 }}>
      <div onClick={onClose} style={{ position: "absolute", inset: 0, background: "var(--scrim)", backdropFilter: "blur(var(--scrim-blur))", WebkitBackdropFilter: "blur(var(--scrim-blur))", animation: closing ? "nyanDlgFadeOut 180ms ease-in forwards" : "nyanDlgFade 200ms ease-out" }} />
      <div role="dialog" aria-modal="true" aria-label={title} style={{
        position: "relative", width: "100%", maxWidth: 320,
        background: "var(--nyan-surface-raised, var(--nyan-surface))",
        borderRadius: "var(--r-panel)", border: "1px solid var(--chrome-edge)",
        boxShadow: "var(--shadow-light-card)", padding: "22px 20px 18px",
        display: "flex", flexDirection: "column", alignItems: "center", textAlign: "center", gap: 12,
        animation: closing ? "nyanDlgOut 180ms ease-in forwards" : "nyanDlgIn 240ms cubic-bezier(0.33,0.9,0.36,1)",
      }}>
        {icon && (
          <div style={{ width: 52, height: 52, borderRadius: "var(--r-card-nested)", background: tileBg, display: "grid", placeItems: "center" }}>
            <Icon name={icon} size={26} color={tileFg} />
          </div>
        )}
        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
          <div style={{ font: "600 18px/1.25 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.1px" }}>{title}</div>
          {message && <div style={{ font: "400 14px/1.45 var(--font-ui)", color: "var(--nyan-text-secondary)" }}>{message}</div>}
        </div>
        {children}
        <div style={{ display: "flex", gap: 8, width: "100%", marginTop: 4 }}>
          {!hideCancel && (
            <NyanPrimaryButton label={cancelLabel} variant="ghost" expanded onPress={onCancel || onClose} style={{ flex: 1, background: "color-mix(in srgb, var(--nyan-text) 6%, transparent)", color: "var(--nyan-text-secondary)" }} />
          )}
          <NyanPrimaryButton
            label={confirmLabel} expanded onPress={onConfirm}
            style={{ flex: 1, ...(danger ? { background: "var(--error-fill)", color: "var(--nyan-on-error)", boxShadow: "0 6px 16px -6px color-mix(in srgb, var(--error-fill) 60%, transparent)" } : null) }}
          />
        </div>
      </div>
      <style>{`
        @keyframes nyanDlgFade { from { opacity: 0; } to { opacity: 1; } }
        @keyframes nyanDlgFadeOut { from { opacity: 1; } to { opacity: 0; } }
        @keyframes nyanDlgIn { from { opacity: 0; transform: scale(0.94) translateY(8px); } to { opacity: 1; transform: none; } }
        @keyframes nyanDlgOut { from { opacity: 1; transform: none; } to { opacity: 0; transform: scale(0.96); } }
      `}</style>
    </div>
  );
};

export { NyanDialog };
