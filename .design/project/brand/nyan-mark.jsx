/* Nyan Mark — One Paper native brand mark.
   A cat peeking over its open book. Built to the reader-chrome doctrine:
   ONE matcha fill, cream knockout features, ~1.5–2px strokes with round joins,
   geometric and flat — no gradients, no soft 3D, no baked wordmark.

   Props:
     size   — px (square)
     fill   — body color (default matcha #6E7A55)
     ink    — feature/knockout color (default warm cream); used for eyes,
              nose, whiskers, inner-ears, book pages + spine
     mono   — render the whole mark in one color; features knock out to `paper`
     paper  — knockout color in mono mode (default #F2EEE2)
     grid   — overlay the construction grid
*/
const NyanMark = ({ size = 96, fill = "#6E7A55", ink, paper = "#F2EEE2", mono, grid }) => {
  const body = mono ? mono : fill;
  const feat = mono ? paper : (ink || "#F4F1E6");
  const sw = 96; // viewBox units

  return (
    <svg width={size} height={size} viewBox="0 0 96 96" fill="none" xmlns="http://www.w3.org/2000/svg" style={{ display: "block", overflow: "visible" }}>
      {grid && (
        <g stroke="#C9B79A" strokeWidth="0.5" opacity="0.7">
          <rect x="12" y="12" width="72" height="72" rx="0" fill="none" />
          <line x1="48" y1="6" x2="48" y2="90" />
          <line x1="6" y1="48" x2="90" y2="48" />
          <circle cx="48" cy="48" r="36" fill="none" />
        </g>
      )}

      {/* ── Cat: ears ─────────────────────────────────────────────── */}
      <path d="M31 30 L30 11 L46 22 Z" fill={body} stroke={body} strokeWidth="2.4" strokeLinejoin="round" />
      <path d="M65 30 L66 11 L50 22 Z" fill={body} stroke={body} strokeWidth="2.4" strokeLinejoin="round" />
      {/* inner ears */}
      <path d="M34 27 L33.2 16 L43 22.5 Z" fill={feat} stroke={feat} strokeWidth="1.2" strokeLinejoin="round" />
      <path d="M62 27 L62.8 16 L53 22.5 Z" fill={feat} stroke={feat} strokeWidth="1.2" strokeLinejoin="round" />

      {/* ── Cat: head ─────────────────────────────────────────────── */}
      <ellipse cx="48" cy="39" rx="19" ry="17" fill={body} />

      {/* whiskers */}
      <g stroke={feat} strokeWidth="1.3" strokeLinecap="round" opacity="0.9">
        <line x1="34" y1="40" x2="24" y2="38.5" />
        <line x1="34" y1="42.6" x2="23.5" y2="42.6" />
        <line x1="34" y1="45.2" x2="24" y2="46.8" />
        <line x1="62" y1="40" x2="72" y2="38.5" />
        <line x1="62" y1="42.6" x2="72.5" y2="42.6" />
        <line x1="62" y1="45.2" x2="72" y2="46.8" />
      </g>

      {/* eyes — closed, content */}
      <g stroke={feat} strokeWidth="2" strokeLinecap="round" fill="none">
        <path d="M39.5 37.5 Q43 41 46.5 37.5" />
        <path d="M49.5 37.5 Q53 41 56.5 37.5" />
      </g>
      {/* nose */}
      <path d="M46.4 41.6 L49.6 41.6 L48 44 Z" fill={feat} />
      {/* mouth */}
      <g stroke={feat} strokeWidth="1.4" strokeLinecap="round" fill="none">
        <path d="M48 44 Q46 46 44.3 45" />
        <path d="M48 44 Q50 46 51.7 45" />
      </g>

      {/* ── Open book (in front — cat peeks over it) ──────────────── */}
      <path d="M48 54
               C39 51 25 51.5 17 55
               C14 56 13 58.5 14.5 61
               L18 71
               C18.5 73 21 73 23 72
               C33 68.5 42 68.5 48 70.5
               C54 68.5 63 68.5 73 72
               C75 73 77.5 73 78 71
               L81.5 61
               C83 58.5 82 56 79 55
               C71 51.5 57 51 48 54 Z"
            fill={body} stroke={body} strokeWidth="0.6" strokeLinejoin="round" />
      {/* spine + page lines */}
      <g stroke={feat} strokeWidth="1.7" strokeLinecap="round" fill="none">
        <path d="M48 54.5 L48 70" />
      </g>
      <g stroke={feat} strokeWidth="1.4" strokeLinecap="round" fill="none" opacity="0.92">
        <path d="M41 58.5 C34 56.5 27 57.5 21.5 59.5" />
        <path d="M42 62.5 C35 61 29 62 23.5 64" />
        <path d="M55 58.5 C62 56.5 69 57.5 74.5 59.5" />
        <path d="M54 62.5 C61 61 67 62 72.5 64" />
      </g>

      {/* paws resting on the book edge */}
      <path d="M40 52.5 a3.4 3.4 0 0 1 6.8 0 z" fill={body} />
      <path d="M49.2 52.5 a3.4 3.4 0 0 1 6.8 0 z" fill={body} />
    </svg>
  );
};

window.NyanMark = NyanMark;
