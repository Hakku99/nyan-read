/* ============================================================================
   Nyan Read — Surfaces — containers & sheets
   ----------------------------------------------------------------------------
   Info card, list rows, grouped row stack, empty state, bottom sheet, action-sheet row, FAB.
   Part of the split component library. Exports go to window so other Babel
   <script> blocks (galleries, screens, the live prototype) can use them.
   ============================================================================ */

const { useState, useEffect, useRef, useCallback, useMemo } = React;

/* ── Info card (NyanInfoCard) ────────────────────────────────────────────── */
const NyanInfoCard = ({ children, variant = "standard", tone = "surface", padding = 16, onPress, style }) => {
  const isGrouped = variant === "grouped";
  const radius = isGrouped ? "var(--radius-input)" : "var(--radius-card)";
  const shadow = isGrouped ? "var(--shadow-grouped)" : "var(--shadow-light-card)";
  const bg = tone === "muted" ? "var(--nyan-surface-muted)"
           : tone === "raised" ? "var(--nyan-surface-raised, var(--nyan-surface))"
           : "var(--nyan-surface)";
  const borderAlpha = isGrouped ? 0.16 : 0.3;
  const borderWidth = isGrouped ? 0.72 : 0.5;
  return (
    <div
      onClick={onPress}
      style={{
        background: bg,
        borderRadius: radius,
        boxShadow: shadow,
        border: `${borderWidth}px solid color-mix(in srgb, var(--nyan-divider) ${borderAlpha * 100}%, transparent)`,
        padding,
        cursor: onPress ? "pointer" : "default",
        ...style,
      }}
    >
      {children}
    </div>
  );
};


/* ── List row (NyanListRow / settings row) ───────────────────────────────── */
const NyanListRow = ({ icon, title, subtitle, trailing, onPress, danger = false }) => {
  const fg = danger ? "var(--error-secondary)" : "var(--nyan-text)";
  return (
    <div
      onClick={onPress}
      style={{
        background: "var(--nyan-surface)",
        padding: "14px 16px",
        display: "flex",
        alignItems: "center",
        gap: 12,
        cursor: onPress ? "pointer" : "default",
        minHeight: 56,
      }}
    >
      {icon && (
        <div style={{
          width: 36, height: 36, borderRadius: "var(--radius-small)",
          background: "color-mix(in srgb, var(--nyan-primary) 9%, transparent)",
          display: "grid", placeItems: "center", flexShrink: 0,
        }}>
          <Icon name={icon} size={17} color={danger ? "var(--error-secondary)" : "var(--nyan-primary)"} />
        </div>
      )}
      <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 2, minWidth: 0 }}>
        <div style={{ font: "600 16px/1.2 var(--font-ui)", color: fg, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{title}</div>
        {subtitle && <div className="nyan-meta">{subtitle}</div>}
      </div>
      {trailing !== undefined ? trailing : (onPress && <Icon name="chevron_right" size={18} color="color-mix(in srgb, var(--nyan-text-secondary) 44%, transparent)" />)}
    </div>
  );
};


/* ── Grouped card stack — rows separated by hairlines, single rounded shell  */
const NyanRowGroup = ({ children, style }) => {
  const items = React.Children.toArray(children).filter(Boolean);
  return (
    <div style={{
      background: "var(--nyan-surface)",
      borderRadius: "var(--radius-input)",
      border: "0.72px solid color-mix(in srgb, var(--nyan-divider) 16%, transparent)",
      boxShadow: "var(--shadow-grouped)",
      overflow: "hidden",
      ...style,
    }}>
      {items.map((c, i) => (
        <React.Fragment key={i}>
          {c}
          {i < items.length - 1 && (
            <div style={{ height: 1, background: "var(--nyan-divider)", marginLeft: 64, opacity: 0.5 }} />
          )}
        </React.Fragment>
      ))}
    </div>
  );
};


/* ── Empty state (NyanEmptyState) ────────────────────────────────────────── */
const NyanEmptyState = ({ icon, title, description, action }) => (
  <div style={{ display: "flex", flexDirection: "column", alignItems: "center", textAlign: "center", padding: "32px 24px", gap: 16 }}>
    <div style={{ padding: 14, background: "color-mix(in srgb, var(--nyan-primary) 8%, transparent)", borderRadius: "var(--radius-card)" }}>
      {typeof icon === "string"
        ? <Icon name={icon} size={34} color="color-mix(in srgb, var(--nyan-primary) 80%, transparent)" />
        : icon}
    </div>
    <div style={{ display: "flex", flexDirection: "column", gap: 8, maxWidth: 320 }}>
      <div className="nyan-section">{title}</div>
      {description && <div style={{ font: "400 14px/1.5 var(--font-ui)", color: "var(--nyan-text-secondary)", whiteSpace: "pre-line" }}>{description}</div>}
    </div>
    {action && <div style={{ marginTop: 4 }}>{action}</div>}
  </div>
);


