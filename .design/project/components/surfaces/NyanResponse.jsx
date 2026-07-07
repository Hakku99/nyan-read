/* ============================================================================
   Nyan Read — NyanResponse
   Compiled into the DS bundle; consume as window.<Namespace>.NyanResponse.
   Props contract: ./NyanResponse.d.ts
   ============================================================================ */

/* ── Response feedback (NyanResponse) ─────────────────────────────────────
   The single shared "what just happened" surface — shown after any action
   completes, fails, is skipped, or is mid-flight. One toast for the whole
   system so confirmations read the same everywhere (delete → undo, import →
   done, move to Privacy → skipped).

   Floating chrome doctrine: insets --inset from the edge, all four corners
   rounded (--r-card-nested), lifts on the quiet --shadow-subtle (the token
   reserved for toasts). No scrim — a response is non-blocking.

   Props:
     status      "success" | "error" | "skipped" | "info" | "loading"
     title       short line — Title Case, calm (e.g. "Bookmark deleted")
     description optional sentence-case detail
     action      { label, onPress } — one trailing ghost action (e.g. Undo)
     onDismiss   shows a quiet ✕; omit for auto-dismiss toasts
     placement   "bottom" (float inset at base of a relative parent) | "static"
*/
const NYAN_RESPONSE_STATUS = {
  success: { icon: "check-circle",   spin: false, fg: "var(--nyan-success)",
             tile: "color-mix(in srgb, var(--nyan-success) 13%, var(--nyan-surface))" },
  error:   { icon: "warning-circle", spin: false, fg: "var(--error-primary)",
             tile: "var(--error-bg)" },
  skipped: { icon: "skip-forward",   spin: false, fg: "var(--nyan-text-muted)",
             tile: "var(--nyan-surface-muted)" },
  info:    { icon: "info",           spin: false, fg: "var(--reader-info-blue)",
             tile: "color-mix(in srgb, var(--reader-info-blue) 13%, var(--nyan-surface))" },
  loading: { icon: "circle-notch",   spin: true,  fg: "var(--nyan-primary)",
             tile: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))" },
};

const NyanResponse = ({ status = "success", title, description, action, onDismiss, placement = "static", style }) => {
  const s = NYAN_RESPONSE_STATUS[status] || NYAN_RESPONSE_STATUS.success;
  const card = (
    <div
      role="status"
      style={{
        display: "flex", alignItems: "center", gap: 12,
        background: "var(--nyan-surface-raised)",
        border: "1px solid var(--chrome-edge)",
        borderRadius: "var(--r-card-nested)",
        boxShadow: "var(--shadow-subtle)",
        padding: "10px 12px",
        minHeight: 56,
        ...(placement === "static" ? style : null),
      }}
    >
      <div style={{
        width: 36, height: 36, flexShrink: 0, borderRadius: "var(--r-chip)",
        background: s.tile, display: "grid", placeItems: "center",
      }}>
        <i className={`ph ph-${s.icon}`} style={{ fontSize: 20, color: s.fg,
          animation: s.spin ? "nyan-spin 900ms linear infinite" : undefined }} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ font: "600 14px/1.25 var(--font-ui)", color: "var(--nyan-text)",
          overflow: "hidden", textOverflow: "ellipsis", whiteSpace: description ? "nowrap" : "normal" }}>{title}</div>
        {description && (
          <div style={{ font: "400 12.5px/1.35 var(--font-ui)", color: "var(--nyan-text-secondary)", marginTop: 2 }}>{description}</div>
        )}
      </div>
      {action && (
        <button onClick={action.onPress} style={{
          all: "unset", cursor: "pointer", flexShrink: 0,
          height: 32, padding: "0 12px", borderRadius: "var(--r-chip)",
          font: "600 13px/1 var(--font-ui)", color: "var(--nyan-primary-deep)",
          background: "color-mix(in srgb, var(--nyan-primary) 10%, transparent)",
        }}>{action.label}</button>
      )}
      {onDismiss && (
        <button onClick={onDismiss} title="Dismiss" style={{
          all: "unset", cursor: "pointer", flexShrink: 0,
          width: 32, height: 32, borderRadius: "var(--r-chip)", display: "grid", placeItems: "center",
        }}>
          <i className="ph ph-x" style={{ fontSize: 16, color: "var(--nyan-text-muted)" }} />
        </button>
      )}
    </div>
  );
  if (placement === "bottom") {
    return (
      <div style={{ position: "absolute", left: "var(--inset)", right: "var(--inset)", bottom: "var(--inset)", zIndex: 60, ...style }}>
        {card}
      </div>
    );
  }
  return card;
};

export { NyanResponse };
