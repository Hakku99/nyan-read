/* ============================================================================
   Nyan Read — ReaderParagraph
   Compiled into the DS bundle; consume as window.<Namespace>.ReaderParagraph.
   Props contract: ./ReaderParagraph.d.ts
   ============================================================================ */

/* ── Reading text body (inside reader canvas) ───────────────────────────── */
const ReaderParagraph = ({ children, serif = false, fontSize = 18, lineHeight = 1.75, color }) => (
  <p style={{
    font: `400 ${fontSize}px/${lineHeight} ${serif ? "var(--font-serif)" : "var(--font-ui)"}`,
    color: color || "var(--reader-ink)",
    margin: "0 0 1.2em 0",
    textIndent: "2em",
    textAlign: "justify",
    textWrap: "pretty",
  }}>{children}</p>
);

export { ReaderParagraph };
