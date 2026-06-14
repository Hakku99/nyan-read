/* ============================================================================
   Nyan Read — NyanBottomSheet
   Compiled into the DS bundle; consume as window.<Namespace>.NyanBottomSheet.
   Props contract: ./NyanBottomSheet.d.ts
   ============================================================================ */

const { useState, useEffect } = React;

/* ── Bottom sheet — "One Paper": floating, inset, warm scrim + blur ──────── */
const NyanBottomSheet = ({ open, onClose, children, height }) => {
  // Keep the sheet mounted through its exit animation: `render` lags `open`.
  const [render, setRender] = useState(open);
  const [closing, setClosing] = useState(false);
  useEffect(() => {
    if (open) { setRender(true); setClosing(false); return; }
    if (!render) return;
    setClosing(true);
    const id = setTimeout(() => { setRender(false); setClosing(false); }, 240);
    return () => clearTimeout(id);
  }, [open]);
  if (!render) return null;
  return (
    <div style={{ position: "absolute", inset: 0, zIndex: 50, pointerEvents: "auto" }}>
      {/* depth response: warm ink scrim + Gaussian blur recedes the page behind.
         Uses the --scrim token so it deepens correctly in Sumi Dark. */}
      <div onClick={onClose} style={{
        position: "absolute", inset: 0,
        background: "var(--scrim)",
        backdropFilter: "blur(var(--scrim-blur))", WebkitBackdropFilter: "blur(var(--scrim-blur))",
        animation: closing ? "nyanFadeOut 220ms ease-in forwards" : "nyanFade 220ms ease-out",
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
        animation: closing
          ? "nyanSlideDown 240ms cubic-bezier(0.4,0,0.7,0.2) forwards"
          : "nyanSlideUp 280ms cubic-bezier(0.33,0.9,0.36,1)",
        overflow: "hidden",
      }}>
        <div style={{ padding: "12px 0 6px", display: "flex", justifyContent: "center" }}>
          <div style={{ width: 40, height: 5, borderRadius: 999, background: "var(--grabber)" }} />
        </div>
        <div style={{ flex: 1, minHeight: 0, overflow: "auto" }}>{children}</div>
      </div>
      <style>{`
        @keyframes nyanFade { from { opacity: 0; } to { opacity: 1; } }
        @keyframes nyanFadeOut { from { opacity: 1; } to { opacity: 0; } }
        @keyframes nyanSlideUp { from { transform: translateY(120%); } to { transform: translateY(0); } }
        @keyframes nyanSlideDown { from { transform: translateY(0); } to { transform: translateY(120%); } }
      `}</style>
    </div>
  );
};

export { NyanBottomSheet };