/* ── Bottom sheet — "One Paper": floating, inset, warm scrim + blur ──────── */
const NyanBottomSheet = ({ open, onClose, children, height }) => {
  if (!open) return null;
  return (
    <div style={{ position: "absolute", inset: 0, zIndex: 50, pointerEvents: "auto" }}>
      {/* depth response: warm ink scrim + Gaussian blur recedes the page behind.
         Uses the --scrim token so it deepens correctly in Sumi Dark. */}
      <div onClick={onClose} style={{
        position: "absolute", inset: 0,
        background: "var(--scrim)",
        backdropFilter: "blur(var(--scrim-blur))", WebkitBackdropFilter: "blur(var(--scrim-blur))",
        animation: "nyanFade 220ms ease-out",
      }} />
      {/* the sheet floats inset by 12px on all sides, all four corners rounded —
         the same paper, inset, and lift as the reader dock */}
      <div style={{
        position: "absolute", left: "var(--inset)", right: "var(--inset)", bottom: "var(--inset)",
        background: "var(--nyan-surface-raised, var(--nyan-surface))",
        borderRadius: "var(--r-sheet)",
        border: "1px solid var(--chrome-edge)",
        boxShadow: "var(--shadow-light-card)",
        maxHeight: "calc(85% - 12px)",
        height: height ? `calc(${height} - 12px)` : undefined,
        display: "flex", flexDirection: "column",
        animation: "nyanSlideUp 280ms cubic-bezier(0.33,0.9,0.36,1)",
        overflow: "hidden",
      }}>
        <div style={{ padding: "12px 0 6px", display: "flex", justifyContent: "center" }}>
          <div style={{ width: 40, height: 5, borderRadius: 999, background: "var(--grabber)" }} />
        </div>
        <div style={{ flex: 1, minHeight: 0, overflow: "auto" }}>{children}</div>
      </div>
      <style>{`
        @keyframes nyanFade { from { opacity: 0; } to { opacity: 1; } }
        @keyframes nyanSlideUp { from { transform: translateY(120%); } to { transform: translateY(0); } }
      `}</style>
    </div>
  );
};


/* ── Action-sheet row (NyanActionSheetRow) ───────────────────────────────── */
const NyanActionSheetRow = ({ icon, title, subtitle, onPress, showChevron = true }) => (
  <div onClick={onPress} style={{
    padding: "12px 16px", display: "flex", alignItems: "center", gap: 12,
    cursor: "pointer",
  }}>
    <div style={{
      width: 36, height: 36, borderRadius: "var(--radius-small)",
      background: "color-mix(in srgb, var(--nyan-primary) 9%, transparent)",
      display: "grid", placeItems: "center", flexShrink: 0,
    }}>
      <Icon name={icon} size={17} color="var(--nyan-primary)" />
    </div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ font: "600 16px/1.2 var(--font-ui)", color: "var(--nyan-text)" }}>{title}</div>
      <div className="nyan-meta" style={{ marginTop: 4 }}>{subtitle}</div>
    </div>
    {showChevron && <Icon name="chevron_right" size={18} color="color-mix(in srgb, var(--nyan-text-secondary) 44%, transparent)" />}
  </div>
);


/* ── Floating action button ─────────────────────────────────────────────── */
const NyanFAB = ({ icon = "add", onPress, style }) => (
  <button onClick={onPress} style={{
    all: "unset", cursor: "pointer",
    width: 56, height: 56,
    background: "var(--nyan-primary-deep)",
    color: "var(--nyan-surface)",
    borderRadius: "var(--r-dock)",
    display: "grid", placeItems: "center",
    boxShadow: "var(--shadow-light-card)",
    position: "absolute", right: "var(--inset)", bottom: "var(--inset)",
    ...style,
  }}>
    <Icon name={icon} size={26} color="var(--nyan-surface)" />
  </button>
);


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
        background: "var(--nyan-surface)",
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


/* ── Option picker sheet (NyanOptionSheet) ────────────────────────────────
   The single bottom-sheet for "pick one of these" (theme preset, language,
   page-turn mode, reminder interval) AND "do one of these" (export data).
   Same floating-chrome doctrine as NyanBottomSheet: warm scrim + blur, inset
   sheet, all four corners, one soft lift. Drops into any position:relative
   frame as a sibling overlay.

   Props:
     title       sheet heading
     subtitle    optional one-line description
     options     array of string | { label, hint, swatch, icon }
     selected    index of the chosen option (radio variant)
     variant     "radio" (default — single-select list) | "action" (icon rows)
     onClose     dismiss handler (scrim tap + ✕)                              */
