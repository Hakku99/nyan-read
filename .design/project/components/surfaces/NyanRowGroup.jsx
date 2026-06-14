/* ============================================================================
   Nyan Read — NyanRowGroup
   Compiled into the DS bundle; consume as window.<Namespace>.NyanRowGroup.
   Props contract: ./NyanRowGroup.d.ts
   ============================================================================ */

/* ── Grouped card stack — rows separated by inset hairlines, single shell ──── */
const NyanRowGroup = ({ children, style }) => {
  const items = React.Children.toArray(children).filter(Boolean);
  return (
    <div style={{
      background: "var(--nyan-surface)",
      borderRadius: "var(--r-card-nested)",
      border: "1px solid var(--chrome-edge)",
      boxShadow: "var(--shadow-grouped)",
      overflow: "hidden",
      ...style,
    }}>
      {items.map((c, i) => (
        <React.Fragment key={i}>
          {i > 0 && (
            <div style={{ height: "0.5px", background: "color-mix(in srgb, var(--nyan-divider) 34%, transparent)", margin: "0 16px" }} />
          )}
          {c}
        </React.Fragment>
      ))}
    </div>
  );
};

export { NyanRowGroup };
