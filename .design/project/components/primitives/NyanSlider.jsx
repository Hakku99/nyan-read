/* ============================================================================
   Nyan Read — NyanSlider
   Compiled into the DS bundle; consume as window.<Namespace>.NyanSlider.
   Props contract: ./NyanSlider.d.ts
   ============================================================================ */

const { useState, useEffect, useRef, useCallback, useMemo } = React;

/* ── Slider (used in reader settings) ───────────────────────────────────── */
const NyanSlider = ({ value, min = 0, max = 100, step = 1, onChange, color = "var(--nyan-primary-deep)", "aria-label": ariaLabel, disabled = false }) => {
  const trackRef = useRef(null);
  const onPointer = (e) => {
    const rect = trackRef.current.getBoundingClientRect();
    const x = (e.touches ? e.touches[0].clientX : e.clientX) - rect.left;
    const pct = Math.max(0, Math.min(1, x / rect.width));
    const raw = min + pct * (max - min);
    const snapped = Math.round(raw / step) * step;
    onChange(Math.max(min, Math.min(max, snapped)));
  };
  const [dragging, setDragging] = useState(false);
  useEffect(() => {
    if (!dragging) return;
    const move = (e) => onPointer(e);
    const up = () => setDragging(false);
    window.addEventListener("mousemove", move);
    window.addEventListener("mouseup", up);
    window.addEventListener("touchmove", move);
    window.addEventListener("touchend", up);
    return () => {
      window.removeEventListener("mousemove", move);
      window.removeEventListener("mouseup", up);
      window.removeEventListener("touchmove", move);
      window.removeEventListener("touchend", up);
    };
  }, [dragging]);
  const onKeyDown = (e) => {
    if (disabled) return;
    let next = value;
    if (e.key === "ArrowRight" || e.key === "ArrowUp") next = value + step;
    else if (e.key === "ArrowLeft" || e.key === "ArrowDown") next = value - step;
    else if (e.key === "Home") next = min;
    else if (e.key === "End") next = max;
    else if (e.key === "PageUp") next = value + step * 10;
    else if (e.key === "PageDown") next = value - step * 10;
    else return;
    e.preventDefault();
    onChange(Math.max(min, Math.min(max, next)));
  };
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <div
      ref={trackRef}
      role="slider"
      tabIndex={disabled ? -1 : 0}
      aria-valuemin={min}
      aria-valuemax={max}
      aria-valuenow={value}
      aria-label={ariaLabel}
      aria-disabled={disabled || undefined}
      onKeyDown={onKeyDown}
      onMouseDown={disabled ? undefined : (e) => { setDragging(true); onPointer(e); }}
      onTouchStart={disabled ? undefined : (e) => { setDragging(true); onPointer(e); }}
      style={{ position: "relative", height: 24, display: "flex", alignItems: "center", cursor: disabled ? "default" : "pointer", touchAction: "none", opacity: disabled ? 0.4 : 1, outline: "none" }}
    >
      <div style={{ position: "absolute", left: 0, right: 0, height: 6, background: "color-mix(in srgb, var(--nyan-text) 12%, transparent)", borderRadius: 999 }} />
      <div style={{ position: "absolute", left: 0, width: `${pct}%`, height: 6, background: color, borderRadius: 999 }} />
      {/* ring thumb — surface fill, matcha ring + soft lift (matches the blueprint) */}
      <div style={{
        position: "absolute", left: `calc(${pct}% - 10px)`,
        width: 20, height: 20, background: "var(--nyan-surface)", borderRadius: "50%",
        boxShadow: `0 1px 4px color-mix(in srgb, var(--shadow-color) 28%, transparent), 0 0 0 1.5px color-mix(in srgb, ${color} 60%, transparent)`,
      }} />
    </div>
  );
};

export { NyanSlider };