const NyanOptionSheet = ({ title, subtitle, options = [], selected = 0, variant = "radio", onClose, style }) => (
  <div style={{ position: "absolute", inset: 0, zIndex: 50, ...style }}>
    <div onClick={onClose} style={{ position: "absolute", inset: 0, background: "var(--scrim)",
      backdropFilter: "blur(var(--scrim-blur))", WebkitBackdropFilter: "blur(var(--scrim-blur))", animation: "nyanFade 220ms ease-out" }} />
    <div style={{ position: "absolute", left: "var(--inset)", right: "var(--inset)", bottom: "var(--inset)",
      background: "var(--nyan-surface)", border: "1px solid var(--chrome-edge)", borderRadius: "var(--r-sheet)",
      boxShadow: "var(--shadow-light-card)", overflow: "hidden", animation: "nyanSlideUp 280ms cubic-bezier(0.33,0.9,0.36,1)" }}>
      {/* grabber */}
      <div style={{ paddingTop: 10, display: "flex", justifyContent: "center" }}>
        <div style={{ width: 40, height: 5, borderRadius: 999, background: "var(--grabber)" }} />
      </div>
      {/* header */}
      <div style={{ padding: "12px 20px 8px", display: "flex", alignItems: "flex-start", gap: 12 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ font: "600 18px/1.2 var(--font-ui)", color: "var(--nyan-text)", letterSpacing: "-0.1px" }}>{title}</div>
          {subtitle && <div style={{ font: "400 13px/1.38 var(--font-ui)", color: "var(--nyan-text-secondary)", marginTop: 4 }}>{subtitle}</div>}
        </div>
        <button onClick={onClose} title="Close" style={{ all: "unset", cursor: "pointer", width: 32, height: 32, borderRadius: "var(--r-chip)", display: "grid", placeItems: "center", flexShrink: 0, marginTop: -2 }}>
          <i className="ph ph-x" style={{ fontSize: 16, color: "var(--nyan-text-muted)" }} />
        </button>
      </div>
      {/* options */}
      <div style={{ padding: "4px 12px 16px", display: "flex", flexDirection: "column" }}>
        {options.map((raw, i) => {
          const o = typeof raw === "string" ? { label: raw } : raw;
          const isSel = variant === "radio" && i === selected;
          return (
            <button key={i} onClick={onClose} style={{ all: "unset", cursor: "pointer", boxSizing: "border-box",
              display: "flex", alignItems: "center", gap: 12, padding: "12px 12px", minHeight: 56, borderRadius: "var(--r-card-nested)",
              background: isSel ? "color-mix(in srgb, var(--nyan-primary) 8%, transparent)" : "transparent" }}>
              {o.swatch && (
                <div style={{ width: 30, height: 30, borderRadius: "var(--r-chip)", flexShrink: 0, background: o.swatch,
                  border: "1px solid color-mix(in srgb, var(--nyan-divider) 60%, transparent)" }} />
              )}
              {o.icon && (
                <div style={{ width: 36, height: 36, borderRadius: "var(--r-chip)", flexShrink: 0,
                  background: "color-mix(in srgb, var(--nyan-primary) 10%, var(--nyan-surface-muted))", display: "grid", placeItems: "center" }}>
                  <i className={`ph ph-${o.icon}`} style={{ fontSize: 18, color: "var(--nyan-primary)" }} />
                </div>
              )}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ font: `${isSel ? 600 : 500} 15px/1.2 var(--font-ui)`, color: isSel ? "var(--nyan-primary-deep)" : "var(--nyan-text)" }}>{o.label}</div>
                {o.hint && <div style={{ font: "400 12.5px/1.3 var(--font-ui)", color: "var(--nyan-text-secondary)", marginTop: 2 }}>{o.hint}</div>}
              </div>
              {variant === "radio" ? (
                <div style={{ width: 22, height: 22, borderRadius: "50%", flexShrink: 0, display: "grid", placeItems: "center",
                  border: `2px solid ${isSel ? "var(--nyan-primary)" : "color-mix(in srgb, var(--nyan-divider) 80%, transparent)"}` }}>
                  {isSel && <div style={{ width: 11, height: 11, borderRadius: "50%", background: "var(--nyan-primary)" }} />}
                </div>
              ) : (
                <i className="ph ph-caret-right" style={{ fontSize: 16, color: "var(--nyan-text-muted)", flexShrink: 0 }} />
              )}
            </button>
          );
        })}
      </div>
    </div>
  </div>
);


/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, { NyanInfoCard, NyanListRow, NyanRowGroup, NyanEmptyState, NyanBottomSheet, NyanActionSheetRow, NyanFAB, NyanResponse, NyanOptionSheet });
