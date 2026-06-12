/* ============================================================================
   Nyan Read — Skeleton
   Compiled into the DS bundle; consume as window.<Namespace>.Skeleton.
   Props contract: ./Skeleton.d.ts
   ============================================================================ */

/* ── Skeleton ─────────────────────────────────────────────────────────────────
   Loading placeholder — a calm paper shimmer (NOT a grey Material block). Used
   while a book imports, a cover renders, or a list hydrates. `variant` picks the
   shape: "text" (a line, height tracks font), "cover" (a 120:156 book cover),
   "circle", or "block". Compose several to mock a whole row. The shimmer respects
   prefers-reduced-motion. */
const Skeleton = ({ variant = "text", width, height, radius, style }) => {
  const presets = {
    text:   { width: width || "100%", height: height || 12, radius: radius != null ? radius : 6 },
    cover:  { width: width || "100%", height: height, radius: radius != null ? radius : 12, aspect: "120 / 156" },
    circle: { width: width || 40, height: height || 40, radius: "50%" },
    block:  { width: width || "100%", height: height || 80, radius: radius != null ? radius : "var(--r-card-nested)" },
  };
  const p = presets[variant] || presets.text;
  return (
    <div style={{
      width: p.width, height: p.height, aspectRatio: p.aspect, borderRadius: p.radius,
      background: "linear-gradient(100deg, color-mix(in srgb, var(--nyan-primary) 7%, var(--nyan-surface-muted)) 30%, color-mix(in srgb, var(--nyan-primary) 13%, var(--nyan-surface)) 50%, color-mix(in srgb, var(--nyan-primary) 7%, var(--nyan-surface-muted)) 70%)",
      backgroundSize: "200% 100%",
      animation: "nyanSkeleton 1400ms ease-in-out infinite",
      ...style,
    }}>
      <style>{"@keyframes nyanSkeleton { from { background-position: 200% 0; } to { background-position: -200% 0; } } @media (prefers-reduced-motion: reduce) { @keyframes nyanSkeleton { from, to { background-position: 0 0; } } }"}</style>
    </div>
  );
};

export { Skeleton };
