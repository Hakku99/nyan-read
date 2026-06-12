/* ============================================================================
   Nyan Read — PinDots
   Compiled into the DS bundle; consume as window.<Namespace>.PinDots.
   Props contract: ./PinDots.d.ts
   ============================================================================ */

/* ── PIN dots (U16) ───────────────────────────────────────────────────────────
   The filled/empty progress dots above the PIN keypad. Shakes on error. `dotColor`
   adapts to the takeover theme (cream on the ink-night gate, ink on the warm-paper
   gate) so the same component serves both. */
const PinDots = ({ count = 0, length = 4, hasError = false, dotColor = "var(--nyan-text)", gap = 20, size = 16 }) => (
  <div style={{ display: "flex", gap, justifyContent: "center", animation: hasError ? "nyanPinShake 320ms ease" : "none" }}>
    {Array.from({ length }).map((_, i) => (
      <div key={i} style={{
        width: size, height: size, borderRadius: "50%",
        background: i < count ? dotColor : "transparent",
        border: `1.5px solid color-mix(in srgb, ${dotColor} ${hasError ? 38 : 56}%, transparent)`,
        transition: "background 120ms ease",
      }} />
    ))}
    <style>{"@keyframes nyanPinShake { 0%,100% { transform: translateX(0); } 20% { transform: translateX(-8px); } 40% { transform: translateX(8px); } 60% { transform: translateX(-5px); } 80% { transform: translateX(5px); } }"}</style>
  </div>
);

export { PinDots };
