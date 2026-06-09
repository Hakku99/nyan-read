/* @ds-bundle: {"format":3,"namespace":"NyanReadDesignSystem_019e2f","components":[],"sourceHashes":{"brand/nyan-mark.jsx":"dc3409626c1d","components/cards.jsx":"ec7121009712","components/headers.jsx":"8ceb9085a695","components/primitives.jsx":"56c8853d51db","components/reader.jsx":"af5c80faf8f4","components/surfaces.jsx":"801189ea9bbe","screens/bundle1.jsx":"f9ad6853de1b","screens/bundle2-screens.jsx":"1b00c01ddca1","screens/bundle3.jsx":"58e9e5fa309d","screens/bundle4.jsx":"2ad01f02e7d5"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.NyanReadDesignSystem_019e2f = window.NyanReadDesignSystem_019e2f || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// brand/nyan-mark.jsx
try { (() => {
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
const NyanMark = ({
  size = 96,
  fill = "#6E7A55",
  ink,
  paper = "#F2EEE2",
  mono,
  grid
}) => {
  const body = mono ? mono : fill;
  const feat = mono ? paper : ink || "#F4F1E6";
  const sw = 96; // viewBox units

  return /*#__PURE__*/React.createElement("svg", {
    width: size,
    height: size,
    viewBox: "0 0 96 96",
    fill: "none",
    xmlns: "http://www.w3.org/2000/svg",
    style: {
      display: "block",
      overflow: "visible"
    }
  }, grid && /*#__PURE__*/React.createElement("g", {
    stroke: "#C9B79A",
    strokeWidth: "0.5",
    opacity: "0.7"
  }, /*#__PURE__*/React.createElement("rect", {
    x: "12",
    y: "12",
    width: "72",
    height: "72",
    rx: "0",
    fill: "none"
  }), /*#__PURE__*/React.createElement("line", {
    x1: "48",
    y1: "6",
    x2: "48",
    y2: "90"
  }), /*#__PURE__*/React.createElement("line", {
    x1: "6",
    y1: "48",
    x2: "90",
    y2: "48"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "48",
    cy: "48",
    r: "36",
    fill: "none"
  })), /*#__PURE__*/React.createElement("path", {
    d: "M31 30 L30 11 L46 22 Z",
    fill: body,
    stroke: body,
    strokeWidth: "2.4",
    strokeLinejoin: "round"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M65 30 L66 11 L50 22 Z",
    fill: body,
    stroke: body,
    strokeWidth: "2.4",
    strokeLinejoin: "round"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M34 27 L33.2 16 L43 22.5 Z",
    fill: feat,
    stroke: feat,
    strokeWidth: "1.2",
    strokeLinejoin: "round"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M62 27 L62.8 16 L53 22.5 Z",
    fill: feat,
    stroke: feat,
    strokeWidth: "1.2",
    strokeLinejoin: "round"
  }), /*#__PURE__*/React.createElement("ellipse", {
    cx: "48",
    cy: "39",
    rx: "19",
    ry: "17",
    fill: body
  }), /*#__PURE__*/React.createElement("g", {
    stroke: feat,
    strokeWidth: "1.3",
    strokeLinecap: "round",
    opacity: "0.9"
  }, /*#__PURE__*/React.createElement("line", {
    x1: "34",
    y1: "40",
    x2: "24",
    y2: "38.5"
  }), /*#__PURE__*/React.createElement("line", {
    x1: "34",
    y1: "42.6",
    x2: "23.5",
    y2: "42.6"
  }), /*#__PURE__*/React.createElement("line", {
    x1: "34",
    y1: "45.2",
    x2: "24",
    y2: "46.8"
  }), /*#__PURE__*/React.createElement("line", {
    x1: "62",
    y1: "40",
    x2: "72",
    y2: "38.5"
  }), /*#__PURE__*/React.createElement("line", {
    x1: "62",
    y1: "42.6",
    x2: "72.5",
    y2: "42.6"
  }), /*#__PURE__*/React.createElement("line", {
    x1: "62",
    y1: "45.2",
    x2: "72",
    y2: "46.8"
  })), /*#__PURE__*/React.createElement("g", {
    stroke: feat,
    strokeWidth: "2",
    strokeLinecap: "round",
    fill: "none"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M39.5 37.5 Q43 41 46.5 37.5"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M49.5 37.5 Q53 41 56.5 37.5"
  })), /*#__PURE__*/React.createElement("path", {
    d: "M46.4 41.6 L49.6 41.6 L48 44 Z",
    fill: feat
  }), /*#__PURE__*/React.createElement("g", {
    stroke: feat,
    strokeWidth: "1.4",
    strokeLinecap: "round",
    fill: "none"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M48 44 Q46 46 44.3 45"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M48 44 Q50 46 51.7 45"
  })), /*#__PURE__*/React.createElement("path", {
    d: "M48 54 C39 51 25 51.5 17 55 C14 56 13 58.5 14.5 61 L18 71 C18.5 73 21 73 23 72 C33 68.5 42 68.5 48 70.5 C54 68.5 63 68.5 73 72 C75 73 77.5 73 78 71 L81.5 61 C83 58.5 82 56 79 55 C71 51.5 57 51 48 54 Z",
    fill: body,
    stroke: body,
    strokeWidth: "0.6",
    strokeLinejoin: "round"
  }), /*#__PURE__*/React.createElement("g", {
    stroke: feat,
    strokeWidth: "1.7",
    strokeLinecap: "round",
    fill: "none"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M48 54.5 L48 70"
  })), /*#__PURE__*/React.createElement("g", {
    stroke: feat,
    strokeWidth: "1.4",
    strokeLinecap: "round",
    fill: "none",
    opacity: "0.92"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M41 58.5 C34 56.5 27 57.5 21.5 59.5"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M42 62.5 C35 61 29 62 23.5 64"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M55 58.5 C62 56.5 69 57.5 74.5 59.5"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M54 62.5 C61 61 67 62 72.5 64"
  })), /*#__PURE__*/React.createElement("path", {
    d: "M40 52.5 a3.4 3.4 0 0 1 6.8 0 z",
    fill: body
  }), /*#__PURE__*/React.createElement("path", {
    d: "M49.2 52.5 a3.4 3.4 0 0 1 6.8 0 z",
    fill: body
  }));
};
window.NyanMark = NyanMark;
})(); } catch (e) { __ds_ns.__errors.push({ path: "brand/nyan-mark.jsx", error: String((e && e.message) || e) }); }

// components/cards.jsx
try { (() => {
/* ============================================================================
   Nyan Read — Cards — book & content cards
   ----------------------------------------------------------------------------
   Book grid card, collapsible Continue Reading card, bookmark card.
   Part of the split component library. Exports go to window so other Babel
   <script> blocks (galleries, screens, the live prototype) can use them.
   ============================================================================ */

const {
  useState,
  useEffect,
  useRef,
  useCallback,
  useMemo
} = React;

/* ── Book grid card (NyanBookGridCard) ───────────────────────────────────
   Source of truth: U9 Bookshelf Home, Cream · grid view (screens/bundle3.jsx
   `BookCard`). A chromeless column — NOT a bordered tile: a tall 120:156 cover
   wash carrying the format chip, a thin progress bar shown only once started,
   then a 2-line title + single-line author. `selectionMode` adds the top-left
   check + selected ring used by U21 multi-select.
   Accepts either `book.pct` (0–100) or `book.progress` (0–1). */
const NyanBookGridCard = ({
  book,
  selected = false,
  selectionMode = false,
  onPress,
  onLongPress
}) => {
  const longPressTimer = useRef(null);
  const start = () => {
    longPressTimer.current = setTimeout(() => onLongPress?.(), 400);
  };
  const cancel = () => clearTimeout(longPressTimer.current);
  const pct = book.pct != null ? book.pct : Math.round((book.progress || 0) * 100);
  return /*#__PURE__*/React.createElement("div", {
    onClick: onPress,
    onMouseDown: start,
    onMouseUp: cancel,
    onMouseLeave: cancel,
    onTouchStart: start,
    onTouchEnd: cancel,
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 6,
      cursor: "pointer",
      userSelect: "none"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      width: "100%",
      aspectRatio: "120 / 156",
      borderRadius: 12,
      background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))",
      border: selected ? "2px solid var(--nyan-primary)" : "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)",
      boxShadow: selected ? "0 0 0 3px color-mix(in srgb, var(--nyan-primary) 16%, transparent)" : "none",
      display: "grid",
      placeItems: "center",
      overflow: "hidden",
      transition: "box-shadow 140ms ease, border-color 140ms ease"
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "menu_book",
    size: 26,
    color: "var(--nyan-primary)"
  }), book.fmt && /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      top: 6,
      right: 6,
      height: 17,
      padding: "0 6px",
      borderRadius: 999,
      background: "color-mix(in srgb, var(--nyan-surface) 88%, transparent)",
      border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)",
      display: "flex",
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "600 9px/1 var(--font-ui)",
      color: "var(--nyan-primary-deep)"
    }
  }, book.fmt)), selectionMode && /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      top: 6,
      left: 6,
      width: 22,
      height: 22,
      borderRadius: "50%",
      display: "grid",
      placeItems: "center",
      background: selected ? "var(--nyan-select-fill)" : "color-mix(in srgb, var(--nyan-surface) 80%, transparent)",
      border: selected ? "1.5px solid var(--nyan-select-fill)" : "1.5px solid color-mix(in srgb, var(--nyan-text) 30%, transparent)",
      boxShadow: selected ? "0 1px 4px color-mix(in srgb, var(--nyan-select-fill) 40%, transparent)" : "none"
    }
  }, selected && /*#__PURE__*/React.createElement("svg", {
    width: 14,
    height: 14,
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "#FFFFFF",
    strokeWidth: "3.4",
    strokeLinecap: "round",
    strokeLinejoin: "round",
    style: {
      display: "block"
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M5 12.5 L10 17.5 L19 7"
  })))), pct > 0 && /*#__PURE__*/React.createElement("div", {
    style: {
      height: 3,
      borderRadius: 999,
      background: "color-mix(in srgb, var(--nyan-primary) 16%, var(--nyan-surface))",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: `${pct}%`,
      height: "100%",
      borderRadius: 999,
      background: "var(--nyan-primary)"
    }
  })), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 12.5px/1.25 var(--font-ui)",
      color: "var(--nyan-text)",
      overflow: "hidden",
      display: "-webkit-box",
      WebkitLineClamp: 2,
      WebkitBoxOrient: "vertical"
    }
  }, book.title), book.author && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 11px/1.3 var(--font-ui)",
      color: "var(--nyan-text-muted)",
      marginTop: 2,
      whiteSpace: "nowrap",
      overflow: "hidden",
      textOverflow: "ellipsis"
    }
  }, book.author)));
};

/* ── Continue reading card (NyanContinueReadingCard) ───────────────────────
   Latest design (U9): collapsible. Header (book glyph + "Continue Reading"
   eyebrow + caret) is always visible and toggles the body. Expanded shows a
   cover, title/author, a progress row, and a full-width matcha CTA that
   enters the book. Collapsed shrinks to a slim row carrying title + percent. */
const NyanContinueReadingCard = ({
  book,
  onContinue,
  collapsed = false,
  onToggleCollapse
}) => {
  const pct = Math.round(book.progress * 100);
  return /*#__PURE__*/React.createElement(NyanInfoCard, {
    padding: 0
  }, /*#__PURE__*/React.createElement("div", {
    onClick: onToggleCollapse,
    style: {
      display: "flex",
      alignItems: "center",
      gap: 10,
      padding: collapsed ? "11px 14px" : "12px 14px 8px",
      cursor: onToggleCollapse ? "pointer" : "default"
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "menu_book",
    size: 15,
    color: "var(--nyan-primary)"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "500 11px/1.2 var(--font-ui)",
      color: "var(--nyan-text-muted)",
      letterSpacing: "0.2px"
    }
  }, "Continue Reading"), collapsed && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 13px/1.3 var(--font-ui)",
      color: "var(--nyan-text)",
      marginTop: 2,
      whiteSpace: "nowrap",
      overflow: "hidden",
      textOverflow: "ellipsis"
    }
  }, book.title)), collapsed && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "600 11px/1 var(--font-ui)",
      color: "var(--nyan-primary-deep)",
      flexShrink: 0
    }
  }, pct, "%"), onToggleCollapse && /*#__PURE__*/React.createElement(Icon, {
    name: "keyboard_arrow_down",
    size: 18,
    color: "var(--nyan-text-muted)",
    style: {
      flexShrink: 0,
      transform: collapsed ? "none" : "rotate(180deg)",
      transition: "transform 200ms var(--ease-paper)"
    }
  })), !collapsed && /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "0 14px 14px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 56,
      height: 72,
      borderRadius: 14,
      background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface-muted))",
      border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)",
      flexShrink: 0,
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "menu_book",
    size: 22,
    color: "var(--nyan-primary)"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0,
      display: "flex",
      flexDirection: "column",
      justifyContent: "center",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 15px/1.3 var(--font-ui)",
      color: "var(--nyan-text)",
      letterSpacing: "-0.1px",
      overflow: "hidden",
      display: "-webkit-box",
      WebkitLineClamp: 2,
      WebkitBoxOrient: "vertical"
    }
  }, book.title), book.author && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 12px/1.3 var(--font-ui)",
      color: "var(--nyan-text-muted)",
      marginTop: 2,
      whiteSpace: "nowrap",
      overflow: "hidden",
      textOverflow: "ellipsis"
    }
  }, book.author)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      height: 4,
      borderRadius: 999,
      background: "color-mix(in srgb, var(--nyan-primary) 16%, var(--nyan-surface-muted))",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: `${pct}%`,
      height: "100%",
      borderRadius: 999,
      background: "var(--nyan-primary)"
    }
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "600 11px/1 var(--font-ui)",
      color: "var(--nyan-primary-deep)",
      flexShrink: 0
    }
  }, pct, "%")))), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 12
    }
  }, /*#__PURE__*/React.createElement(NyanPrimaryButton, {
    label: "Continue Reading",
    icon: "menu_book",
    expanded: true,
    onPress: onContinue
  }))));
};

/* ── Bookmark card ─────────────────────────────────────────────────────────
   Source of truth: U12 Bookmark List (screens/bundle3.jsx `BookmarkCard`).
   Uppercase primary-deep eyebrow label, a 2-line excerpt, and — when a note
   exists — a divider followed by a "Note" pill + the note text. The swipe-to-
   delete rail lives in the list context (U12), not on the card itself. */
const NyanBookmarkCard = ({
  label,
  excerpt,
  note,
  onPress
}) => /*#__PURE__*/React.createElement("div", {
  onClick: onPress,
  style: {
    background: "var(--nyan-surface)",
    borderRadius: 16,
    border: "0.72px solid color-mix(in srgb, var(--nyan-divider) 36%, transparent)",
    padding: "12px 14px",
    cursor: onPress ? "pointer" : "default"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    font: "500 10.5px/1.2 var(--font-ui)",
    color: "var(--nyan-primary-deep)",
    marginBottom: 6,
    letterSpacing: "0.2px",
    textTransform: "uppercase"
  }
}, label), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 14px/1.45 var(--font-ui)",
    color: "var(--nyan-text)",
    display: "-webkit-box",
    WebkitLineClamp: 2,
    WebkitBoxOrient: "vertical",
    overflow: "hidden",
    marginBottom: note ? 8 : 0
  }
}, excerpt), note && /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    gap: 7,
    alignItems: "flex-start",
    marginTop: 6,
    paddingTop: 6,
    borderTop: "0.5px solid color-mix(in srgb, var(--nyan-divider) 34%, transparent)"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    height: 20,
    padding: "0 7px",
    borderRadius: 999,
    background: "color-mix(in srgb, var(--nyan-primary) 10%, var(--nyan-surface-muted))",
    border: "0.5px solid color-mix(in srgb, var(--nyan-primary) 18%, transparent)",
    display: "flex",
    alignItems: "center",
    flexShrink: 0
  }
}, /*#__PURE__*/React.createElement("span", {
  style: {
    font: "500 10px/1 var(--font-ui)",
    color: "var(--nyan-primary-deep)"
  }
}, "Note")), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 13px/1.38 var(--font-ui)",
    color: "var(--nyan-text-secondary)",
    flex: 1
  }
}, note)));

/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, {
  NyanBookGridCard,
  NyanContinueReadingCard,
  NyanBookmarkCard
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/cards.jsx", error: String((e && e.message) || e) }); }

// components/headers.jsx
try { (() => {
/* ============================================================================
   Nyan Read — Headers
   ----------------------------------------------------------------------------
   Page header (title + subtitle + actions) and the olive section caption.
   Part of the split component library. Exports go to window so other Babel
   <script> blocks (galleries, screens, the live prototype) can use them.
   ============================================================================ */

const {
  useState,
  useEffect,
  useRef,
  useCallback,
  useMemo
} = React;

/* ── Section header (olive caption + optional dot) ───────────────────────── */
const NyanSectionHeader = ({
  title,
  withDot = false,
  style
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    padding: "0 16px 12px",
    display: "flex",
    alignItems: "center",
    gap: 8,
    ...style
  }
}, withDot && /*#__PURE__*/React.createElement("div", {
  style: {
    width: 4,
    height: 4,
    borderRadius: "50%",
    background: "color-mix(in srgb, var(--nyan-primary) 63%, transparent)"
  }
}), /*#__PURE__*/React.createElement("div", {
  className: "nyan-section-header",
  style: {
    textTransform: "uppercase"
  }
}, title));

/* ── Page header ─────────────────────────────────────────────────────────── */
const NyanPageHeader = ({
  title,
  subtitle,
  leading,
  actions,
  style
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    padding: "16px 16px 12px",
    display: "flex",
    alignItems: "flex-start",
    gap: 12,
    ...style
  }
}, leading, /*#__PURE__*/React.createElement("div", {
  style: {
    flex: 1,
    display: "flex",
    flexDirection: "column",
    minWidth: 0
  }
}, /*#__PURE__*/React.createElement("div", {
  className: "nyan-title",
  style: {
    letterSpacing: "-0.15px"
  }
}, title), subtitle && /*#__PURE__*/React.createElement("div", {
  className: "nyan-meta",
  style: {
    marginTop: 4,
    color: "var(--nyan-text-muted)",
    lineHeight: 1.35
  }
}, subtitle)), actions && /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    gap: 4
  }
}, actions));

/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, {
  NyanSectionHeader,
  NyanPageHeader
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/headers.jsx", error: String((e && e.message) || e) }); }

// components/primitives.jsx
try { (() => {
/* ============================================================================
   Nyan Read — Primitives — inputs & controls
   ----------------------------------------------------------------------------
   Icon, buttons, switch, segmented control, slider. The atoms everything else is built from.
   Part of the split component library. Exports go to window so other Babel
   <script> blocks (galleries, screens, the live prototype) can use them.
   ============================================================================ */

const {
  useState,
  useEffect,
  useRef,
  useCallback,
  useMemo
} = React;

/* ── Icon shortcut ───────────────────────────────────────────────────────
   Renders Phosphor Regular icons. Accepts Material-style names (menu_book,
   bookmark, chevron_right, ...) and maps them to Phosphor's kebab-case
   equivalents — so callers stay legible and source-aligned.
   See preview/iconography.html for rationale on the Phosphor swap. */
const MATERIAL_TO_PHOSPHOR = {
  menu_book: "book-open",
  bookmark: "bookmark-simple",
  bookmark_border: "bookmark-simple",
  lock: "lock-simple",
  lock_open: "lock-simple-open",
  add: "plus",
  remove: "minus",
  settings: "gear-six",
  search: "magnifying-glass",
  more_horiz: "dots-three",
  chevron_right: "caret-right",
  chevron_left: "caret-left",
  check: "check",
  keyboard_arrow_up: "caret-up",
  keyboard_arrow_down: "caret-down",
  arrow_back: "arrow-left",
  close: "x",
  share: "share-network",
  ios_share: "share-fat",
  delete: "trash",
  delete_outline: "trash",
  alarm: "alarm",
  auto_stories: "books",
  view_list: "list",
  grid_view: "squares-four",
  sort: "arrows-down-up",
  schedule: "clock",
  library_add: "book-bookmark",
  title: "text-aa",
  palette: "palette",
  language: "translate",
  format_size: "text-aa",
  cloud_download: "cloud-arrow-down",
  cloud_upload: "cloud-arrow-up",
  auto_awesome: "sparkle",
  folder_open: "folder-open",
  content_copy: "copy",
  tune: "sliders-horizontal",
  format_list_bulleted: "list-bullets",
  wb_sunny: "sun",
  block: "prohibit"
};
const Icon = ({
  name,
  size = 20,
  color,
  style,
  onClick
}) => {
  const phName = MATERIAL_TO_PHOSPHOR[name] || name.replace(/_/g, "-");
  const baseClass = name === "bookmark" ? "ph-fill" : "ph";
  return /*#__PURE__*/React.createElement("i", {
    className: `${baseClass} ph-${phName}`,
    onClick: onClick,
    style: {
      fontSize: size,
      color: color || "var(--nyan-text)",
      lineHeight: 1,
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      ...style
    }
  });
};

/* ── Primary button (NyanPrimaryButton) ──────────────────────────────────
   Heights are LOCKED, never grown by padding. Choose by `size`:
     sm = 36px  (in-card CTAs)
     md = 44px  (default body CTA · matches minTapTarget)
     lg = 52px  (hero / sticky bottom CTA only)
   Padding is horizontal only; the label is single-line with ellipsis. */
const NyanPrimaryButton = ({
  label,
  onPress,
  icon,
  expanded = false,
  variant = "primary",
  size = "md",
  style
}) => {
  const height = size === "sm" ? 36 : size === "lg" ? 52 : 44;
  const padX = size === "sm" ? 14 : size === "lg" ? 28 : 24;
  const fz = size === "sm" ? 14 : size === "lg" ? 17 : 16;
  const iconSz = size === "sm" ? 16 : 18;
  const bg = variant === "deep" ? "var(--nyan-primary-deep)" : variant === "ghost" ? "transparent" : "var(--nyan-primary)";
  const fg = variant === "ghost" ? "var(--nyan-primary-deep)" : "var(--nyan-surface)";
  return /*#__PURE__*/React.createElement("button", {
    onClick: onPress,
    style: {
      all: "unset",
      cursor: "pointer",
      boxSizing: "border-box",
      height,
      padding: `0 ${padX}px`,
      background: bg,
      color: fg,
      font: `${variant === "ghost" ? 600 : 500} ${fz}px/1 var(--font-ui)`,
      borderRadius: "var(--radius-input)",
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      gap: 6,
      width: expanded ? "100%" : "auto",
      textAlign: "center",
      flexShrink: 0,
      ...style
    }
  }, icon && /*#__PURE__*/React.createElement(Icon, {
    name: icon,
    size: iconSz,
    color: fg
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      whiteSpace: "nowrap",
      overflow: "hidden",
      textOverflow: "ellipsis",
      minWidth: 0
    }
  }, label));
};

/* ── Pill chip — the outline-on-select signature ──────────────────────────
   One option-chip treatment for the whole system (warmth, line-height, font,
   sort, theme...). Resting: recessed muted fill, no border. Selected: the
   fill drops away and a matcha-deep outline + matcha text takes over — the
   chip "lifts off the track". Radius is --r-chip (12), the deepest-nested
   member of the concentric family. */
const PillButton = ({
  label,
  selected,
  onPress,
  icon,
  style
}) => /*#__PURE__*/React.createElement("button", {
  onClick: onPress,
  style: {
    all: "unset",
    cursor: "pointer",
    boxSizing: "border-box",
    padding: "9px 16px",
    minWidth: 0,
    minHeight: 36,
    borderRadius: "var(--r-chip)",
    background: selected ? "transparent" : "var(--nyan-surface-muted)",
    color: selected ? "var(--nyan-primary-deep)" : "var(--nyan-text-secondary)",
    border: selected ? "1.5px solid var(--nyan-primary-deep)" : "1.5px solid transparent",
    font: "500 14px/1 var(--font-ui)",
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
    transition: "color 160ms var(--ease-paper), border-color 160ms var(--ease-paper), background 160ms var(--ease-paper)",
    ...style
  }
}, icon && /*#__PURE__*/React.createElement(Icon, {
  name: icon,
  size: 16,
  color: selected ? "var(--nyan-primary-deep)" : "var(--nyan-text-secondary)"
}), label);

/* ── Switch (Material-ish, Nyan-tinted) ──────────────────────────────────── */
const NyanSwitch = ({
  value,
  onChange
}) => /*#__PURE__*/React.createElement("div", {
  onClick: () => onChange(!value),
  style: {
    width: 44,
    height: 26,
    borderRadius: 999,
    background: value ? "var(--nyan-primary)" : "color-mix(in srgb, var(--nyan-divider) 100%, transparent)",
    position: "relative",
    cursor: "pointer",
    transition: "background 150ms ease",
    flexShrink: 0
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    position: "absolute",
    top: 3,
    left: value ? 21 : 3,
    width: 20,
    height: 20,
    background: "var(--nyan-surface)",
    borderRadius: "50%",
    boxShadow: "0 1px 2px rgba(0,0,0,0.08)",
    transition: "left 200ms ease"
  }
}));

/* ── Segmented tab control (NyanSegmentedTabControl) ─────────────────────────
   ONE recessed-track style for the whole system — top-level views AND sort.
   The track is recessed by TONE (surface-muted), never a border; the selected
   segment is a floating paper chip (surface + grouped shadow) that slides.
   Selected text is always matcha-deep — the single raised voice.
   `style="subtle"` swaps the white chip for a matcha-tint chip (same family). */
const SegmentedTabControl = ({
  tabs,
  selected,
  onChange,
  style = "emphasis"
}) => {
  const subtle = style === "subtle";
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: 40,
      background: "var(--nyan-surface-muted)",
      borderRadius: "var(--r-control)",
      padding: 4,
      display: "grid",
      gridTemplateColumns: `repeat(${tabs.length}, 1fr)`,
      position: "relative"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      top: 4,
      bottom: 4,
      left: `calc(${selected / tabs.length * 100}% + 4px)`,
      width: `calc(${100 / tabs.length}% - 8px)`,
      background: subtle ? "color-mix(in srgb, var(--nyan-primary) 16%, transparent)" : "var(--nyan-surface)",
      borderRadius: "calc(var(--r-control) - 3px)",
      boxShadow: subtle ? "none" : "var(--shadow-grouped)",
      transition: "left var(--dur-chrome) var(--ease-paper)"
    }
  }), tabs.map((t, i) => {
    const isSel = i === selected;
    const color = isSel ? "var(--nyan-primary-deep)" : "var(--nyan-text-secondary)";
    return /*#__PURE__*/React.createElement("button", {
      key: i,
      onClick: () => onChange(i),
      style: {
        all: "unset",
        cursor: "pointer",
        position: "relative",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        gap: 6,
        color,
        font: "500 14px/1 var(--font-ui)",
        zIndex: 1,
        padding: "0 4px",
        textAlign: "center"
      }
    }, t.icon && /*#__PURE__*/React.createElement(Icon, {
      name: t.icon,
      size: 16,
      color: color
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        overflow: "hidden",
        textOverflow: "ellipsis",
        whiteSpace: "nowrap"
      }
    }, t.label));
  }));
};

/* ── Slider (used in reader settings) ───────────────────────────────────── */
const NyanSlider = ({
  value,
  min = 0,
  max = 100,
  onChange,
  color = "var(--nyan-primary-deep)"
}) => {
  const trackRef = useRef(null);
  const onPointer = e => {
    const rect = trackRef.current.getBoundingClientRect();
    const x = (e.touches ? e.touches[0].clientX : e.clientX) - rect.left;
    const pct = Math.max(0, Math.min(1, x / rect.width));
    onChange(Math.round(min + pct * (max - min)));
  };
  const [dragging, setDragging] = useState(false);
  useEffect(() => {
    if (!dragging) return;
    const move = e => onPointer(e);
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
  const pct = (value - min) / (max - min) * 100;
  return /*#__PURE__*/React.createElement("div", {
    ref: trackRef,
    onMouseDown: e => {
      setDragging(true);
      onPointer(e);
    },
    onTouchStart: e => {
      setDragging(true);
      onPointer(e);
    },
    style: {
      position: "relative",
      height: 24,
      display: "flex",
      alignItems: "center",
      cursor: "pointer",
      touchAction: "none"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 0,
      right: 0,
      height: 6,
      background: "color-mix(in srgb, var(--nyan-text) 12%, transparent)",
      borderRadius: 999
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 0,
      width: `${pct}%`,
      height: 6,
      background: color,
      borderRadius: 999
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: `calc(${pct}% - 10px)`,
      width: 20,
      height: 20,
      background: "var(--nyan-surface)",
      borderRadius: "50%",
      boxShadow: `0 1px 4px color-mix(in srgb, var(--shadow-color) 28%, transparent), 0 0 0 1.5px color-mix(in srgb, ${color} 60%, transparent)`
    }
  }));
};

/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, {
  Icon,
  NyanPrimaryButton,
  PillButton,
  NyanSwitch,
  SegmentedTabControl,
  NyanSlider
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/primitives.jsx", error: String((e && e.message) || e) }); }

// components/reader.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* ============================================================================
   Nyan Read — Reader chrome — One Paper dock & settings body
   ----------------------------------------------------------------------------
   The reader paragraph, settings knobs/panels, shared ReaderSettingsBody, chapter list, dock footer, and the OnePaperDock shell (dock that grows into a sheet).
   Part of the split component library. Exports go to window so other Babel
   <script> blocks (galleries, screens, the live prototype) can use them.
   ============================================================================ */

const {
  useState,
  useEffect,
  useRef,
  useCallback,
  useMemo
} = React;

/* ── Reading text body (inside reader canvas) ───────────────────────────── */
const ReaderParagraph = ({
  children,
  serif = false,
  fontSize = 18,
  lineHeight = 1.75,
  color
}) => /*#__PURE__*/React.createElement("p", {
  style: {
    font: `400 ${fontSize}px/${lineHeight} ${serif ? "var(--font-serif)" : "var(--font-ui)"}`,
    color: color || "var(--reader-ink)",
    margin: "0 0 1.2em 0",
    textIndent: "2em",
    textAlign: "justify",
    textWrap: "pretty"
  }
}, children);

/* ════════════════════════════════════════════════════════════════════════
   ONE PAPER · shared reader chrome
   --------------------------------------------------------------------------
   The dock that grows into a sheet, the dock footer (progress + chapter
   stepper + 3 actions), and the reader sheet bodies. Extracted here so the
   live kit reader AND the spec bundles render the EXACT same chrome — one
   source of truth, no drift.
   ════════════════════════════════════════════════════════════════════════ */

/* Concentric nested card — recessed muted fill at radius 16, one step inside
   the radius-28 sheet (arc parallel to the parent). The only knob style. */

const Knob = ({
  label,
  hint,
  children
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    background: "var(--nyan-surface-muted)",
    borderRadius: "var(--r-card-nested)",
    padding: 14
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "baseline",
    marginBottom: 11
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    font: "600 15px/1.2 var(--font-ui)",
    color: "var(--nyan-text)"
  }
}, label), hint && /*#__PURE__*/React.createElement("div", {
  className: "nyan-meta"
}, hint)), children);
const DisplayPanel = ({
  t,
  setT
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    flexDirection: "column",
    gap: 12
  }
}, /*#__PURE__*/React.createElement(Knob, {
  label: "Brightness",
  hint: "Adjust the reading light"
}, /*#__PURE__*/React.createElement(NyanSlider, {
  value: t.brightness,
  min: 0,
  max: 100,
  onChange: v => setT({
    ...t,
    brightness: v
  })
}), /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    marginTop: 10
  }
}, /*#__PURE__*/React.createElement("div", {
  className: "nyan-meta"
}, "Follow system brightness"), /*#__PURE__*/React.createElement(NyanSwitch, {
  value: t.autoBrightness,
  onChange: v => setT({
    ...t,
    autoBrightness: v
  })
}))), /*#__PURE__*/React.createElement(Knob, {
  label: "Warmth",
  hint: "Reduce glare at night"
}, /*#__PURE__*/React.createElement(NyanSlider, {
  value: {
    low: 10,
    medium: 50,
    high: 90
  }[t.warmth],
  onChange: v => setT({
    ...t,
    warmth: v < 33 ? "low" : v < 66 ? "medium" : "high"
  }),
  color: "var(--hl-orange)"
}), /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    gap: 8,
    marginTop: 12
  }
}, ["low", "medium", "high"].map(w => /*#__PURE__*/React.createElement(PillButton, {
  key: w,
  label: w[0].toUpperCase() + w.slice(1),
  selected: t.warmth === w,
  onPress: () => setT({
    ...t,
    warmth: w
  }),
  style: {
    flex: 1
  }
})))), /*#__PURE__*/React.createElement(Knob, {
  label: "Page Turn Mode"
}, /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    gap: 8
  }
}, ["tap", "swipe", "disabled"].map(m => /*#__PURE__*/React.createElement(PillButton, {
  key: m,
  label: m[0].toUpperCase() + m.slice(1),
  selected: t.pageTurn === m,
  onPress: () => setT({
    ...t,
    pageTurn: m
  }),
  style: {
    flex: 1
  }
})))));
const TextPanel = ({
  t,
  setT
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    flexDirection: "column",
    gap: 12
  }
}, /*#__PURE__*/React.createElement(Knob, {
  label: "Font Size",
  hint: "Larger or smaller"
}, /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    alignItems: "center",
    gap: 12
  }
}, /*#__PURE__*/React.createElement("button", {
  onClick: () => setT({
    ...t,
    fontSize: Math.max(12, t.fontSize - 1)
  }),
  style: stepBtn
}, /*#__PURE__*/React.createElement(Icon, {
  name: "remove",
  size: 17,
  color: "var(--nyan-text)"
})), /*#__PURE__*/React.createElement("div", {
  style: {
    flex: 1
  }
}, /*#__PURE__*/React.createElement(NyanSlider, {
  value: t.fontSize,
  min: 12,
  max: 28,
  onChange: v => setT({
    ...t,
    fontSize: v
  })
})), /*#__PURE__*/React.createElement("button", {
  onClick: () => setT({
    ...t,
    fontSize: Math.min(28, t.fontSize + 1)
  }),
  style: stepBtn
}, /*#__PURE__*/React.createElement(Icon, {
  name: "add",
  size: 17,
  color: "var(--nyan-text)"
})), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "500 13px/1 var(--font-mono)",
    color: "var(--nyan-text-secondary)",
    minWidth: 34,
    textAlign: "right"
  }
}, t.fontSize, "pt"))), /*#__PURE__*/React.createElement(Knob, {
  label: "Line Height",
  hint: "Line spacing rhythm"
}, /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    gap: 8
  }
}, [["Compact", 1.45], ["Standard", 1.75], ["Comfortable", 2.05]].map(([lbl, val]) => /*#__PURE__*/React.createElement(PillButton, {
  key: lbl,
  label: lbl,
  selected: Math.abs(t.lineHeight - val) < 0.05,
  onPress: () => setT({
    ...t,
    lineHeight: val
  }),
  style: {
    flex: 1,
    minWidth: 0,
    padding: "9px 6px",
    whiteSpace: "nowrap"
  }
})))), /*#__PURE__*/React.createElement(Knob, {
  label: "Font Family"
}, /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    gap: 8
  }
}, /*#__PURE__*/React.createElement(PillButton, {
  label: "Sans",
  selected: !t.serif,
  onPress: () => setT({
    ...t,
    serif: false
  }),
  style: {
    flex: 1
  }
}), /*#__PURE__*/React.createElement(PillButton, {
  label: "Serif",
  selected: t.serif,
  onPress: () => setT({
    ...t,
    serif: true
  }),
  style: {
    flex: 1
  }
})), /*#__PURE__*/React.createElement("div", {
  style: {
    marginTop: 12,
    padding: 14,
    background: "var(--nyan-surface)",
    borderRadius: "var(--r-chip)",
    font: `400 ${t.fontSize}px/${t.lineHeight} ${t.serif ? "var(--font-serif)" : "var(--font-ui)"}`,
    color: "var(--nyan-text)"
  }
}, "The cat sat on the threshold for a long while. \u55B5\u9605")));
const ThemePanel = ({
  t,
  setT
}) => {
  const swatches = [{
    id: "cream",
    name: "Cream",
    preview: "#FFFCF5",
    ink: "#4A453E"
  }, {
    id: "sepia",
    name: "Sepia",
    preview: "#F5ECD8",
    ink: "#5C4F3F"
  }, {
    id: "sumi",
    name: "Sumi",
    preview: "#302D2B",
    ink: "#E5DED3"
  }, {
    id: "charcoal",
    name: "Charcoal",
    preview: "#1B1A19",
    ink: "#F1EBDD"
  }];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement(Knob, {
    label: "Reading Theme"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr",
      gap: 10
    }
  }, swatches.map(s => {
    const selected = t.readerTheme === s.id;
    return /*#__PURE__*/React.createElement("div", {
      key: s.id,
      onClick: () => setT({
        ...t,
        readerTheme: s.id
      }),
      style: {
        cursor: "pointer",
        padding: 12,
        background: s.preview,
        borderRadius: "var(--r-card-nested)",
        border: selected ? "1.5px solid var(--nyan-primary)" : "1.5px solid transparent",
        position: "relative",
        height: 74,
        display: "flex",
        flexDirection: "column",
        justifyContent: "space-between"
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        font: "600 14px/1 var(--font-ui)",
        color: s.ink
      }
    }, s.name), /*#__PURE__*/React.createElement("div", {
      style: {
        font: "400 13px/1 var(--font-serif)",
        color: s.ink,
        opacity: 0.72
      }
    }, "Aa \u6C38"), selected && /*#__PURE__*/React.createElement("div", {
      style: {
        position: "absolute",
        top: 8,
        right: 8,
        width: 22,
        height: 22,
        borderRadius: "50%",
        background: "var(--nyan-primary)",
        display: "grid",
        placeItems: "center"
      }
    }, /*#__PURE__*/React.createElement(Icon, {
      name: "check",
      size: 13,
      color: "var(--nyan-surface)"
    })));
  }))));
};

/* Chromeless settings body: tab switcher + active panel. The dock supplies the
   surface, grabber, header, and footer — this is just the controls. */

const ReaderSettingsBody = ({
  t,
  setT,
  tab,
  setTab
}) => /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(SegmentedTabControl, {
  style: "subtle",
  selected: tab,
  onChange: setTab,
  tabs: [{
    label: "Display"
  }, {
    label: "Text"
  }, {
    label: "Theme"
  }]
}), /*#__PURE__*/React.createElement("div", {
  style: {
    paddingTop: 14
  }
}, tab === 0 && /*#__PURE__*/React.createElement(DisplayPanel, {
  t: t,
  setT: setT
}), tab === 1 && /*#__PURE__*/React.createElement(TextPanel, {
  t: t,
  setT: setT
}), tab === 2 && /*#__PURE__*/React.createElement(ThemePanel, {
  t: t,
  setT: setT
})));

/* Chapter list — current chapter = matcha badge + primary-deep title + play. */

const ReaderChapterList = ({
  chapters,
  currentIndex,
  ascending = true,
  onSelect
}) => {
  const order = chapters.map((c, i) => [c, i]);
  const rows = ascending ? order : order.slice().reverse();
  return /*#__PURE__*/React.createElement("div", null, rows.map(([title, i]) => {
    const cur = i === currentIndex;
    return /*#__PURE__*/React.createElement("div", {
      key: i,
      "data-current": cur ? "true" : undefined,
      onClick: () => onSelect && onSelect(i),
      style: {
        display: "flex",
        alignItems: "center",
        gap: 14,
        padding: "12px 8px",
        borderRadius: "var(--r-chip)",
        cursor: "pointer",
        background: cur ? "color-mix(in srgb, var(--nyan-primary) 12%, transparent)" : "transparent"
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        width: 30,
        height: 30,
        flex: "none",
        borderRadius: "var(--r-chip)",
        display: "grid",
        placeItems: "center",
        background: cur ? "var(--nyan-primary)" : "var(--nyan-surface-muted)",
        color: cur ? "var(--nyan-surface)" : "var(--nyan-text-muted)",
        font: `${cur ? 600 : 500} 13px/1 var(--font-mono)`
      }
    }, i + 1), /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1,
        minWidth: 0,
        font: `${cur ? 500 : 400} 15px/1.35 var(--font-ui)`,
        color: cur ? "var(--nyan-primary-deep)" : "var(--nyan-text)"
      }
    }, title), cur && /*#__PURE__*/React.createElement("i", {
      className: "ph-fill ph-play",
      style: {
        color: "var(--nyan-primary)",
        fontSize: 16
      }
    }));
  }));
};

/* Dock footer — the persistent base of the One Paper panel:
   a chapter stepper flanking the progress bar, then the 3 actions.
   Stepper carets are the ONLY chapter-nav affordance in the model. */

const DockFooter = ({
  chapterIndex,
  chapterCount,
  progress,
  activeAction,
  onAction,
  onPrevChapter,
  onNextChapter,
  sheetOpen,
  actions
}) => {
  const acts = actions || [{
    key: "chapters",
    icon: "format_list_bulleted",
    label: "Chapters"
  }, {
    key: "bookmarks",
    icon: "bookmark_border",
    label: "Bookmarks"
  }, {
    key: "highlights",
    icon: "highlighter",
    label: "Highlights"
  }, {
    key: "settings",
    icon: "title",
    label: "Settings"
  }];
  const atStart = chapterIndex <= 0;
  const atEnd = chapterIndex >= chapterCount - 1;
  const step = disabled => ({
    all: "unset",
    cursor: disabled ? "default" : "pointer",
    width: 36,
    height: 36,
    flex: "none",
    borderRadius: "var(--r-chip)",
    display: "grid",
    placeItems: "center",
    opacity: disabled ? 0.32 : 1
  });
  return /*#__PURE__*/React.createElement("div", {
    style: {
      borderTop: sheetOpen ? "1px solid var(--nyan-divider)" : "1px solid transparent",
      transition: "border-color 200ms var(--ease-paper)"
    }
  }, !sheetOpen && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 6,
      padding: "11px 10px 3px"
    }
  }, /*#__PURE__*/React.createElement("button", {
    onClick: atStart ? undefined : onPrevChapter,
    style: step(atStart),
    title: "Previous chapter"
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "chevron_left",
    size: 20,
    color: "var(--nyan-text-secondary)"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      marginBottom: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "400 12px/1 var(--font-ui)",
      color: "var(--nyan-text-muted)"
    }
  }, "Chapter ", chapterIndex + 1, " of ", chapterCount), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "500 12px/1 var(--font-mono)",
      color: "var(--nyan-text-secondary)"
    }
  }, Math.round(progress * 100), "%")), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 4,
      borderRadius: 999,
      background: "color-mix(in srgb, var(--nyan-text) 11%, transparent)",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: `${progress * 100}%`,
      height: "100%",
      background: "var(--nyan-primary)",
      borderRadius: 999
    }
  }))), /*#__PURE__*/React.createElement("button", {
    onClick: atEnd ? undefined : onNextChapter,
    style: step(atEnd),
    title: "Next chapter"
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "chevron_right",
    size: 20,
    color: "var(--nyan-text-secondary)"
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      padding: sheetOpen ? "6px 8px 10px" : "8px 8px 12px"
    }
  }, acts.map(a => {
    const on = a.key === activeAction;
    return /*#__PURE__*/React.createElement("button", {
      key: a.key,
      onClick: () => onAction && onAction(a.key),
      style: {
        all: "unset",
        cursor: "pointer",
        flex: 1,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 5,
        padding: "8px 4px",
        borderRadius: 14,
        background: on ? "color-mix(in srgb, var(--nyan-primary) 12%, transparent)" : "transparent",
        color: on ? "var(--nyan-primary-deep)" : "var(--nyan-text-secondary)",
        transition: "background 160ms var(--ease-paper)"
      }
    }, /*#__PURE__*/React.createElement(Icon, {
      name: a.icon,
      size: 24,
      color: on ? "var(--nyan-primary-deep)" : "var(--nyan-text-secondary)"
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        font: `${on ? 600 : 500} 12px/1 var(--font-ui)`
      }
    }, a.label));
  })));
};

/* OnePaperDock — the floating panel that is a DOCK when collapsed and a SHEET
   when grown. Same width, inset, surface, shadow either way; radius eases
   24 → 28. Provide `sheetOpen` + `title`/`meta`/`children` for the grown body;
   the footer (DockFooter) is always pinned at the base.
   Place inside a position:relative reader frame; pass `visible` for immersive
   toggling. The parent owns the canvas recede + scrim. */

const OnePaperDock = ({
  visible = true,
  sheetOpen = false,
  title,
  meta,
  children,
  maxSheetHeight = 520,
  onStopProp = true,
  ...footer
}) => /*#__PURE__*/React.createElement("div", {
  onClick: onStopProp ? e => e.stopPropagation() : undefined,
  style: {
    position: "absolute",
    zIndex: 9,
    left: "var(--inset)",
    right: "var(--inset)",
    bottom: "var(--inset)",
    background: "var(--nyan-surface)",
    border: "1px solid var(--chrome-edge)",
    borderRadius: sheetOpen ? "var(--r-sheet)" : "var(--r-dock)",
    boxShadow: "var(--shadow-light-card)",
    overflow: "hidden",
    transform: visible ? "none" : "translateY(140%)",
    opacity: visible ? 1 : 0,
    pointerEvents: visible ? "auto" : "none",
    transition: "transform var(--dur-grow) var(--ease-paper), border-radius 260ms var(--ease-paper), opacity var(--dur-chrome) var(--ease-paper)"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    maxHeight: sheetOpen ? maxSheetHeight : 0,
    overflow: "hidden",
    transition: "max-height var(--dur-grow) var(--ease-paper)"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    maxHeight: maxSheetHeight,
    overflowY: "auto",
    padding: "0 14px 8px"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    width: 40,
    height: 5,
    borderRadius: 999,
    background: "var(--grabber)",
    margin: "10px auto 4px"
  }
}), /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    alignItems: "baseline",
    justifyContent: "space-between",
    padding: "6px 2px 12px"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    font: "600 20px/1.2 var(--font-ui)",
    color: "var(--nyan-text)",
    letterSpacing: "-0.2px"
  }
}, title), meta && /*#__PURE__*/React.createElement("div", {
  className: "nyan-meta"
}, meta)), children)), /*#__PURE__*/React.createElement(DockFooter, _extends({
  sheetOpen: sheetOpen
}, footer)));
const stepBtn = {
  all: "unset",
  cursor: "pointer",
  width: 34,
  height: 34,
  borderRadius: "var(--r-chip)",
  border: "1px solid var(--nyan-divider)",
  display: "grid",
  placeItems: "center",
  background: "var(--nyan-surface)"
};

/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, {
  ReaderParagraph,
  Knob,
  DisplayPanel,
  TextPanel,
  ThemePanel,
  ReaderSettingsBody,
  ReaderChapterList,
  DockFooter,
  OnePaperDock
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/reader.jsx", error: String((e && e.message) || e) }); }

// components/surfaces.jsx
try { (() => {
/* ============================================================================
   Nyan Read — Surfaces — containers & sheets
   ----------------------------------------------------------------------------
   Info card, list rows, grouped row stack, empty state, bottom sheet, action-sheet row, FAB.
   Part of the split component library. Exports go to window so other Babel
   <script> blocks (galleries, screens, the live prototype) can use them.
   ============================================================================ */

const {
  useState,
  useEffect,
  useRef,
  useCallback,
  useMemo
} = React;

/* ── Info card (NyanInfoCard) ────────────────────────────────────────────── */
const NyanInfoCard = ({
  children,
  variant = "standard",
  tone = "surface",
  padding = 16,
  onPress,
  style
}) => {
  const isGrouped = variant === "grouped";
  const radius = isGrouped ? "var(--radius-input)" : "var(--radius-card)";
  const shadow = isGrouped ? "var(--shadow-grouped)" : "var(--shadow-light-card)";
  const bg = tone === "muted" ? "var(--nyan-surface-muted)" : tone === "raised" ? "var(--nyan-surface-raised, var(--nyan-surface))" : "var(--nyan-surface)";
  const borderAlpha = isGrouped ? 0.16 : 0.3;
  const borderWidth = isGrouped ? 0.72 : 0.5;
  return /*#__PURE__*/React.createElement("div", {
    onClick: onPress,
    style: {
      background: bg,
      borderRadius: radius,
      boxShadow: shadow,
      border: `${borderWidth}px solid color-mix(in srgb, var(--nyan-divider) ${borderAlpha * 100}%, transparent)`,
      padding,
      cursor: onPress ? "pointer" : "default",
      ...style
    }
  }, children);
};

/* ── List row (NyanListRow / settings row) ───────────────────────────────── */
const NyanListRow = ({
  icon,
  title,
  subtitle,
  trailing,
  onPress,
  danger = false
}) => {
  const fg = danger ? "var(--error-secondary)" : "var(--nyan-text)";
  return /*#__PURE__*/React.createElement("div", {
    onClick: onPress,
    style: {
      background: "var(--nyan-surface)",
      padding: "14px 16px",
      display: "flex",
      alignItems: "center",
      gap: 12,
      cursor: onPress ? "pointer" : "default",
      minHeight: 56
    }
  }, icon && /*#__PURE__*/React.createElement("div", {
    style: {
      width: 36,
      height: 36,
      borderRadius: "var(--radius-small)",
      background: "color-mix(in srgb, var(--nyan-primary) 9%, transparent)",
      display: "grid",
      placeItems: "center",
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: icon,
    size: 17,
    color: danger ? "var(--error-secondary)" : "var(--nyan-primary)"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: "flex",
      flexDirection: "column",
      gap: 2,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 16px/1.2 var(--font-ui)",
      color: fg,
      whiteSpace: "nowrap",
      overflow: "hidden",
      textOverflow: "ellipsis"
    }
  }, title), subtitle && /*#__PURE__*/React.createElement("div", {
    className: "nyan-meta"
  }, subtitle)), trailing !== undefined ? trailing : onPress && /*#__PURE__*/React.createElement(Icon, {
    name: "chevron_right",
    size: 18,
    color: "color-mix(in srgb, var(--nyan-text-secondary) 44%, transparent)"
  }));
};

/* ── Grouped card stack — rows separated by hairlines, single rounded shell  */
const NyanRowGroup = ({
  children,
  style
}) => {
  const items = React.Children.toArray(children).filter(Boolean);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--nyan-surface)",
      borderRadius: "var(--radius-input)",
      border: "0.72px solid color-mix(in srgb, var(--nyan-divider) 16%, transparent)",
      boxShadow: "var(--shadow-grouped)",
      overflow: "hidden",
      ...style
    }
  }, items.map((c, i) => /*#__PURE__*/React.createElement(React.Fragment, {
    key: i
  }, c, i < items.length - 1 && /*#__PURE__*/React.createElement("div", {
    style: {
      height: 1,
      background: "var(--nyan-divider)",
      marginLeft: 64,
      opacity: 0.5
    }
  }))));
};

/* ── Empty state (NyanEmptyState) ────────────────────────────────────────── */
const NyanEmptyState = ({
  icon,
  title,
  description,
  action
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    textAlign: "center",
    padding: "32px 24px",
    gap: 16
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    padding: 14,
    background: "color-mix(in srgb, var(--nyan-primary) 8%, transparent)",
    borderRadius: "var(--radius-card)"
  }
}, typeof icon === "string" ? /*#__PURE__*/React.createElement(Icon, {
  name: icon,
  size: 34,
  color: "color-mix(in srgb, var(--nyan-primary) 80%, transparent)"
}) : icon), /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    flexDirection: "column",
    gap: 8,
    maxWidth: 320
  }
}, /*#__PURE__*/React.createElement("div", {
  className: "nyan-section"
}, title), description && /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 14px/1.5 var(--font-ui)",
    color: "var(--nyan-text-secondary)",
    whiteSpace: "pre-line"
  }
}, description)), action && /*#__PURE__*/React.createElement("div", {
  style: {
    marginTop: 4
  }
}, action));

/* ── Bottom sheet — "One Paper": floating, inset, warm scrim + blur ──────── */
const NyanBottomSheet = ({
  open,
  onClose,
  children,
  height
}) => {
  if (!open) return null;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      zIndex: 50,
      pointerEvents: "auto"
    }
  }, /*#__PURE__*/React.createElement("div", {
    onClick: onClose,
    style: {
      position: "absolute",
      inset: 0,
      background: "var(--scrim)",
      backdropFilter: "blur(var(--scrim-blur))",
      WebkitBackdropFilter: "blur(var(--scrim-blur))",
      animation: "nyanFade 220ms ease-out"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: "var(--inset)",
      right: "var(--inset)",
      bottom: "var(--inset)",
      background: "var(--nyan-surface-raised, var(--nyan-surface))",
      borderRadius: "var(--r-sheet)",
      border: "1px solid var(--chrome-edge)",
      boxShadow: "var(--shadow-light-card)",
      maxHeight: "calc(85% - 12px)",
      height: height ? `calc(${height} - 12px)` : undefined,
      display: "flex",
      flexDirection: "column",
      animation: "nyanSlideUp 280ms cubic-bezier(0.33,0.9,0.36,1)",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "12px 0 6px",
      display: "flex",
      justifyContent: "center"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 40,
      height: 5,
      borderRadius: 999,
      background: "var(--grabber)"
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minHeight: 0,
      overflow: "auto"
    }
  }, children)), /*#__PURE__*/React.createElement("style", null, `
        @keyframes nyanFade { from { opacity: 0; } to { opacity: 1; } }
        @keyframes nyanSlideUp { from { transform: translateY(120%); } to { transform: translateY(0); } }
      `));
};

/* ── Action-sheet row (NyanActionSheetRow) ───────────────────────────────── */
const NyanActionSheetRow = ({
  icon,
  title,
  subtitle,
  onPress,
  showChevron = true
}) => /*#__PURE__*/React.createElement("div", {
  onClick: onPress,
  style: {
    padding: "12px 16px",
    display: "flex",
    alignItems: "center",
    gap: 12,
    cursor: "pointer"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    width: 36,
    height: 36,
    borderRadius: "var(--radius-small)",
    background: "color-mix(in srgb, var(--nyan-primary) 9%, transparent)",
    display: "grid",
    placeItems: "center",
    flexShrink: 0
  }
}, /*#__PURE__*/React.createElement(Icon, {
  name: icon,
  size: 17,
  color: "var(--nyan-primary)"
})), /*#__PURE__*/React.createElement("div", {
  style: {
    flex: 1,
    minWidth: 0
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    font: "600 16px/1.2 var(--font-ui)",
    color: "var(--nyan-text)"
  }
}, title), /*#__PURE__*/React.createElement("div", {
  className: "nyan-meta",
  style: {
    marginTop: 4
  }
}, subtitle)), showChevron && /*#__PURE__*/React.createElement(Icon, {
  name: "chevron_right",
  size: 18,
  color: "color-mix(in srgb, var(--nyan-text-secondary) 44%, transparent)"
}));

/* ── Floating action button ─────────────────────────────────────────────── */
const NyanFAB = ({
  icon = "add",
  onPress,
  style
}) => /*#__PURE__*/React.createElement("button", {
  onClick: onPress,
  style: {
    all: "unset",
    cursor: "pointer",
    width: 56,
    height: 56,
    background: "var(--nyan-primary-deep)",
    color: "var(--nyan-surface)",
    borderRadius: "var(--r-dock)",
    display: "grid",
    placeItems: "center",
    boxShadow: "var(--shadow-light-card)",
    position: "absolute",
    right: "var(--inset)",
    bottom: "var(--inset)",
    ...style
  }
}, /*#__PURE__*/React.createElement(Icon, {
  name: icon,
  size: 26,
  color: "var(--nyan-surface)"
}));

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
  success: {
    icon: "check-circle",
    spin: false,
    fg: "var(--nyan-success)",
    tile: "color-mix(in srgb, var(--nyan-success) 13%, var(--nyan-surface))"
  },
  error: {
    icon: "warning-circle",
    spin: false,
    fg: "var(--error-primary)",
    tile: "var(--error-bg)"
  },
  skipped: {
    icon: "skip-forward",
    spin: false,
    fg: "var(--nyan-text-muted)",
    tile: "var(--nyan-surface-muted)"
  },
  info: {
    icon: "info",
    spin: false,
    fg: "var(--reader-info-blue)",
    tile: "color-mix(in srgb, var(--reader-info-blue) 13%, var(--nyan-surface))"
  },
  loading: {
    icon: "circle-notch",
    spin: true,
    fg: "var(--nyan-primary)",
    tile: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))"
  }
};
const NyanResponse = ({
  status = "success",
  title,
  description,
  action,
  onDismiss,
  placement = "static",
  style
}) => {
  const s = NYAN_RESPONSE_STATUS[status] || NYAN_RESPONSE_STATUS.success;
  const card = /*#__PURE__*/React.createElement("div", {
    role: "status",
    style: {
      display: "flex",
      alignItems: "center",
      gap: 12,
      background: "var(--nyan-surface)",
      border: "1px solid var(--chrome-edge)",
      borderRadius: "var(--r-card-nested)",
      boxShadow: "var(--shadow-subtle)",
      padding: "10px 12px",
      minHeight: 56,
      ...(placement === "static" ? style : null)
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 36,
      height: 36,
      flexShrink: 0,
      borderRadius: "var(--r-chip)",
      background: s.tile,
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: `ph ph-${s.icon}`,
    style: {
      fontSize: 20,
      color: s.fg,
      animation: s.spin ? "nyan-spin 900ms linear infinite" : undefined
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 14px/1.25 var(--font-ui)",
      color: "var(--nyan-text)",
      overflow: "hidden",
      textOverflow: "ellipsis",
      whiteSpace: description ? "nowrap" : "normal"
    }
  }, title), description && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 12.5px/1.35 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      marginTop: 2
    }
  }, description)), action && /*#__PURE__*/React.createElement("button", {
    onClick: action.onPress,
    style: {
      all: "unset",
      cursor: "pointer",
      flexShrink: 0,
      height: 32,
      padding: "0 12px",
      borderRadius: "var(--r-chip)",
      font: "600 13px/1 var(--font-ui)",
      color: "var(--nyan-primary-deep)",
      background: "color-mix(in srgb, var(--nyan-primary) 10%, transparent)"
    }
  }, action.label), onDismiss && /*#__PURE__*/React.createElement("button", {
    onClick: onDismiss,
    title: "Dismiss",
    style: {
      all: "unset",
      cursor: "pointer",
      flexShrink: 0,
      width: 32,
      height: 32,
      borderRadius: "var(--r-chip)",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-x",
    style: {
      fontSize: 16,
      color: "var(--nyan-text-muted)"
    }
  })));
  if (placement === "bottom") {
    return /*#__PURE__*/React.createElement("div", {
      style: {
        position: "absolute",
        left: "var(--inset)",
        right: "var(--inset)",
        bottom: "var(--inset)",
        zIndex: 60,
        ...style
      }
    }, card);
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
const NyanOptionSheet = ({
  title,
  subtitle,
  options = [],
  selected = 0,
  variant = "radio",
  onClose,
  style
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    position: "absolute",
    inset: 0,
    zIndex: 50,
    ...style
  }
}, /*#__PURE__*/React.createElement("div", {
  onClick: onClose,
  style: {
    position: "absolute",
    inset: 0,
    background: "var(--scrim)",
    backdropFilter: "blur(var(--scrim-blur))",
    WebkitBackdropFilter: "blur(var(--scrim-blur))",
    animation: "nyanFade 220ms ease-out"
  }
}), /*#__PURE__*/React.createElement("div", {
  style: {
    position: "absolute",
    left: "var(--inset)",
    right: "var(--inset)",
    bottom: "var(--inset)",
    background: "var(--nyan-surface)",
    border: "1px solid var(--chrome-edge)",
    borderRadius: "var(--r-sheet)",
    boxShadow: "var(--shadow-light-card)",
    overflow: "hidden",
    animation: "nyanSlideUp 280ms cubic-bezier(0.33,0.9,0.36,1)"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    paddingTop: 10,
    display: "flex",
    justifyContent: "center"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    width: 40,
    height: 5,
    borderRadius: 999,
    background: "var(--grabber)"
  }
})), /*#__PURE__*/React.createElement("div", {
  style: {
    padding: "12px 20px 8px",
    display: "flex",
    alignItems: "flex-start",
    gap: 12
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    flex: 1,
    minWidth: 0
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    font: "600 18px/1.2 var(--font-ui)",
    color: "var(--nyan-text)",
    letterSpacing: "-0.1px"
  }
}, title), subtitle && /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 13px/1.38 var(--font-ui)",
    color: "var(--nyan-text-secondary)",
    marginTop: 4
  }
}, subtitle)), /*#__PURE__*/React.createElement("button", {
  onClick: onClose,
  title: "Close",
  style: {
    all: "unset",
    cursor: "pointer",
    width: 32,
    height: 32,
    borderRadius: "var(--r-chip)",
    display: "grid",
    placeItems: "center",
    flexShrink: 0,
    marginTop: -2
  }
}, /*#__PURE__*/React.createElement("i", {
  className: "ph ph-x",
  style: {
    fontSize: 16,
    color: "var(--nyan-text-muted)"
  }
}))), /*#__PURE__*/React.createElement("div", {
  style: {
    padding: "4px 12px 16px",
    display: "flex",
    flexDirection: "column"
  }
}, options.map((raw, i) => {
  const o = typeof raw === "string" ? {
    label: raw
  } : raw;
  const isSel = variant === "radio" && i === selected;
  return /*#__PURE__*/React.createElement("button", {
    key: i,
    onClick: onClose,
    style: {
      all: "unset",
      cursor: "pointer",
      boxSizing: "border-box",
      display: "flex",
      alignItems: "center",
      gap: 12,
      padding: "12px 12px",
      minHeight: 56,
      borderRadius: "var(--r-card-nested)",
      background: isSel ? "color-mix(in srgb, var(--nyan-primary) 8%, transparent)" : "transparent"
    }
  }, o.swatch && /*#__PURE__*/React.createElement("div", {
    style: {
      width: 30,
      height: 30,
      borderRadius: "var(--r-chip)",
      flexShrink: 0,
      background: o.swatch,
      border: "1px solid color-mix(in srgb, var(--nyan-divider) 60%, transparent)"
    }
  }), o.icon && /*#__PURE__*/React.createElement("div", {
    style: {
      width: 36,
      height: 36,
      borderRadius: "var(--r-chip)",
      flexShrink: 0,
      background: "color-mix(in srgb, var(--nyan-primary) 10%, var(--nyan-surface-muted))",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: `ph ph-${o.icon}`,
    style: {
      fontSize: 18,
      color: "var(--nyan-primary)"
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: `${isSel ? 600 : 500} 15px/1.2 var(--font-ui)`,
      color: isSel ? "var(--nyan-primary-deep)" : "var(--nyan-text)"
    }
  }, o.label), o.hint && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 12.5px/1.3 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      marginTop: 2
    }
  }, o.hint)), variant === "radio" ? /*#__PURE__*/React.createElement("div", {
    style: {
      width: 22,
      height: 22,
      borderRadius: "50%",
      flexShrink: 0,
      display: "grid",
      placeItems: "center",
      border: `2px solid ${isSel ? "var(--nyan-primary)" : "color-mix(in srgb, var(--nyan-divider) 80%, transparent)"}`
    }
  }, isSel && /*#__PURE__*/React.createElement("div", {
    style: {
      width: 11,
      height: 11,
      borderRadius: "50%",
      background: "var(--nyan-primary)"
    }
  })) : /*#__PURE__*/React.createElement("i", {
    className: "ph ph-caret-right",
    style: {
      fontSize: 16,
      color: "var(--nyan-text-muted)",
      flexShrink: 0
    }
  }));
}))));

/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, {
  NyanInfoCard,
  NyanListRow,
  NyanRowGroup,
  NyanEmptyState,
  NyanBottomSheet,
  NyanActionSheetRow,
  NyanFAB,
  NyanResponse,
  NyanOptionSheet
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/surfaces.jsx", error: String((e && e.message) || e) }); }

// screens/bundle1.jsx
try { (() => {
/* ============================================================================
   Nyan Read — Screens: U1 Brightness · U2 Highlight Note Dialog · U3 Chapters (reader dock)
   ----------------------------------------------------------------------------
   Full-screen compositions assembled from components/*. Extracted verbatim from
   the bundle gallery so Claude Code can read/edit one screen without the HTML.
   Self-exports to window; the bundle HTML imports this then renders the gallery.
   ============================================================================ */

const {
  useState,
  useEffect,
  useRef
} = React;

/* ─────────────────────────────────────────────────────────────────
   SHARED HELPERS
───────────────────────────────────────────────────────────────── */

/* Simulated reader page — flat paper bg with prose */

/* Applies data-theme="sumi" so all --nyan-* vars cascade correctly */

/* ─────────────────────────────────────────────────────────────────
   U1 · BRIGHTNESS — One Paper model (two affordances, no glass HUD)
   The old centred frosted card is gone. Brightness now lives in:
     (a) an EDGE GESTURE — vertical drag on the left third of the page,
         surfacing a slim floating capsule (the daily, immersive path)
     (b) a TOP-BAR SUN POPOVER — discoverable affordance hung off the
         floating top bar; one inline NyanSlider, no full settings sheet
   Both use One Paper chrome: --nyan-surface, lightCard lift, --chrome-edge
   hairline, matcha fill, ring thumb.
───────────────────────────────────────────────────────────────── */

/* (a) Edge-gesture capsule — a vertical fill on the left third */
const BrightnessGestureHUD = ({
  initVal = 0.65,
  dark = false
}) => {
  const [val, setVal] = useState(initVal);
  const [dragging, setDrag] = useState(false);
  const trackRef = useRef(null);
  const clamped = Math.max(0.04, Math.min(1, val));
  const pct = Math.round(clamped * 100);
  const seek = e => {
    if (!trackRef.current) return;
    const r = trackRef.current.getBoundingClientRect();
    const cy = e.touches ? e.touches[0].clientY : e.clientY;
    setVal(Math.max(0, Math.min(1, 1 - (cy - r.top) / r.height)));
  };
  useEffect(() => {
    if (!dragging) return;
    const mm = e => seek(e),
      mu = () => setDrag(false);
    window.addEventListener("mousemove", mm);
    window.addEventListener("mouseup", mu);
    window.addEventListener("touchmove", mm, {
      passive: true
    });
    window.addEventListener("touchend", mu);
    return () => {
      window.removeEventListener("mousemove", mm);
      window.removeEventListener("mouseup", mu);
      window.removeEventListener("touchmove", mm);
      window.removeEventListener("touchend", mu);
    };
  }, [dragging]);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 0,
      top: 0,
      bottom: 0,
      width: "33%",
      background: dark ? "rgba(169,182,144,0.05)" : "rgba(110,122,85,0.04)",
      borderRight: "1px dashed color-mix(in srgb, var(--nyan-primary) 22%, transparent)"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 12,
      top: "50%",
      transform: "translateY(-50%)",
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      gap: 12,
      background: "var(--nyan-surface)",
      border: "1px solid var(--chrome-edge)",
      borderRadius: "var(--r-dock)",
      boxShadow: "var(--shadow-light-card)",
      padding: "16px 12px"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-sun",
    style: {
      fontSize: 18,
      color: "var(--nyan-primary-deep)"
    }
  }), /*#__PURE__*/React.createElement("div", {
    ref: trackRef,
    onMouseDown: e => {
      setDrag(true);
      seek(e);
    },
    onTouchStart: e => {
      setDrag(true);
      seek(e);
    },
    style: {
      position: "relative",
      width: 8,
      height: 150,
      borderRadius: 999,
      cursor: "pointer",
      touchAction: "none",
      background: "color-mix(in srgb, var(--nyan-text) 12%, transparent)",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 0,
      right: 0,
      bottom: 0,
      height: `${clamped * 100}%`,
      background: "var(--nyan-primary)",
      borderRadius: 999,
      transition: dragging ? "none" : "height 90ms ease"
    }
  })), /*#__PURE__*/React.createElement("i", {
    className: "ph ph-moon",
    style: {
      fontSize: 16,
      color: "var(--nyan-text-muted)"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 14px/1 var(--font-mono)",
      color: "var(--nyan-primary-deep)",
      fontVariantNumeric: "tabular-nums"
    }
  }, pct, "%")));
};

/* (b) Top-bar sun → centered Brightness dialog over a glass overlay.
   The dialog no longer hangs off the floating header — it lifts to the
   centre of the viewport, and the page behind recedes under a warm
   glassmorphism scrim (blur + saturate). The top bar stays as dimmed
   context with its sun control lit. */
const BrightnessPopover = ({
  initVal = 0.65,
  dark = false
}) => {
  const [val, setVal] = useState(Math.round(initVal * 100));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      top: 52,
      left: "var(--inset)",
      right: "var(--inset)",
      background: "var(--nyan-surface)",
      border: "1px solid var(--chrome-edge)",
      borderRadius: "var(--r-dock)",
      boxShadow: "var(--shadow-light-card)",
      display: "flex",
      alignItems: "center",
      gap: 6,
      padding: "9px 8px"
    }
  }, /*#__PURE__*/React.createElement("button", {
    style: {
      all: "unset",
      cursor: "pointer",
      width: 40,
      height: 40,
      borderRadius: "var(--r-control)",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "arrow_back",
    size: 21
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0,
      padding: "0 2px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 14px/1.2 var(--font-ui)",
      color: "var(--nyan-text)"
    }
  }, "The Stillwater Diaries"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 11.5px/1.2 var(--font-ui)",
      color: "var(--nyan-text-muted)"
    }
  }, "Kana Mori")), /*#__PURE__*/React.createElement("button", {
    style: {
      all: "unset",
      cursor: "pointer",
      width: 40,
      height: 40,
      borderRadius: "var(--r-control)",
      display: "grid",
      placeItems: "center",
      background: "color-mix(in srgb, var(--nyan-primary) 14%, transparent)"
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "wb_sunny",
    size: 21,
    color: "var(--nyan-primary-deep)"
  })), /*#__PURE__*/React.createElement("button", {
    style: {
      all: "unset",
      cursor: "pointer",
      width: 40,
      height: 40,
      borderRadius: "var(--r-control)",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "more_horiz",
    size: 21
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      zIndex: 20,
      background: dark ? "color-mix(in srgb, var(--nyan-bg) 42%, transparent)" : "color-mix(in srgb, var(--nyan-bg) 46%, transparent)",
      backdropFilter: "blur(13.6px) saturate(1.15)",
      WebkitBackdropFilter: "blur(13.6px) saturate(1.15)",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      padding: 24
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: "100%",
      maxWidth: 320,
      background: dark ? "color-mix(in srgb, var(--nyan-surface) 88%, transparent)" : "color-mix(in srgb, var(--nyan-surface) 82%, transparent)",
      border: "1px solid color-mix(in srgb, var(--nyan-surface) 70%, var(--chrome-edge))",
      borderRadius: "var(--r-sheet)",
      boxShadow: "var(--shadow-light-card)",
      backdropFilter: "blur(6px)",
      WebkitBackdropFilter: "blur(6px)",
      padding: 22
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 12,
      marginBottom: 18
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 38,
      height: 38,
      borderRadius: "var(--r-control)",
      flexShrink: 0,
      background: "color-mix(in srgb, var(--nyan-primary) 14%, transparent)",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "wb_sunny",
    size: 20,
    color: "var(--nyan-primary-deep)"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 17px/1.15 var(--font-ui)",
      color: "var(--nyan-text)",
      letterSpacing: "-0.1px"
    }
  }, "Brightness"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 12.5px/1.2 var(--font-ui)",
      color: "var(--nyan-text-muted)",
      marginTop: 2
    }
  }, "Adjust the reading light.")), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "600 18px/1 var(--font-mono)",
      color: "var(--nyan-primary-deep)",
      fontVariantNumeric: "tabular-nums"
    }
  }, val, "%")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "moon",
    size: 18,
    color: "var(--nyan-text-muted)"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement(NyanSlider, {
    value: val,
    min: 0,
    max: 100,
    onChange: setVal
  })), /*#__PURE__*/React.createElement(Icon, {
    name: "wb_sunny",
    size: 18,
    color: "var(--nyan-text-muted)"
  })))));
};
const U1Artboard = ({
  initVal,
  dark,
  mode
}) => /*#__PURE__*/React.createElement(ThemeWrap, {
  dark: dark
}, /*#__PURE__*/React.createElement(ReaderBg, {
  dark: dark
}, mode === "popover" ? /*#__PURE__*/React.createElement(BrightnessPopover, {
  initVal: initVal,
  dark: dark
}) : /*#__PURE__*/React.createElement(BrightnessGestureHUD, {
  initVal: initVal,
  dark: dark
})));

/* ─────────────────────────────────────────────────────────────────
   U2 · HIGHLIGHT NOTE DIALOG
   Layout: color-badge title row · excerpt preview card ·
           5-swatch picker pill · multiline note input · Cancel / Save
───────────────────────────────────────────────────────────────── */
const HL_SWATCHES = [{
  fill: "#F2E58A",
  ink: "#B89A2C",
  label: "Yellow"
}, {
  fill: "#A8D18D",
  ink: "#4E8A2D",
  label: "Green"
}, {
  fill: "#9EC5E8",
  ink: "#2E6B96",
  label: "Blue"
}, {
  fill: "#E8A0BF",
  ink: "#A84070",
  label: "Pink"
}, {
  fill: "#F2BE7E",
  ink: "#B8662A",
  label: "Orange"
}];
const EXCERPT_TEXT = "He set the lacquer cup down on the low table and looked, again, at the calligraphy hanging in the alcove.";
const NOTE_TEXT = "This moment of stillness mirrors the opening scene — the bell, the rain, and now the cup. A deliberate circularity.";
const HighlightNoteDialog = ({
  initColor = 0,
  initNote = "",
  dark = false
}) => {
  const [ci, setCi] = useState(initColor);
  const [note, setNote] = useState(initNote);
  const [focused, setFocused] = useState(false);
  const sel = HL_SWATCHES[ci];
  const inputBorder = focused ? "1px solid color-mix(in srgb, var(--nyan-primary) 30%, transparent)" : "1px solid color-mix(in srgb, var(--nyan-divider) 42%, transparent)";
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: "100%",
      maxWidth: 350,
      background: "var(--nyan-surface)",
      borderRadius: "var(--r-dock)",
      border: "1px solid var(--chrome-edge)",
      boxShadow: "var(--shadow-light-card)",
      padding: 18,
      display: "flex",
      flexDirection: "column"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 12,
      marginBottom: 10
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 24,
      height: 24,
      borderRadius: "50%",
      background: `color-mix(in srgb, ${sel.ink} 12%, var(--nyan-surface))`,
      border: `1px solid color-mix(in srgb, ${sel.ink} 10%, transparent)`,
      display: "grid",
      placeItems: "center",
      flexShrink: 0,
      transition: "background 180ms ease"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-pencil-line",
    style: {
      fontSize: 12,
      color: `color-mix(in srgb, ${sel.ink} 88%, var(--nyan-text))`
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      font: "600 18px/1.16 var(--font-ui)",
      color: "var(--nyan-text)",
      letterSpacing: "-0.1px"
    }
  }, "Edit Note"), /*#__PURE__*/React.createElement("button", {
    style: {
      all: "unset",
      cursor: "pointer",
      width: 40,
      height: 40,
      borderRadius: "var(--r-control)",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-trash",
    style: {
      fontSize: 19,
      color: "var(--nyan-text-muted)"
    }
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      background: `color-mix(in srgb, ${sel.ink} 6%, var(--nyan-surface-muted))`,
      border: `1px solid color-mix(in srgb, ${sel.ink} 14%, var(--nyan-divider))`,
      borderRadius: 16,
      padding: "9px 14px",
      display: "flex",
      alignItems: "flex-start",
      gap: 10,
      marginBottom: 12,
      minHeight: 48,
      transition: "background 200ms ease, border-color 200ms ease"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 2.5,
      alignSelf: "stretch",
      flexShrink: 0,
      borderRadius: 99,
      background: `color-mix(in srgb, ${sel.ink} 65%, transparent)`,
      marginTop: 2,
      transition: "background 200ms ease"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      font: "500 13.5px/1.38 var(--font-ui)",
      color: "var(--nyan-text)",
      opacity: 0.88,
      display: "-webkit-box",
      WebkitLineClamp: 2,
      WebkitBoxOrient: "vertical",
      overflow: "hidden"
    }
  }, EXCERPT_TEXT)), /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--nyan-surface-muted)",
      borderRadius: 16,
      padding: "10px 14px",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      gap: 16,
      marginBottom: 12
    }
  }, HL_SWATCHES.map((c, i) => {
    const active = i === ci;
    return /*#__PURE__*/React.createElement("button", {
      key: i,
      onClick: () => setCi(i),
      title: c.label,
      style: {
        all: "unset",
        cursor: "pointer",
        width: 26,
        height: 26,
        borderRadius: "50%",
        display: "grid",
        placeItems: "center",
        background: c.fill,
        boxShadow: active ? "0 0 0 2px var(--nyan-surface-muted), 0 0 0 3px var(--nyan-primary-deep)" : "inset 0 0 0 1px color-mix(in srgb, " + c.ink + " 20%, transparent)",
        transition: "box-shadow 160ms var(--ease-paper)"
      }
    });
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      background: "color-mix(in srgb, var(--nyan-surface-muted) 88%, var(--nyan-surface))",
      borderRadius: 16,
      border: inputBorder,
      padding: "12px 15px",
      minHeight: 82,
      marginBottom: 14,
      transition: "border-color 160ms ease"
    }
  }, /*#__PURE__*/React.createElement("textarea", {
    value: note,
    onChange: e => setNote(e.target.value),
    onFocus: () => setFocused(true),
    onBlur: () => setFocused(false),
    placeholder: "Add a note\u2026",
    style: {
      all: "unset",
      display: "block",
      width: "100%",
      minHeight: 58,
      font: "400 15px/1.42 var(--font-ui)",
      color: "var(--nyan-text)",
      resize: "none",
      boxSizing: "border-box"
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 10,
      justifyContent: "flex-end"
    }
  }, /*#__PURE__*/React.createElement(NyanPrimaryButton, {
    label: "Cancel",
    variant: "ghost",
    size: "lg"
  }), /*#__PURE__*/React.createElement(NyanPrimaryButton, {
    label: "Save",
    variant: "primary",
    size: "lg"
  })));
};
const U2Artboard = ({
  initColor,
  initNote,
  dark
}) => /*#__PURE__*/React.createElement(ThemeWrap, {
  dark: dark
}, /*#__PURE__*/React.createElement(ReaderBg, {
  dark: dark
}, /*#__PURE__*/React.createElement("div", {
  style: {
    position: "absolute",
    inset: 0,
    background: "var(--scrim)",
    backdropFilter: "blur(var(--scrim-blur))",
    WebkitBackdropFilter: "blur(var(--scrim-blur))",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    padding: 20
  }
}, /*#__PURE__*/React.createElement(HighlightNoteDialog, {
  initColor: initColor,
  initNote: initNote,
  dark: dark
}))));

/* ─────────────────────────────────────────────────────────────────
   U3 · CHAPTERS — strictly the One Paper reader dock, grown into a sheet.
   The dock footer (progress + chapter stepper + 3 actions) stays pinned;
   the page behind recedes under a warm scrim + blur. A "Jump to current
   chapter" button sits between the sort toggle and the list, scrolling the
   sheet back to the chapter you're reading.
───────────────────────────────────────────────────────────────── */
const TOC_DATA = ["The Threshold", "What the Bell Knows", "A Cup of Still Water", "The Calligraphy", "Late Spring Evening", "Wisteria in Rain", "The Gate Across the River", "Honest Sounds", "A Name Long Forgotten", "Second Strike", "The Lacquer Tray", "Folding the Page", "Three Hundred Readings", "The Open Shoji", "What Each Petal Meant", "The Quiet Occasion", "Across the River", "The Rest of the Night"];
const ChapterDockSheet = ({
  dark = false
}) => {
  const [asc, setAsc] = useState(true);
  const [curIndex, setCurIndex] = useState(2);
  const listWrapRef = useRef(null);
  const jumpToCurrent = () => {
    const wrap = listWrapRef.current;
    if (!wrap) return;
    const row = wrap.querySelector('[data-current="true"]');
    if (!row) return;
    // walk up to the nearest scrollable ancestor (the grown sheet body)
    let sc = wrap.parentElement;
    while (sc && !(sc.scrollHeight > sc.clientHeight + 1)) sc = sc.parentElement;
    if (!sc) return;
    const delta = row.getBoundingClientRect().top - sc.getBoundingClientRect().top;
    sc.scrollTop += delta - 12;
  };
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      zIndex: 8,
      background: "var(--scrim)",
      backdropFilter: "blur(var(--scrim-blur))",
      WebkitBackdropFilter: "blur(var(--scrim-blur))"
    }
  }), /*#__PURE__*/React.createElement(OnePaperDock, {
    visible: true,
    sheetOpen: true,
    title: "Chapters",
    meta: `${TOC_DATA.length} chapters`,
    maxSheetHeight: dark ? 430 : 430,
    chapterIndex: curIndex,
    chapterCount: TOC_DATA.length,
    progress: (curIndex + 0.4) / TOC_DATA.length,
    activeAction: "chapters",
    onAction: () => {},
    onPrevChapter: () => setCurIndex(i => Math.max(0, i - 1)),
    onNextChapter: () => setCurIndex(i => Math.min(TOC_DATA.length - 1, i + 1)),
    onStopProp: false
  }, /*#__PURE__*/React.createElement(SegmentedTabControl, {
    tabs: [{
      label: "Ascending"
    }, {
      label: "Descending"
    }],
    selected: asc ? 0 : 1,
    onChange: i => setAsc(i === 0),
    style: "subtle"
  }), /*#__PURE__*/React.createElement("div", {
    ref: listWrapRef,
    style: {
      marginTop: 10,
      paddingBottom: 4
    }
  }, /*#__PURE__*/React.createElement(ReaderChapterList, {
    chapters: TOC_DATA,
    currentIndex: curIndex,
    ascending: asc,
    onSelect: setCurIndex
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "sticky",
      bottom: 10,
      display: "flex",
      justifyContent: "flex-end",
      pointerEvents: "none",
      zIndex: 3
    }
  }, /*#__PURE__*/React.createElement("button", {
    onClick: jumpToCurrent,
    style: {
      all: "unset",
      boxSizing: "border-box",
      cursor: "pointer",
      pointerEvents: "auto",
      height: 44,
      padding: "0 18px",
      borderRadius: "var(--r-dock)",
      display: "inline-flex",
      alignItems: "center",
      gap: 8,
      background: "var(--nyan-primary-deep)",
      color: "var(--nyan-surface)",
      boxShadow: "var(--shadow-light-card)"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-crosshair-simple",
    style: {
      fontSize: 17,
      color: "var(--nyan-surface)"
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "600 13.5px/1 var(--font-ui)",
      color: "var(--nyan-surface)"
    }
  }, "Jump to current")))));
};
const U3Artboard = ({
  dark
}) => /*#__PURE__*/React.createElement(ThemeWrap, {
  dark: dark
}, /*#__PURE__*/React.createElement(ReaderBg, {
  dark: dark
}, /*#__PURE__*/React.createElement(ChapterDockSheet, {
  dark: dark
})));

/* ─────────────────────────────────────────────────────────────────
   DESIGN CANVAS
───────────────────────────────────────────────────────────────── */

/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, {
  BrightnessGestureHUD,
  BrightnessPopover,
  U1Artboard,
  HL_SWATCHES,
  EXCERPT_TEXT,
  NOTE_TEXT,
  HighlightNoteDialog,
  U2Artboard,
  TOC_DATA,
  ChapterDockSheet,
  U3Artboard
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "screens/bundle1.jsx", error: String((e && e.message) || e) }); }

// screens/bundle2-screens.jsx
try { (() => {
/* ============================================================================
   Nyan Read — Screens: U4 Reader Menu · U5 Text Selection Menu · U7 Splash · U8 Reader Error
   ----------------------------------------------------------------------------
   Full-screen compositions assembled from components/*. Extracted verbatim from
   the bundle gallery so Claude Code can read/edit one screen without the HTML.
   Self-exports to window; the bundle HTML imports this then renders the gallery.
   ============================================================================ */

const {
  useState,
  useRef,
  useEffect
} = React;

/* ── shared helpers ──────────────────────────────────────────────────── */

/* ──────────────────────────────────────────────────────────────────────
   U4 · READER MENU — strictly the One Paper reader dock, grown into the
   Reading Settings sheet. Renders the SHARED ReaderSettingsBody (the same
   Display / Text / Theme controls the live kit dock uses), under the dock
   header, with the dock footer (progress + chapter stepper + 3 actions)
   pinned below and the page receded under a warm scrim + blur.
   Replaces the old bespoke Pill + DisplayPanel + TextPanel + ThemePanel +
   ReaderMenuSheet — all of that now lives once, in components.jsx.
   ────────────────────────────────────────────────────────────────────── */
/* Per-tab factory defaults for the Reading Settings sheet. The header "Reset"
   control restores only the fields owned by the tab you're looking at — Display
   resets brightness/warmth/page-turn, Text resets size/spacing/family, Theme
   resets the reading theme. There is no separate footer "Reset to defaults"
   button under the Theme options; the header per-tab reset is the only reset. */
const U4_DEFAULTS = dark => ({
  brightness: 70,
  autoBrightness: true,
  warmth: "low",
  pageTurn: "tap",
  fontSize: 18,
  lineHeight: 1.75,
  serif: false,
  readerTheme: dark ? "sumi" : "cream"
});
const U4_TAB_FIELDS = [["brightness", "autoBrightness", "warmth", "pageTurn"],
// Display
["fontSize", "lineHeight", "serif"],
// Text
["readerTheme"] // Theme
];
const U4_TAB_NAMES = ["Display", "Text", "Theme"];
const ResetTabButton = ({
  tab,
  onReset
}) => /*#__PURE__*/React.createElement("button", {
  onClick: onReset,
  title: `Reset ${U4_TAB_NAMES[tab]} settings to defaults`,
  style: {
    all: "unset",
    cursor: "pointer",
    boxSizing: "border-box",
    display: "inline-flex",
    alignItems: "center",
    gap: 5,
    height: 30,
    padding: "0 2px",
    borderRadius: "var(--r-chip)",
    background: "transparent",
    color: "var(--nyan-primary-deep)",
    font: "500 12.5px/1 var(--font-ui)",
    transition: "opacity 160ms var(--ease-paper)"
  }
}, /*#__PURE__*/React.createElement("i", {
  className: "ph ph-arrow-counter-clockwise",
  style: {
    fontSize: 14
  }
}), "Reset ", U4_TAB_NAMES[tab]);
const U4ReaderDock = ({
  dark,
  initTab = 0
}) => {
  const [t, setT] = useState({
    brightness: 62,
    autoBrightness: false,
    warmth: "medium",
    pageTurn: "tap",
    fontSize: 18,
    lineHeight: 1.75,
    serif: false,
    readerTheme: dark ? "sumi" : "cream"
  });
  const [tab, setTab] = useState(initTab);
  const [curIndex, setCurIndex] = useState(3);
  const TOTAL = 18;
  const resetCurrentTab = () => {
    const defaults = U4_DEFAULTS(dark);
    const fields = U4_TAB_FIELDS[tab];
    setT(prev => {
      const next = {
        ...prev
      };
      fields.forEach(f => {
        next[f] = defaults[f];
      });
      return next;
    });
  };
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      zIndex: 8,
      background: "var(--scrim)",
      backdropFilter: "blur(var(--scrim-blur))",
      WebkitBackdropFilter: "blur(var(--scrim-blur))"
    }
  }), /*#__PURE__*/React.createElement(OnePaperDock, {
    visible: true,
    sheetOpen: true,
    title: "Reading Settings",
    meta: /*#__PURE__*/React.createElement(ResetTabButton, {
      tab: tab,
      onReset: resetCurrentTab
    }),
    maxSheetHeight: 470,
    chapterIndex: curIndex,
    chapterCount: TOTAL,
    progress: 0.42,
    activeAction: "settings",
    onAction: () => {},
    onPrevChapter: () => setCurIndex(i => Math.max(0, i - 1)),
    onNextChapter: () => setCurIndex(i => Math.min(TOTAL - 1, i + 1)),
    onStopProp: false
  }, /*#__PURE__*/React.createElement(ReaderSettingsBody, {
    t: t,
    setT: setT,
    tab: tab,
    setTab: setTab
  })));
};
const U4Artboard = ({
  dark,
  tab
}) => /*#__PURE__*/React.createElement(ReaderBg, {
  dark: dark
}, /*#__PURE__*/React.createElement(U4ReaderDock, {
  dark: dark,
  initTab: tab
}));

/* ──────────────────────────────────────────────────────────────────────
   U5 · TEXT SELECTION MENU
   Corrective: replaces Material elevation+grey with --nyan-surface card
   ────────────────────────────────────────────────────────────────────── */
const HL_DOTS = ["#D8C06B", "#A9C08E", "#7FABAC", "#CDA2A8", "#DBB686"];
const TextSelectionMenu = ({
  dark
}) => /*#__PURE__*/React.createElement("div", {
  "data-theme": dark ? "sumi" : undefined,
  style: {
    display: "inline-flex",
    alignItems: "center",
    background: "var(--nyan-surface)",
    borderRadius: 16,
    border: "1px solid var(--chrome-edge)",
    boxShadow: "var(--shadow-light-card)",
    padding: "6px 8px",
    gap: 4
  }
}, [["ph-copy", "Copy"], ["ph-magnifying-glass", "Search"]].map(([ic, label]) => /*#__PURE__*/React.createElement("button", {
  key: label,
  style: {
    all: "unset",
    cursor: "pointer",
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    gap: 3,
    padding: "6px 10px",
    borderRadius: "var(--r-chip)"
  }
}, /*#__PURE__*/React.createElement("i", {
  className: `ph ${ic}`,
  style: {
    fontSize: 18,
    color: "var(--nyan-primary)"
  }
}), /*#__PURE__*/React.createElement("span", {
  style: {
    font: "400 10px/1 var(--font-ui)",
    color: "var(--nyan-text-muted)"
  }
}, label))), /*#__PURE__*/React.createElement("div", {
  style: {
    width: "0.72px",
    height: 32,
    background: "color-mix(in srgb, var(--nyan-divider) 60%, transparent)",
    flexShrink: 0,
    margin: "0 2px"
  }
}), HL_DOTS.map((c, i) => /*#__PURE__*/React.createElement("button", {
  key: i,
  title: ["Yellow", "Green", "Blue", "Pink", "Orange"][i],
  style: {
    all: "unset",
    cursor: "pointer",
    width: 32,
    height: 32,
    borderRadius: "50%",
    display: "grid",
    placeItems: "center"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    width: 22,
    height: 22,
    borderRadius: "50%",
    background: c,
    border: "1.5px solid color-mix(in srgb, var(--nyan-surface) 80%, transparent)",
    boxShadow: "0 1px 3px rgba(0,0,0,0.10)"
  }
}))));
const U5Artboard = ({
  dark
}) => /*#__PURE__*/React.createElement(ReaderBg, {
  dark: dark
}, /*#__PURE__*/React.createElement("div", {
  style: {
    position: "absolute",
    inset: 0,
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    gap: 12
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    maxWidth: 290,
    font: "400 15px/1.6 var(--font-ui)",
    color: dark ? "#E5DED3" : "#4A453E",
    textAlign: "center"
  }
}, /*#__PURE__*/React.createElement("span", {
  style: {
    background: "#D8C06B80",
    borderRadius: 3,
    padding: "1px 0"
  }
}, "only the bell and the rain felt honest")), /*#__PURE__*/React.createElement("div", {
  style: {
    transform: "translateY(-4px)"
  }
}, /*#__PURE__*/React.createElement(TextSelectionMenu, {
  dark: dark
}))));

/* ──────────────────────────────────────────────────────────────────────
   U6 · PIN OVERLAY (SECURE ENTRY DIALOG)
   Corrective: scrim is rgba(0,0,0,0.32) NOT Colors.black87 (0.87)
               No pure black — all surfaces use --nyan tokens
   ────────────────────────────────────────────────────────────────────── */
/* ──────────────────────────────────────────────────────────────────────
   U6 · REMOVED — PIN entry is consolidated into the full-screen privacy gate
   (U16, Bundle 4). A reading-app lock is a security boundary, so it should be
   an unmistakable full-screen takeover, not a dismissible dialog. One PIN UI,
   not two.
   ────────────────────────────────────────────────────────────────────── */

/* ──────────────────────────────────────────────────────────────────────
   U7 · SPLASH PAGE
   Corrective: Colors.white + PNG cover → --nyan-bg cream + logo-line.svg
   ────────────────────────────────────────────────────────────────────── */
/* ──────────────────────────────────────────────────────────────────────
   U7 · SPLASH PAGE  —  rebuilt to speak One Paper
   The launch screen now obeys the reader-chrome doctrine: cream paper page,
   one floating "paper" tile (surface · radius 28 · single soft lift) holding
   the brand mark, matcha as the only raised voice, concentric radii, and the
   paper-soft fade. Nothing is welded to the edge; nothing is pure white.
   ────────────────────────────────────────────────────────────────────── */
const SplashScreen = ({
  stage = "loaded",
  markSrc
}) => /*#__PURE__*/React.createElement(NyanSplash, {
  loading: stage === "loading",
  markSrc: markSrc
});
const U7Artboard = ({
  stage,
  markSrc
}) => /*#__PURE__*/React.createElement(SplashScreen, {
  stage: stage,
  markSrc: markSrc
});

/* ──────────────────────────────────────────────────────────────────────
   U8 · READER ERROR VIEW
   Uses --error-* tokens; mascot placeholder; expandable tech details
   ────────────────────────────────────────────────────────────────────── */
const ERROR_TYPES = {
  fileNotFound: {
    icon: "compass",
    title: "This book lost its way",
    body: "The file can't be found — it may have been moved or deleted.",
    retry: false
  },
  parseFailed: {
    icon: "warning-circle",
    title: "These pages are stuck together",
    body: "We couldn't open this file. It might be corrupted.",
    retry: true
  },
  unsupported: {
    icon: "file-dashed",
    title: "Nyan can't read this format",
    body: "This file type isn't supported yet.",
    retry: false
  }
};
const ErrorView = ({
  dark,
  type = "fileNotFound"
}) => {
  const [details, setDetails] = useState(false);
  const e = ERROR_TYPES[type];
  return /*#__PURE__*/React.createElement("div", {
    "data-theme": dark ? "sumi" : undefined,
    style: {
      width: "100%",
      height: "100%",
      background: "var(--nyan-bg)",
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "center",
      textAlign: "center",
      padding: "32px 28px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 84,
      height: 84,
      borderRadius: "50%",
      background: "color-mix(in srgb, var(--error-primary) 8%, var(--nyan-surface))",
      border: "0.7px solid color-mix(in srgb, var(--error-primary) 22%, transparent)",
      display: "grid",
      placeItems: "center",
      marginBottom: 18
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: `ph ph-${e.icon}`,
    style: {
      fontSize: 36,
      color: "var(--error-primary)",
      opacity: 0.82
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 18px/1.25 var(--font-ui)",
      color: "var(--nyan-text)",
      opacity: 0.84,
      marginBottom: 8
    }
  }, e.title), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 14px/1.5 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      opacity: 0.74,
      maxWidth: 268,
      textWrap: "pretty",
      marginBottom: 26
    }
  }, e.body), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(NyanPrimaryButton, {
    label: "Back to Bookshelf",
    variant: "ghost",
    icon: "arrow_back"
  }), e.retry && /*#__PURE__*/React.createElement(NyanPrimaryButton, {
    label: "Retry",
    variant: "primary",
    icon: "arrow_clockwise"
  })), /*#__PURE__*/React.createElement("button", {
    style: {
      all: "unset",
      cursor: "pointer",
      height: 44,
      marginTop: 6,
      padding: "0 14px",
      display: "flex",
      alignItems: "center",
      gap: 7,
      font: "500 13px/1 var(--font-ui)",
      color: "var(--nyan-text-muted)"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-bug-beetle",
    style: {
      fontSize: 15
    }
  }), "Report to developer"), type === "parseFailed" && /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 10,
      width: "100%",
      maxWidth: 320
    }
  }, /*#__PURE__*/React.createElement("button", {
    onClick: () => setDetails(d => !d),
    style: {
      all: "unset",
      cursor: "pointer",
      font: "400 12px/1.2 var(--font-ui)",
      color: "var(--nyan-text-muted)",
      display: "block",
      textAlign: "center",
      width: "100%",
      paddingBottom: 10
    }
  }, details ? "Hide technical details" : "Show technical details"), details && /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--nyan-surface-muted)",
      borderRadius: 12,
      border: "1px solid var(--nyan-divider)",
      padding: 12,
      textAlign: "left"
    }
  }, /*#__PURE__*/React.createElement("pre", {
    style: {
      margin: 0,
      font: "400 10.5px/1.5 var(--font-mono)",
      color: "var(--nyan-text-secondary)",
      whiteSpace: "pre-wrap",
      wordBreak: "break-all"
    }
  }, `EpubException: Unexpected token at byte 0x2F4A\n  at EpubParser.parse (epub_parser.dart:184)\n  at ReaderEngine.loadBook (reader_engine.dart:62)`))));
};
const U8Artboard = ({
  dark,
  type
}) => /*#__PURE__*/React.createElement(ErrorView, {
  dark: dark,
  type: type
});

/* ──────────────────────────────────────────────────────────────────────
   DESIGN CANVAS
   ────────────────────────────────────────────────────────────────────── */

/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, {
  U4ReaderDock,
  U4Artboard,
  HL_DOTS,
  TextSelectionMenu,
  U5Artboard,
  SplashScreen,
  U7Artboard,
  ERROR_TYPES,
  ErrorView,
  U8Artboard
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "screens/bundle2-screens.jsx", error: String((e && e.message) || e) }); }

// screens/bundle3.jsx
try { (() => {
/* ============================================================================
   Nyan Read — Screens: U9 Bookshelf · U10 Book Details · U11 Import Sheet · U12 Bookmarks · U13 Notes & Highlights
   ----------------------------------------------------------------------------
   Full-screen compositions assembled from components/*. Extracted verbatim from
   the bundle gallery so Claude Code can read/edit one screen without the HTML.
   Self-exports to window; the bundle HTML imports this then renders the gallery.
   ============================================================================ */

const {
  useState
} = React;

/* Screen scaffold helpers (PageHdr / SectionHdr / RowGroup / ListRow) and the
   reader/app wrappers are shared from screens/_chrome.jsx. */

/* ──────────────────────────────────────────────────────────────────────
   U9 · BOOKSHELF HOME SCREEN
   ────────────────────────────────────────────────────────────────────── */
const BOOKS = [{
  id: 1,
  title: "The Stillwater Diaries",
  author: "Matsuno Eri",
  fmt: "EPUB",
  pct: 42,
  isPrivate: false
}, {
  id: 2,
  title: "Borrowed Light",
  author: "Yuen Lai-Ying",
  fmt: "TXT",
  pct: 0,
  isPrivate: false
}, {
  id: 3,
  title: "A Long Slope Down",
  author: "Park Hyun-joo",
  fmt: "PDF",
  pct: 88,
  isPrivate: false
}, {
  id: 4,
  title: "Sand and Memoir",
  author: "Unknown",
  fmt: "EPUB",
  pct: 12,
  isPrivate: false
}];
const BookCard = ({
  book,
  dark
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    flexDirection: "column",
    gap: 6,
    cursor: "pointer"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    width: "100%",
    aspectRatio: "120/156",
    borderRadius: 12,
    background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))",
    border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)",
    display: "grid",
    placeItems: "center",
    position: "relative",
    overflow: "hidden"
  }
}, /*#__PURE__*/React.createElement("i", {
  className: "ph ph-book-open",
  style: {
    fontSize: 26,
    color: "var(--nyan-primary)"
  }
}), /*#__PURE__*/React.createElement("div", {
  style: {
    position: "absolute",
    top: 6,
    right: 6,
    height: 17,
    padding: "0 6px",
    borderRadius: 999,
    background: "color-mix(in srgb, var(--nyan-surface) 88%, transparent)",
    border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)",
    display: "flex",
    alignItems: "center"
  }
}, /*#__PURE__*/React.createElement("span", {
  style: {
    font: "600 9px/1 var(--font-ui)",
    color: "var(--nyan-primary-deep)"
  }
}, book.fmt))), book.pct > 0 && /*#__PURE__*/React.createElement("div", {
  style: {
    height: 3,
    borderRadius: 999,
    background: "color-mix(in srgb, var(--nyan-primary) 16%, var(--nyan-surface))",
    overflow: "hidden"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    width: `${book.pct}%`,
    height: "100%",
    borderRadius: 999,
    background: "var(--nyan-primary)"
  }
})), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
  style: {
    font: "600 12.5px/1.25 var(--font-ui)",
    color: "var(--nyan-text)",
    overflow: "hidden",
    display: "-webkit-box",
    WebkitLineClamp: 2,
    WebkitBoxOrient: "vertical"
  }
}, book.title), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 11px/1.3 var(--font-ui)",
    color: "var(--nyan-text-muted)",
    marginTop: 2,
    whiteSpace: "nowrap",
    overflow: "hidden",
    textOverflow: "ellipsis"
  }
}, book.author)));
const ContinueCard = ({
  book,
  dark,
  initOpen = true
}) => {
  const [open, setOpen] = useState(initOpen);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--nyan-surface)",
      borderRadius: 16,
      border: "0.72px solid color-mix(in srgb, var(--nyan-divider) 36%, transparent)",
      boxShadow: "var(--shadow-subtle)",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    onClick: () => setOpen(o => !o),
    style: {
      display: "flex",
      alignItems: "center",
      gap: 10,
      padding: open ? "12px 12px 8px" : "11px 12px",
      cursor: "pointer"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-book-open-text",
    style: {
      fontSize: 15,
      color: "var(--nyan-primary)",
      flexShrink: 0
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "500 11px/1.2 var(--font-ui)",
      color: "var(--nyan-text-muted)",
      letterSpacing: "0.2px"
    }
  }, "Continue Reading"), !open && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 13px/1.3 var(--font-ui)",
      color: "var(--nyan-text)",
      marginTop: 2,
      whiteSpace: "nowrap",
      overflow: "hidden",
      textOverflow: "ellipsis"
    }
  }, book.title)), !open && /*#__PURE__*/React.createElement("span", {
    style: {
      font: "600 11px/1 var(--font-ui)",
      color: "var(--nyan-primary-deep)",
      fontVariantNumeric: "tabular-nums",
      flexShrink: 0
    }
  }, book.pct, "%"), /*#__PURE__*/React.createElement("i", {
    className: "ph ph-caret-down",
    style: {
      fontSize: 15,
      color: "var(--nyan-text-muted)",
      flexShrink: 0,
      transform: open ? "rotate(180deg)" : "none",
      transition: "transform 200ms var(--ease-paper)"
    }
  })), open && /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "0 12px 12px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 56,
      height: 72,
      borderRadius: 14,
      background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface-muted))",
      border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)",
      flexShrink: 0,
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-book-open",
    style: {
      fontSize: 22,
      color: "var(--nyan-primary)"
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0,
      display: "flex",
      flexDirection: "column",
      justifyContent: "center",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 14px/1.3 var(--font-ui)",
      color: "var(--nyan-text)",
      overflow: "hidden",
      display: "-webkit-box",
      WebkitLineClamp: 2,
      WebkitBoxOrient: "vertical"
    }
  }, book.title), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 12px/1.3 var(--font-ui)",
      color: "var(--nyan-text-muted)",
      marginTop: 2,
      whiteSpace: "nowrap",
      overflow: "hidden",
      textOverflow: "ellipsis"
    }
  }, book.author)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      height: 3,
      borderRadius: 999,
      background: "color-mix(in srgb, var(--nyan-primary) 16%, var(--nyan-surface-muted))",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: `${book.pct}%`,
      height: "100%",
      borderRadius: 999,
      background: "var(--nyan-primary)"
    }
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "600 11px/1 var(--font-ui)",
      color: "var(--nyan-primary-deep)",
      fontVariantNumeric: "tabular-nums"
    }
  }, book.pct, "%")))), /*#__PURE__*/React.createElement("button", {
    style: {
      all: "unset",
      boxSizing: "border-box",
      cursor: "pointer",
      marginTop: 12,
      width: "100%",
      height: 44,
      borderRadius: 14,
      background: "var(--nyan-primary)",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-book-open",
    style: {
      fontSize: 17,
      color: "var(--nyan-surface)"
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "600 14px/1 var(--font-ui)",
      color: "var(--nyan-surface)"
    }
  }, "Continue Reading"))));
};
const BookListRow = ({
  book
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    alignItems: "center",
    gap: 12,
    padding: "10px 12px",
    minHeight: 44,
    cursor: "pointer"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    width: 44,
    height: 58,
    flexShrink: 0,
    borderRadius: "var(--r-chip)",
    background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))",
    border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)",
    display: "grid",
    placeItems: "center"
  }
}, /*#__PURE__*/React.createElement("i", {
  className: "ph ph-book-open",
  style: {
    fontSize: 20,
    color: "var(--nyan-primary)"
  }
})), /*#__PURE__*/React.createElement("div", {
  style: {
    flex: 1,
    minWidth: 0
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    font: "600 14px/1.25 var(--font-ui)",
    color: "var(--nyan-text)",
    whiteSpace: "nowrap",
    overflow: "hidden",
    textOverflow: "ellipsis"
  }
}, book.title), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 12px/1.3 var(--font-ui)",
    color: "var(--nyan-text-muted)",
    marginTop: 1,
    whiteSpace: "nowrap",
    overflow: "hidden",
    textOverflow: "ellipsis"
  }
}, book.author), book.pct > 0 && /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    marginTop: 7
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    flex: 1,
    height: 3,
    borderRadius: 999,
    background: "color-mix(in srgb, var(--nyan-primary) 16%, var(--nyan-surface-muted))",
    overflow: "hidden"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    width: `${book.pct}%`,
    height: "100%",
    borderRadius: 999,
    background: "var(--nyan-primary)"
  }
})), /*#__PURE__*/React.createElement("span", {
  style: {
    font: "500 11px/1 var(--font-mono)",
    color: "var(--nyan-text-muted)"
  }
}, book.pct, "%"))), /*#__PURE__*/React.createElement("div", {
  style: {
    height: 18,
    padding: "0 7px",
    flexShrink: 0,
    borderRadius: 999,
    background: "var(--nyan-surface-muted)",
    border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)",
    display: "flex",
    alignItems: "center"
  }
}, /*#__PURE__*/React.createElement("span", {
  style: {
    font: "600 9px/1 var(--font-ui)",
    color: "var(--nyan-primary-deep)"
  }
}, book.fmt)), /*#__PURE__*/React.createElement("i", {
  className: "ph ph-caret-right",
  style: {
    fontSize: 15,
    color: "var(--nyan-text-muted)",
    flexShrink: 0
  }
}));
const BookshelfHome = ({
  dark,
  empty,
  view: initView,
  continueCollapsed,
  isPro = false,
  sort: initSort
}) => {
  const [tab, setTab] = useState(0);
  const [view, setView] = useState(initView || "grid");
  const [sort, setSort] = useState(!!initSort);
  return /*#__PURE__*/React.createElement(Shell, {
    dark: dark
  }, /*#__PURE__*/React.createElement(ShelfToolbar, {
    view: view,
    onToggleView: () => setView(v => v === "grid" ? "list" : "grid"),
    sort: sort,
    onToggleSort: () => setSort(s => !s),
    isPro: isPro,
    onSearch: () => {}
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "0 16px 10px",
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      background: "var(--nyan-surface-muted)",
      borderRadius: 14,
      padding: 3,
      gap: 2
    }
  }, ["Public Shelf", "Private Shelf"].map((t, i) => /*#__PURE__*/React.createElement("button", {
    key: t,
    onClick: () => setTab(i),
    style: {
      all: "unset",
      cursor: "pointer",
      flex: 1,
      height: 34,
      borderRadius: 11,
      background: tab === i ? "var(--nyan-surface)" : "transparent",
      boxShadow: tab === i ? "0 1px 3px rgba(0,0,0,0.06)" : "none",
      font: `${tab === i ? 600 : 500} 14px/1 var(--font-ui)`,
      color: tab === i ? "var(--nyan-text)" : "var(--nyan-text-muted)",
      display: "grid",
      placeItems: "center",
      transition: "background 160ms ease"
    }
  }, t)))), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: "auto",
      padding: "0 16px 88px"
    }
  }, empty || tab === 1 ? /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "center",
      height: "100%",
      gap: 14,
      textAlign: "center"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 80,
      height: 80,
      borderRadius: "50%",
      background: "color-mix(in srgb, var(--nyan-primary) 7%, var(--nyan-surface))",
      border: "0.7px solid color-mix(in srgb, var(--nyan-divider) 18%, transparent)",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-books",
    style: {
      fontSize: 34,
      color: "var(--nyan-primary)",
      opacity: 0.78
    }
  })), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 18px/1.25 var(--font-ui)",
      color: "var(--nyan-text)",
      opacity: 0.84,
      marginBottom: 8
    }
  }, "Bookshelf is waiting for stories"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 14px/1.4 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      opacity: 0.74
    }
  }, "Import a book to start reading"))) : /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(ContinueCard, {
    book: BOOKS[0],
    dark: dark,
    initOpen: !continueCollapsed
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 16
    }
  }), view === "grid" ? /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr 1fr",
      gap: "16px 12px"
    }
  }, BOOKS.concat(BOOKS).slice(0, 9).map((b, i) => /*#__PURE__*/React.createElement(BookCard, {
    key: i,
    book: b,
    dark: dark
  }))) : /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--nyan-surface)",
      borderRadius: 16,
      border: "1px solid var(--chrome-edge)",
      boxShadow: "var(--shadow-grouped)",
      overflow: "hidden"
    }
  }, BOOKS.concat(BOOKS).slice(0, 6).map((b, i) => /*#__PURE__*/React.createElement(React.Fragment, {
    key: i
  }, i > 0 && /*#__PURE__*/React.createElement("div", {
    style: {
      height: "0.5px",
      background: "color-mix(in srgb, var(--nyan-divider) 34%, transparent)",
      margin: "0 12px"
    }
  }), /*#__PURE__*/React.createElement(BookListRow, {
    book: b
  })))))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      right: 16,
      bottom: 24
    }
  }, /*#__PURE__*/React.createElement("button", {
    style: {
      all: "unset",
      cursor: "pointer",
      width: 54,
      height: 54,
      borderRadius: 16,
      background: "var(--nyan-primary-deep)",
      display: "grid",
      placeItems: "center",
      boxShadow: "var(--shadow-light-card)"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-plus",
    style: {
      fontSize: 24,
      color: "var(--nyan-surface)"
    }
  }))));
};

/* ──────────────────────────────────────────────────────────────────────
   U6 · BOOKSHELF SEARCH
   Full-screen search over the shelf. Opens from the toolbar Search tool.
   States: idle (recent + suggestions) · results · no-match. Reuses BookListRow.
   ────────────────────────────────────────────────────────────────────── */
const SEARCH_RECENT = ["Stillwater", "Matsuno Eri", "essays"];
const SEARCH_SUGGEST = ["Recently added", "In progress", "Finished", "PDF files"];
const SearchField = ({
  query,
  focused
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    flex: 1,
    height: 44,
    display: "flex",
    alignItems: "center",
    gap: 10,
    padding: "0 12px",
    borderRadius: "var(--r-control)",
    background: "var(--nyan-surface)",
    border: `1.5px solid ${focused ? "var(--nyan-primary)" : "color-mix(in srgb, var(--nyan-divider) 50%, transparent)"}`,
    boxShadow: focused ? "0 0 0 3px color-mix(in srgb, var(--nyan-primary) 12%, transparent)" : "none",
    transition: "border-color 140ms var(--ease-paper)"
  }
}, /*#__PURE__*/React.createElement("i", {
  className: "ph ph-magnifying-glass",
  style: {
    fontSize: 18,
    color: query ? "var(--nyan-primary)" : "var(--nyan-text-muted)",
    flexShrink: 0
  }
}), /*#__PURE__*/React.createElement("div", {
  style: {
    flex: 1,
    minWidth: 0,
    display: "flex",
    alignItems: "center",
    font: "400 15px/1 var(--font-ui)",
    color: query ? "var(--nyan-text)" : "var(--nyan-text-muted)",
    whiteSpace: "nowrap",
    overflow: "hidden"
  }
}, query || "Search title or author", focused && /*#__PURE__*/React.createElement("span", {
  style: {
    width: 1.5,
    height: 18,
    marginLeft: 1,
    background: "var(--nyan-primary)",
    animation: "nyan-caret 1100ms steps(1) infinite"
  }
})), query && /*#__PURE__*/React.createElement("button", {
  style: {
    all: "unset",
    cursor: "pointer",
    width: 22,
    height: 22,
    borderRadius: "50%",
    background: "color-mix(in srgb, var(--nyan-text) 12%, transparent)",
    display: "grid",
    placeItems: "center",
    flexShrink: 0
  }
}, /*#__PURE__*/React.createElement("i", {
  className: "ph ph-x",
  style: {
    fontSize: 12,
    color: "var(--nyan-surface)"
  }
})));
const SearchChip = ({
  icon,
  label
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    height: 34,
    padding: "0 12px",
    borderRadius: "var(--r-chip)",
    display: "inline-flex",
    alignItems: "center",
    gap: 7,
    background: "var(--nyan-surface-muted)",
    border: "1px solid color-mix(in srgb, var(--nyan-divider) 40%, transparent)",
    cursor: "pointer"
  }
}, /*#__PURE__*/React.createElement("i", {
  className: `ph ph-${icon}`,
  style: {
    fontSize: 14,
    color: "var(--nyan-text-muted)"
  }
}), /*#__PURE__*/React.createElement("span", {
  style: {
    font: "500 13px/1 var(--font-ui)",
    color: "var(--nyan-text-secondary)"
  }
}, label));
const BookshelfSearch = ({
  dark,
  query = "",
  focused = true,
  initView = "list"
}) => {
  const q = query.trim().toLowerCase();
  const results = q ? BOOKS.filter(b => b.title.toLowerCase().includes(q) || b.author.toLowerCase().includes(q)) : [];
  const [resultView, setResultView] = useState(initView);
  return /*#__PURE__*/React.createElement(Shell, {
    dark: dark
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "14px 12px 12px",
      display: "flex",
      alignItems: "center",
      gap: 8,
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("button", {
    style: {
      all: "unset",
      cursor: "pointer",
      width: 40,
      height: 40,
      borderRadius: "var(--r-control)",
      display: "grid",
      placeItems: "center",
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-arrow-left",
    style: {
      fontSize: 21,
      color: "var(--nyan-text)"
    }
  })), /*#__PURE__*/React.createElement(SearchField, {
    query: query,
    focused: focused
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: "auto",
      padding: "4px 16px 28px"
    }
  }, !q ?
  /*#__PURE__*/
  /* Idle — recent + suggestions */
  React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      padding: "8px 4px 10px"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "500 11px/1 var(--font-ui)",
      color: "var(--nyan-primary-deep)",
      letterSpacing: "0.22px",
      textTransform: "uppercase"
    }
  }, "Recent"), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "500 12px/1 var(--font-ui)",
      color: "var(--nyan-text-muted)",
      cursor: "pointer"
    }
  }, "Clear")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 2
    }
  }, SEARCH_RECENT.map(r => /*#__PURE__*/React.createElement("div", {
    key: r,
    style: {
      display: "flex",
      alignItems: "center",
      gap: 12,
      padding: "11px 6px",
      cursor: "pointer",
      minHeight: 44
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-clock-counter-clockwise",
    style: {
      fontSize: 18,
      color: "var(--nyan-text-muted)",
      flexShrink: 0
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      font: "400 15px/1.2 var(--font-ui)",
      color: "var(--nyan-text)"
    }
  }, r), /*#__PURE__*/React.createElement("i", {
    className: "ph ph-arrow-up-left",
    style: {
      fontSize: 16,
      color: "var(--nyan-text-muted)",
      flexShrink: 0
    }
  })))), /*#__PURE__*/React.createElement(SectionHdr, {
    label: "Quick filters"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexWrap: "wrap",
      gap: 8
    }
  }, [["sparkle", "Recently added"], ["book-open-text", "In progress"], ["check-circle", "Finished"], ["file-pdf", "PDF files"]].map(([ic, l]) => /*#__PURE__*/React.createElement(SearchChip, {
    key: l,
    icon: ic,
    label: l
  })))) : results.length ?
  /*#__PURE__*/
  /* Results */
  React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      gap: 8,
      padding: "8px 4px 12px"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "500 12px/1 var(--font-ui)",
      color: "var(--nyan-text-muted)"
    }
  }, results.length, " ", results.length === 1 ? "result" : "results", " for \"", query.trim(), "\""), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 2,
      padding: 3,
      borderRadius: 10,
      background: "var(--nyan-surface-muted)",
      flexShrink: 0
    }
  }, [["list", "list"], ["grid", "squares-four"]].map(([v, ic]) => /*#__PURE__*/React.createElement("button", {
    key: v,
    onClick: () => setResultView(v),
    title: v === "list" ? "List view" : "Grid view",
    style: {
      all: "unset",
      cursor: "pointer",
      width: 30,
      height: 26,
      borderRadius: 8,
      display: "grid",
      placeItems: "center",
      background: resultView === v ? "var(--nyan-surface)" : "transparent",
      boxShadow: resultView === v ? "var(--shadow-subtle)" : "none"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: `ph ph-${ic}`,
    style: {
      fontSize: 15,
      color: resultView === v ? "var(--nyan-primary-deep)" : "var(--nyan-text-muted)"
    }
  }))))), resultView === "list" ? /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--nyan-surface)",
      borderRadius: 16,
      border: "1px solid var(--chrome-edge)",
      boxShadow: "var(--shadow-grouped)",
      overflow: "hidden"
    }
  }, results.map((b, i) => /*#__PURE__*/React.createElement(React.Fragment, {
    key: b.id
  }, i > 0 && /*#__PURE__*/React.createElement("div", {
    style: {
      height: "0.5px",
      background: "color-mix(in srgb, var(--nyan-divider) 34%, transparent)",
      margin: "0 12px"
    }
  }), /*#__PURE__*/React.createElement(BookListRow, {
    book: b
  })))) : /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr 1fr",
      gap: "16px 12px"
    }
  }, results.map(b => /*#__PURE__*/React.createElement(BookCard, {
    key: b.id,
    book: b,
    dark: dark
  })))) :
  /*#__PURE__*/
  /* No match */
  React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "center",
      textAlign: "center",
      height: "100%",
      gap: 14,
      paddingBottom: 40
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 80,
      height: 80,
      borderRadius: "50%",
      background: "color-mix(in srgb, var(--nyan-primary) 6%, var(--nyan-surface))",
      border: "0.7px solid color-mix(in srgb, var(--nyan-divider) 18%, transparent)",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-magnifying-glass",
    style: {
      fontSize: 32,
      color: "var(--nyan-primary)",
      opacity: 0.7
    }
  })), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 17px/1.25 var(--font-ui)",
      color: "var(--nyan-text)",
      opacity: 0.84,
      marginBottom: 8
    }
  }, "No books match \"", query.trim(), "\""), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 14px/1.4 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      opacity: 0.74
    }
  }, "Try a different title or author name.")))));
};

/* ──────────────────────────────────────────────────────────────────────
   U10 · BOOK DETAILS PAGE
   ────────────────────────────────────────────────────────────────────── */
const BookDetails = ({
  dark,
  unavailable
}) => /*#__PURE__*/React.createElement(Shell, {
  dark: dark
}, /*#__PURE__*/React.createElement(PageHdr, {
  dark: dark,
  title: "Book Details"
}), /*#__PURE__*/React.createElement("div", {
  style: {
    flex: 1,
    overflowY: "auto",
    padding: "0 16px 32px"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    gap: 10,
    marginBottom: 16
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    width: 120,
    height: 156,
    borderRadius: 16,
    background: unavailable ? "var(--nyan-surface-muted)" : "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))",
    border: unavailable ? "1px solid color-mix(in srgb, var(--error-primary) 22%, transparent)" : "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)",
    display: "grid",
    placeItems: "center",
    position: "relative"
  }
}, unavailable ? /*#__PURE__*/React.createElement("i", {
  className: "ph ph-warning-circle",
  style: {
    fontSize: 40,
    color: "var(--error-primary)"
  }
}) : /*#__PURE__*/React.createElement("i", {
  className: "ph ph-book-open",
  style: {
    fontSize: 44,
    color: "var(--nyan-primary)"
  }
})), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "600 20px/1.3 var(--font-ui)",
    color: "var(--nyan-text)",
    letterSpacing: "-0.1px",
    textAlign: "center"
  }
}, "The Stillwater Diaries"), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 13px/1.3 var(--font-ui)",
    color: "var(--nyan-text-secondary)",
    textAlign: "center"
  }
}, "Matsuno Eri"), /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    gap: 8,
    width: "100%"
  }
}, /*#__PURE__*/React.createElement("button", {
  style: {
    all: "unset",
    cursor: unavailable ? "not-allowed" : "pointer",
    flex: 1,
    height: 50,
    borderRadius: 16,
    background: unavailable ? "color-mix(in srgb, var(--nyan-primary) 42%, var(--nyan-surface-muted))" : "var(--nyan-primary)",
    font: "600 16px/1 var(--font-ui)",
    color: "var(--nyan-surface)",
    display: "grid",
    placeItems: "center",
    opacity: unavailable ? 0.55 : 1
  }
}, unavailable ? "File unavailable" : "Continue Reading"), /*#__PURE__*/React.createElement("button", {
  style: {
    all: "unset",
    cursor: "pointer",
    width: 50,
    height: 50,
    borderRadius: 16,
    background: "var(--nyan-surface)",
    border: "1px solid color-mix(in srgb, var(--nyan-divider) 60%, transparent)",
    display: "grid",
    placeItems: "center",
    flexShrink: 0
  }
}, /*#__PURE__*/React.createElement("i", {
  className: "ph ph-export",
  style: {
    fontSize: 20,
    color: "var(--nyan-text)"
  }
}))), unavailable && /*#__PURE__*/React.createElement("div", {
  style: {
    width: "100%",
    background: "var(--error-bg)",
    borderRadius: 12,
    border: "1px solid color-mix(in srgb, var(--error-accent) 60%, transparent)",
    padding: "10px 12px",
    display: "flex",
    gap: 8,
    alignItems: "flex-start"
  }
}, /*#__PURE__*/React.createElement("i", {
  className: "ph ph-info",
  style: {
    fontSize: 15,
    color: "var(--error-primary)",
    flexShrink: 0,
    marginTop: 1
  }
}), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 13px/1.4 var(--font-ui)",
    color: "var(--error-primary)"
  }
}, "This book seems to have lost its way. The file cannot be found."))), /*#__PURE__*/React.createElement(SectionHdr, {
  label: "Overview"
}), /*#__PURE__*/React.createElement(RowGroup, null, [["Title", "The Stillwater Diaries"], ["Author", "Matsuno Eri"], ["Format", "EPUB"], ["Privacy", "Public Shelf"], ["Reading Progress", "42%"], ["Added", "2025-11-04"]].map(([l, v]) => /*#__PURE__*/React.createElement("div", {
  key: l,
  style: {
    display: "flex",
    alignItems: "center",
    padding: "12px 16px",
    minHeight: 44
  }
}, /*#__PURE__*/React.createElement("span", {
  style: {
    font: "500 13px/1.2 var(--font-ui)",
    color: "var(--nyan-text-secondary)",
    flex: 1
  }
}, l), /*#__PURE__*/React.createElement("span", {
  style: {
    font: "500 14px/1.2 var(--font-ui)",
    color: "var(--nyan-text)",
    textAlign: "right"
  }
}, v)))), /*#__PURE__*/React.createElement("div", {
  style: {
    height: 24
  }
}), /*#__PURE__*/React.createElement(SectionHdr, {
  label: "Source"
}), /*#__PURE__*/React.createElement(RowGroup, null, /*#__PURE__*/React.createElement(ListRow, {
  icon: "folder-open",
  title: "Original Path",
  subtitle: unavailable ? "File not found" : "stillwater_diaries.epub"
}), /*#__PURE__*/React.createElement(ListRow, {
  icon: "copy",
  title: "Copy Path"
}), /*#__PURE__*/React.createElement(ListRow, {
  icon: "clock",
  title: "Last Opened",
  subtitle: "2025-11-28 14:22:09"
})), /*#__PURE__*/React.createElement("div", {
  style: {
    height: 24
  }
}), /*#__PURE__*/React.createElement(SectionHdr, {
  label: "Highlights & Notes"
}), /*#__PURE__*/React.createElement(RowGroup, null, /*#__PURE__*/React.createElement(ListRow, {
  icon: "bookmark",
  title: "Highlights & Notes",
  subtitle: "No highlights yet",
  chevron: true
}))));

/* ──────────────────────────────────────────────────────────────────────
   U11 · IMPORT BOOK SHEET
   `importing` swaps the format-picker body for a live import-progress card:
   per-file status (done / importing / waiting) under an overall counter.
   ────────────────────────────────────────────────────────────────────── */
const IMPORT_QUEUE = [{
  name: "stillwater_diaries.epub",
  fmt: "EPUB",
  state: "done"
}, {
  name: "borrowed_light.txt",
  fmt: "TXT",
  state: "importing"
}, {
  name: "a_long_slope_down.pdf",
  fmt: "PDF",
  state: "waiting"
}];
const ImportFileRow = ({
  file
}) => {
  const lead = file.state === "done" ? /*#__PURE__*/React.createElement("i", {
    className: "ph ph-check-circle",
    style: {
      fontSize: 20,
      color: "var(--nyan-success)"
    }
  }) : file.state === "importing" ? /*#__PURE__*/React.createElement("i", {
    className: "ph ph-circle-notch",
    style: {
      fontSize: 20,
      color: "var(--nyan-primary)",
      animation: "nyan-spin 900ms linear infinite"
    }
  }) : /*#__PURE__*/React.createElement("i", {
    className: "ph ph-circle-dashed",
    style: {
      fontSize: 20,
      color: "var(--nyan-text-muted)",
      opacity: 0.7
    }
  });
  const statusLabel = {
    done: "Added",
    importing: "Importing…",
    waiting: "Waiting"
  }[file.state];
  const statusColor = file.state === "done" ? "var(--nyan-success)" : file.state === "importing" ? "var(--nyan-primary-deep)" : "var(--nyan-text-muted)";
  return /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "11px 16px",
      display: "flex",
      alignItems: "center",
      gap: 12,
      minHeight: 44,
      opacity: file.state === "waiting" ? 0.7 : 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 28,
      display: "grid",
      placeItems: "center",
      flexShrink: 0
    }
  }, lead), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "500 14px/1.2 var(--font-ui)",
      color: "var(--nyan-text)",
      whiteSpace: "nowrap",
      overflow: "hidden",
      textOverflow: "ellipsis"
    }
  }, file.name), file.state === "importing" ? /*#__PURE__*/React.createElement("div", {
    style: {
      height: 3,
      borderRadius: 999,
      background: "color-mix(in srgb, var(--nyan-primary) 14%, var(--nyan-surface-muted))",
      overflow: "hidden",
      marginTop: 7
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: "40%",
      height: "100%",
      borderRadius: 999,
      background: "var(--nyan-primary)",
      animation: "nyan-loadbar 1400ms var(--ease-paper) infinite"
    }
  })) : /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 12px/1.3 var(--font-ui)",
      color: statusColor,
      marginTop: 2
    }
  }, statusLabel)), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 18,
      padding: "0 7px",
      flexShrink: 0,
      borderRadius: 999,
      background: "var(--nyan-surface-muted)",
      border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)",
      display: "flex",
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "600 9px/1 var(--font-ui)",
      color: "var(--nyan-primary-deep)"
    }
  }, file.fmt)));
};
const ImportSheet = ({
  dark,
  emptyShelf,
  importing
}) => {
  const doneCount = IMPORT_QUEUE.filter(f => f.state === "done").length;
  const total = IMPORT_QUEUE.length;
  const pct = Math.round(doneCount / total * 100);
  return /*#__PURE__*/React.createElement(Shell, {
    dark: dark
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      background: "var(--scrim)",
      backdropFilter: "blur(var(--scrim-blur))",
      WebkitBackdropFilter: "blur(var(--scrim-blur))"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: "var(--inset)",
      right: "var(--inset)",
      bottom: "var(--inset)",
      background: "var(--nyan-surface)",
      border: "1px solid var(--chrome-edge)",
      borderRadius: "var(--r-sheet)",
      boxShadow: "var(--shadow-light-card)",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      paddingTop: 10,
      display: "flex",
      justifyContent: "center"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 40,
      height: 5,
      borderRadius: 999,
      background: "var(--grabber)"
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "12px 20px 24px",
      display: "flex",
      flexDirection: "column",
      gap: 14
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 18px/1.2 var(--font-ui)",
      color: "var(--nyan-text)",
      letterSpacing: "-0.1px",
      marginBottom: 4
    }
  }, importing ? "Importing Books" : "Import Books"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 13px/1.38 var(--font-ui)",
      color: "var(--nyan-text-secondary)"
    }
  }, importing ? "Adding to your shelf. Keep the app open." : emptyShelf ? "Add your first book to get started." : "Add more books to your shelf.")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 8,
      height: 34,
      padding: "0 12px",
      background: "color-mix(in srgb, var(--nyan-primary) 8%, transparent)",
      border: "1px solid color-mix(in srgb, var(--nyan-divider) 45%, transparent)",
      borderRadius: 12,
      alignSelf: "flex-start"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-books",
    style: {
      fontSize: 15,
      color: "var(--nyan-primary)"
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "600 13px/1 var(--font-ui)",
      color: "var(--nyan-primary)"
    }
  }, "Public Shelf")), importing ? /*#__PURE__*/React.createElement(RowGroup, null, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "14px 16px 16px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "baseline",
      justifyContent: "space-between",
      marginBottom: 10
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "500 13px/1.2 var(--font-ui)",
      color: "var(--nyan-text-secondary)"
    }
  }, "Importing ", total, " files"), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "500 13px/1 var(--font-mono)",
      color: "var(--nyan-primary-deep)"
    }
  }, doneCount, " / ", total)), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 6,
      borderRadius: 999,
      background: "color-mix(in srgb, var(--nyan-primary) 14%, var(--nyan-surface-muted))",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: `${pct}%`,
      height: "100%",
      borderRadius: 999,
      background: "var(--nyan-primary)",
      transition: "width 320ms var(--ease-paper)"
    }
  }))), IMPORT_QUEUE.map((f, i) => /*#__PURE__*/React.createElement(ImportFileRow, {
    key: i,
    file: f
  }))) : /*#__PURE__*/React.createElement(RowGroup, null, /*#__PURE__*/React.createElement(ListRow, {
    icon: "file",
    title: "Import Files",
    subtitle: "Browse and open .txt, .epub or .pdf",
    chevron: true
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      height: "0.5px",
      background: "color-mix(in srgb, var(--nyan-divider) 34%, transparent)",
      margin: "0 16px"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "12px 16px 16px",
      display: "flex",
      gap: 12,
      alignItems: "flex-start"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 44,
      height: 44,
      borderRadius: 12,
      background: "color-mix(in srgb, var(--nyan-primary) 10%, var(--nyan-surface-muted))",
      flexShrink: 0,
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-book",
    style: {
      fontSize: 20,
      color: "var(--nyan-primary)"
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "500 15px/1.2 var(--font-ui)",
      color: "var(--nyan-text)",
      marginBottom: 4
    }
  }, "Supported Formats"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 13px/1.3 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      marginBottom: 12
    }
  }, "Plain text, e-book, and document files."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 8,
      flexWrap: "wrap"
    }
  }, ["TXT", "EPUB", "PDF"].map(f => /*#__PURE__*/React.createElement("div", {
    key: f,
    style: {
      height: 30,
      padding: "0 12px",
      borderRadius: 12,
      background: "color-mix(in srgb, var(--nyan-primary) 10%, var(--nyan-surface-muted))",
      border: "1px solid color-mix(in srgb, var(--nyan-divider) 50%, transparent)",
      display: "flex",
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "600 13px/1 var(--font-ui)",
      color: "var(--nyan-primary)"
    }
  }, f)))))))))));
};

/* ──────────────────────────────────────────────────────────────────────
   U12 · BOOKMARK LIST PAGE
   ────────────────────────────────────────────────────────────────────── */
const BOOKMARKS = [{
  id: 1,
  label: "Bookmark 1",
  excerpt: "She would sometimes say that of all the noises in the city, only the bell and the rain felt honest.",
  note: "Opens and closes the chapter — the bell is the thesis.",
  date: "2025.11.04"
}, {
  id: 2,
  label: "Bookmark 2",
  excerpt: "He set the lacquer cup down on the low table and looked, again, at the calligraphy.",
  note: null,
  date: "2025.11.04"
}, {
  id: 3,
  label: "Bookmark 3",
  excerpt: "Some things are better held at arm's length, like a wet umbrella indoors.",
  note: "Perfect sentence to quote.",
  date: "2025.11.06"
}];

/* Shared "mid-deletion" row — a card collapsed to a calm Removing… strip with a
   spinner. Used by both the Bookmark and Notes deleting states. */
const RemovingRow = ({
  label,
  excerpt
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    borderRadius: 16,
    marginBottom: 8,
    background: "var(--nyan-surface)",
    border: "0.72px solid color-mix(in srgb, var(--nyan-divider) 36%, transparent)",
    padding: "14px",
    display: "flex",
    alignItems: "center",
    gap: 11,
    opacity: 0.92
  }
}, /*#__PURE__*/React.createElement("i", {
  className: "ph ph-circle-notch",
  style: {
    fontSize: 20,
    color: "var(--error-primary)",
    animation: "nyan-spin 900ms linear infinite",
    flexShrink: 0
  }
}), /*#__PURE__*/React.createElement("div", {
  style: {
    flex: 1,
    minWidth: 0
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    font: "600 13px/1.2 var(--font-ui)",
    color: "var(--nyan-text-secondary)"
  }
}, label), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 13px/1.35 var(--font-ui)",
    color: "var(--nyan-text-muted)",
    whiteSpace: "nowrap",
    overflow: "hidden",
    textOverflow: "ellipsis",
    marginTop: 2,
    textDecoration: "line-through",
    opacity: 0.7
  }
}, excerpt)));
const BookmarkCard = ({
  bm,
  revealed,
  onReveal
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    position: "relative",
    borderRadius: 16,
    overflow: "hidden",
    marginBottom: 8
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    position: "absolute",
    right: 0,
    top: 0,
    bottom: 0,
    width: 104,
    background: "linear-gradient(to right, transparent, color-mix(in srgb, var(--error-bg) 60%, var(--nyan-surface)))",
    borderRadius: "0 16px 16px 0",
    border: "0.5px solid color-mix(in srgb, var(--error-accent) 14%, transparent)",
    display: "flex",
    alignItems: "center",
    justifyContent: "flex-end",
    padding: "0 12px",
    gap: 6
  }
}, /*#__PURE__*/React.createElement("span", {
  style: {
    font: "600 12px/1 var(--font-ui)",
    color: "var(--error-primary)",
    opacity: 0.62
  }
}, "Delete"), /*#__PURE__*/React.createElement("i", {
  className: "ph ph-trash",
  style: {
    fontSize: 20,
    color: "var(--error-primary)",
    opacity: 0.72
  }
})), /*#__PURE__*/React.createElement("div", {
  style: {
    background: "var(--nyan-surface)",
    borderRadius: 16,
    border: "0.72px solid color-mix(in srgb, var(--nyan-divider) 36%, transparent)",
    padding: "12px 14px",
    position: "relative",
    transform: revealed ? "translateX(-80px)" : "none",
    transition: "transform 220ms ease"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    font: "500 11px/1.2 var(--font-ui)",
    color: "var(--nyan-primary-deep)",
    marginBottom: 6,
    letterSpacing: "0.2px",
    textTransform: "uppercase",
    fontSize: 10.5
  }
}, bm.label), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 14px/1.45 var(--font-ui)",
    color: "var(--nyan-text)",
    display: "-webkit-box",
    WebkitLineClamp: 2,
    WebkitBoxOrient: "vertical",
    overflow: "hidden",
    marginBottom: bm.note ? 8 : 0
  }
}, bm.excerpt), bm.note && /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    gap: 7,
    alignItems: "flex-start",
    marginTop: 6,
    paddingTop: 6,
    borderTop: "0.5px solid color-mix(in srgb, var(--nyan-divider) 34%, transparent)"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    height: 20,
    padding: "0 7px",
    borderRadius: 999,
    background: "color-mix(in srgb, var(--nyan-primary) 10%, var(--nyan-surface-muted))",
    border: "0.5px solid color-mix(in srgb, var(--nyan-primary) 18%, transparent)",
    display: "flex",
    alignItems: "center",
    flexShrink: 0
  }
}, /*#__PURE__*/React.createElement("span", {
  style: {
    font: "500 10px/1 var(--font-ui)",
    color: "var(--nyan-primary-deep)"
  }
}, "Note")), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 13px/1.38 var(--font-ui)",
    color: "var(--nyan-text-secondary)",
    flex: 1
  }
}, bm.note))));
const BookmarkList = ({
  dark,
  empty,
  phase
}) => {
  const count = empty ? 0 : phase === "deleted" ? BOOKMARKS.length - 1 : BOOKMARKS.length;
  return /*#__PURE__*/React.createElement(Shell, {
    dark: dark
  }, /*#__PURE__*/React.createElement(PageHdr, {
    dark: dark,
    title: `Bookmarks (${count})`,
    subtitle: "The Stillwater Diaries"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      flex: 1,
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      overflowY: "auto",
      padding: "4px 16px 24px"
    }
  }, empty ? /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "center",
      textAlign: "center",
      height: "100%",
      gap: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 84,
      height: 84,
      borderRadius: "50%",
      background: "color-mix(in srgb, var(--nyan-primary) 6%, var(--nyan-surface))",
      border: "0.7px solid color-mix(in srgb, var(--nyan-divider) 18%, transparent)",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-bookmark-simple",
    style: {
      fontSize: 36,
      color: "var(--nyan-primary)",
      opacity: 0.78
    }
  })), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 18px/1.25 var(--font-ui)",
      color: "var(--nyan-text)",
      opacity: 0.84,
      marginBottom: 8
    }
  }, "No bookmarks yet"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 14px/1.4 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      opacity: 0.74,
      marginBottom: 10
    }
  }, "Passages worth returning to will gather here."), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 13px/1.38 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      opacity: 0.62
    }
  }, "Tap the bookmark while reading to save one."))) : /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--nyan-surface)",
      borderRadius: 16,
      border: "0.6px solid color-mix(in srgb, var(--nyan-divider) 22%, transparent)",
      padding: "12px",
      display: "flex",
      gap: 12,
      alignItems: "center",
      marginBottom: 16,
      boxShadow: "var(--shadow-subtle)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 32,
      height: 32,
      borderRadius: 12,
      background: "color-mix(in srgb, var(--nyan-primary) 8%, var(--nyan-surface-muted))",
      display: "grid",
      placeItems: "center",
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-bookmarks",
    style: {
      fontSize: 16,
      color: "var(--nyan-primary)",
      opacity: 0.84
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 14px/1.1 var(--font-ui)",
      color: "var(--nyan-text)",
      opacity: 0.85
    }
  }, "Your bookmarks"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 12px/1.3 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      marginTop: 3,
      opacity: 0.74
    }
  }, phase === "reveal" ? "Release to delete, or tap the card to cancel." : "Tap to jump back. Swipe left to delete."))), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 11px/1 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      opacity: 0.56,
      letterSpacing: "0.3px",
      padding: "0 4px",
      marginBottom: 8
    }
  }, "2025.11.04"), phase === "deleted" ? /*#__PURE__*/React.createElement(BookmarkCard, {
    bm: BOOKMARKS[1]
  }) : /*#__PURE__*/React.createElement(React.Fragment, null, phase === "removing" ? /*#__PURE__*/React.createElement(RemovingRow, {
    label: "Removing bookmark\u2026",
    excerpt: BOOKMARKS[0].excerpt
  }) : /*#__PURE__*/React.createElement(BookmarkCard, {
    bm: BOOKMARKS[0],
    revealed: phase === "reveal"
  }), /*#__PURE__*/React.createElement(BookmarkCard, {
    bm: BOOKMARKS[1]
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 4
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 11px/1 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      opacity: 0.56,
      letterSpacing: "0.3px",
      padding: "0 4px",
      marginBottom: 8
    }
  }, "2025.11.06"), /*#__PURE__*/React.createElement(BookmarkCard, {
    bm: BOOKMARKS[2]
  }))), phase === "deleted" && /*#__PURE__*/React.createElement(NyanResponse, {
    placement: "bottom",
    status: "success",
    title: "Bookmark deleted",
    action: {
      label: "Undo"
    }
  })));
};

/* ──────────────────────────────────────────────────────────────────────
   U13 · NOTES & HIGHLIGHTS LIST PAGE
   ────────────────────────────────────────────────────────────────────── */
const HL_COLORS = ["#D8C06B", "#A9C08E", "#7FABAC", "#CDA2A8", "#D8C06B"];
const HIGHLIGHTS = [{
  id: 1,
  label: "Highlight 1",
  excerpt: "only the bell and the rain felt honest",
  note: "Opens and closes the chapter — the bell is the thesis.",
  color: "#D8C06B",
  ink: "#B89A2C",
  para: "Paragraph 4"
}, {
  id: 2,
  label: "Highlight 2",
  excerpt: "He set the lacquer cup down on the low table and looked, again, at the calligraphy hanging in the alcove.",
  note: null,
  color: "#9EC5E8",
  ink: "#2E6B96",
  para: "Paragraph 12"
}, {
  id: 3,
  label: "Highlight 3",
  excerpt: "Some things are better held at arm's length, like a wet umbrella indoors.",
  note: "Perfect sentence to quote.",
  color: "#A8D18D",
  ink: "#4E8A2D",
  para: "Paragraph 19"
}];
const HighlightCard = ({
  hl,
  revealed
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    position: "relative",
    borderRadius: 16,
    overflow: "hidden",
    marginBottom: 8
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    position: "absolute",
    right: 0,
    top: 0,
    bottom: 0,
    width: 104,
    background: "linear-gradient(to right, transparent, color-mix(in srgb, var(--error-bg) 60%, var(--nyan-surface)))",
    borderRadius: "0 16px 16px 0",
    border: "0.5px solid color-mix(in srgb, var(--error-accent) 14%, transparent)",
    display: "flex",
    alignItems: "center",
    justifyContent: "flex-end",
    padding: "0 12px",
    gap: 6
  }
}, /*#__PURE__*/React.createElement("span", {
  style: {
    font: "600 12px/1 var(--font-ui)",
    color: "var(--error-primary)",
    opacity: 0.62
  }
}, "Delete"), /*#__PURE__*/React.createElement("i", {
  className: "ph ph-trash",
  style: {
    fontSize: 20,
    color: "var(--error-primary)",
    opacity: 0.72
  }
})), /*#__PURE__*/React.createElement("div", {
  style: {
    background: "var(--nyan-surface)",
    borderRadius: 16,
    border: "0.72px solid color-mix(in srgb, var(--nyan-divider) 36%, transparent)",
    padding: "12px 14px",
    display: "flex",
    gap: 10,
    position: "relative",
    transform: revealed ? "translateX(-80px)" : "none",
    transition: "transform 220ms ease"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    width: 3,
    borderRadius: 99,
    background: hl.color,
    flexShrink: 0,
    alignSelf: "stretch"
  }
}), /*#__PURE__*/React.createElement("div", {
  style: {
    flex: 1,
    minWidth: 0
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 5
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    gap: 6,
    alignItems: "center"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    width: 14,
    height: 14,
    borderRadius: "50%",
    background: hl.color,
    border: "1px solid color-mix(in srgb, var(--nyan-surface) 80%, transparent)"
  }
}), /*#__PURE__*/React.createElement("span", {
  style: {
    font: "500 11px/1 var(--font-ui)",
    color: `color-mix(in srgb, ${hl.ink} 85%, var(--nyan-text))`,
    fontSize: 10.5
  }
}, hl.label)), /*#__PURE__*/React.createElement("span", {
  style: {
    font: "400 11px/1 var(--font-ui)",
    color: "var(--nyan-text-muted)",
    fontSize: 10.5
  }
}, hl.para)), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 14px/1.45 var(--font-ui)",
    color: "var(--nyan-text)",
    display: "-webkit-box",
    WebkitLineClamp: 2,
    WebkitBoxOrient: "vertical",
    overflow: "hidden",
    marginBottom: hl.note ? 8 : 0
  }
}, hl.excerpt), hl.note && /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    gap: 7,
    alignItems: "flex-start",
    paddingTop: 6,
    borderTop: "0.5px solid color-mix(in srgb, var(--nyan-divider) 34%, transparent)"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    height: 20,
    padding: "0 7px",
    borderRadius: 999,
    background: "color-mix(in srgb, var(--nyan-primary) 10%, var(--nyan-surface-muted))",
    border: "0.5px solid color-mix(in srgb, var(--nyan-primary) 18%, transparent)",
    display: "flex",
    alignItems: "center",
    flexShrink: 0
  }
}, /*#__PURE__*/React.createElement("span", {
  style: {
    font: "500 10px/1 var(--font-ui)",
    color: "var(--nyan-primary-deep)"
  }
}, "Note")), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 13px/1.38 var(--font-ui)",
    color: "var(--nyan-text-secondary)"
  }
}, hl.note)))));
const NotesList = ({
  dark,
  empty,
  phase
}) => {
  const count = empty ? 0 : phase === "deleted" ? HIGHLIGHTS.length - 1 : HIGHLIGHTS.length;
  const rows = phase === "deleted" ? HIGHLIGHTS.slice(1) : HIGHLIGHTS;
  return /*#__PURE__*/React.createElement(Shell, {
    dark: dark
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      top: 0,
      left: 0,
      right: 0,
      height: 160,
      background: "linear-gradient(to bottom, color-mix(in srgb, var(--nyan-primary) 5%, var(--nyan-bg)), var(--nyan-bg))",
      pointerEvents: "none",
      zIndex: 0
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      zIndex: 1,
      display: "flex",
      flexDirection: "column",
      height: "100%"
    }
  }, /*#__PURE__*/React.createElement(PageHdr, {
    dark: dark,
    title: `Highlights & Notes (${count})`,
    subtitle: "The Stillwater Diaries"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      flex: 1,
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      overflowY: "auto",
      padding: "4px 16px 24px"
    }
  }, empty ? /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "center",
      textAlign: "center",
      height: "100%",
      gap: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 84,
      height: 84,
      borderRadius: "50%",
      background: "color-mix(in srgb, var(--nyan-primary) 6%, var(--nyan-surface))",
      border: "0.7px solid color-mix(in srgb, var(--nyan-divider) 18%, transparent)",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-highlighter-circle",
    style: {
      fontSize: 36,
      color: "var(--nyan-primary)",
      opacity: 0.78
    }
  })), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 18px/1.25 var(--font-ui)",
      color: "var(--nyan-text)",
      opacity: 0.84,
      marginBottom: 8
    }
  }, "No reading notes yet"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 14px/1.4 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      opacity: 0.74,
      marginBottom: 10
    }
  }, "Lines worth returning to will gather here."), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 13px/1.38 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      opacity: 0.62
    }
  }, "Long-press while reading to save a highlight or note."))) : /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      background: "color-mix(in srgb, var(--nyan-primary) 3.5%, var(--nyan-surface))",
      borderRadius: 16,
      border: "0.6px solid color-mix(in srgb, var(--nyan-divider) 16%, transparent)",
      padding: "12px",
      display: "flex",
      gap: 12,
      alignItems: "center",
      marginBottom: 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 32,
      height: 32,
      borderRadius: 12,
      background: "color-mix(in srgb, var(--nyan-primary) 8%, var(--nyan-surface-muted))",
      display: "grid",
      placeItems: "center",
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-pencil-line",
    style: {
      fontSize: 15,
      color: "var(--nyan-primary)",
      opacity: 0.88
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 15px/1.1 var(--font-ui)",
      color: "var(--nyan-text)",
      opacity: 0.86
    }
  }, "Reading notes"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 12.5px/1.3 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      marginTop: 3,
      opacity: 0.72
    }
  }, phase === "reveal" ? "Release to delete, or tap the card to cancel." : "Tap to return, long-press to edit, swipe left to delete."))), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 11px/1 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      opacity: 0.56,
      letterSpacing: "0.9px",
      padding: "8px 4px 6px",
      textTransform: "uppercase",
      fontSize: 10.5
    }
  }, "2025.11.06"), phase === "removing" && /*#__PURE__*/React.createElement(RemovingRow, {
    label: "Removing highlight\u2026",
    excerpt: HIGHLIGHTS[0].excerpt
  }), rows.map((hl, i) => /*#__PURE__*/React.createElement(HighlightCard, {
    key: hl.id,
    hl: hl,
    revealed: phase === "reveal" && i === 0
  })))), phase === "deleted" && /*#__PURE__*/React.createElement(NyanResponse, {
    placement: "bottom",
    status: "success",
    title: "Highlight deleted",
    action: {
      label: "Undo"
    }
  }))));
};

/* ──────────────────────────────────────────────────────────────────────
   DESIGN CANVAS
   ────────────────────────────────────────────────────────────────────── */

/* ──────────────────────────────────────────────────────────────────────
   U9b · BOOKSHELF SELECT & DELETE (MULTI-SELECT EDIT MODE)
   Entered via long-press / “Select” — the Shelf Toolbar becomes a selection bar
   (Cancel · N selected · Select all), every cover/row gains a check, and a
   floating action bar offers Make Private / Export / Delete. Deleting routes
   through a destructive confirm sheet → a Deleting… progress response → an
   undoable “deleted” response. Works in grid + list, Cream + Sumi.
   ────────────────────────────────────────────────────────────────────── */
const SELECT_IDS = [0, 2];
const SelectCheck = ({
  on,
  size = 24
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    width: size,
    height: size,
    borderRadius: "50%",
    flexShrink: 0,
    display: "grid",
    placeItems: "center",
    background: on ? "var(--nyan-select-fill)" : "color-mix(in srgb, var(--nyan-surface) 76%, transparent)",
    border: on ? "1.5px solid var(--nyan-select-fill)" : "1.5px solid color-mix(in srgb, var(--nyan-text) 30%, transparent)",
    boxShadow: on ? "0 1px 4px color-mix(in srgb, var(--nyan-select-fill) 40%, transparent)" : "0 1px 3px rgba(0,0,0,.12)",
    backdropFilter: "blur(3px)",
    WebkitBackdropFilter: "blur(3px)",
    transition: "all 140ms ease"
  }
}, on && /*#__PURE__*/React.createElement("svg", {
  width: Math.round(size * 0.62),
  height: Math.round(size * 0.62),
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "#FFFFFF",
  strokeWidth: "3.4",
  strokeLinecap: "round",
  strokeLinejoin: "round",
  style: {
    display: "block"
  }
}, /*#__PURE__*/React.createElement("path", {
  d: "M5 12.5 L10 17.5 L19 7"
})));
const SelectBookCard = ({
  book,
  selected
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    flexDirection: "column",
    gap: 6,
    cursor: "pointer"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    position: "relative",
    width: "100%",
    aspectRatio: "120/156",
    borderRadius: 12,
    background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))",
    border: selected ? "2px solid var(--nyan-primary)" : "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)",
    boxShadow: selected ? "0 0 0 3px color-mix(in srgb, var(--nyan-primary) 16%, transparent)" : "none",
    display: "grid",
    placeItems: "center",
    overflow: "hidden",
    transition: "box-shadow 140ms ease, border-color 140ms ease"
  }
}, /*#__PURE__*/React.createElement("i", {
  className: "ph ph-book-open",
  style: {
    fontSize: 26,
    color: "var(--nyan-primary)"
  }
}), /*#__PURE__*/React.createElement("div", {
  style: {
    position: "absolute",
    top: 6,
    right: 6,
    height: 17,
    padding: "0 6px",
    borderRadius: 999,
    background: "color-mix(in srgb, var(--nyan-surface) 88%, transparent)",
    border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)",
    display: "flex",
    alignItems: "center"
  }
}, /*#__PURE__*/React.createElement("span", {
  style: {
    font: "600 9px/1 var(--font-ui)",
    color: "var(--nyan-primary-deep)"
  }
}, book.fmt)), selected && /*#__PURE__*/React.createElement("div", {
  style: {
    position: "absolute",
    inset: 0,
    background: "color-mix(in srgb, var(--nyan-primary) 12%, transparent)"
  }
}), /*#__PURE__*/React.createElement("div", {
  style: {
    position: "absolute",
    top: 7,
    left: 7
  }
}, /*#__PURE__*/React.createElement(SelectCheck, {
  on: selected
}))), book.pct > 0 && /*#__PURE__*/React.createElement("div", {
  style: {
    height: 3,
    borderRadius: 999,
    background: "color-mix(in srgb, var(--nyan-primary) 16%, var(--nyan-surface))",
    overflow: "hidden"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    width: `${book.pct}%`,
    height: "100%",
    borderRadius: 999,
    background: "var(--nyan-primary)"
  }
})), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
  style: {
    font: "600 12.5px/1.25 var(--font-ui)",
    color: "var(--nyan-text)",
    overflow: "hidden",
    display: "-webkit-box",
    WebkitLineClamp: 2,
    WebkitBoxOrient: "vertical"
  }
}, book.title), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 11px/1.3 var(--font-ui)",
    color: "var(--nyan-text-muted)",
    marginTop: 2,
    whiteSpace: "nowrap",
    overflow: "hidden",
    textOverflow: "ellipsis"
  }
}, book.author)));
const SelectBookListRow = ({
  book,
  selected
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    position: "relative",
    display: "flex",
    alignItems: "center",
    gap: 12,
    padding: "10px 12px",
    minHeight: 44,
    cursor: "pointer",
    background: selected ? "color-mix(in srgb, var(--nyan-primary) 7%, transparent)" : "transparent",
    transition: "background 140ms ease"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    position: "relative",
    width: 44,
    height: 58,
    flexShrink: 0
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    width: "100%",
    height: "100%",
    borderRadius: "var(--r-chip)",
    background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))",
    border: selected ? "1.5px solid var(--nyan-primary)" : "0.5px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)",
    display: "grid",
    placeItems: "center"
  }
}, /*#__PURE__*/React.createElement("i", {
  className: "ph ph-book-open",
  style: {
    fontSize: 20,
    color: "var(--nyan-primary)"
  }
})), /*#__PURE__*/React.createElement("div", {
  style: {
    position: "absolute",
    top: 4,
    left: 4
  }
}, /*#__PURE__*/React.createElement(SelectCheck, {
  on: selected,
  size: 20
}))), /*#__PURE__*/React.createElement("div", {
  style: {
    flex: 1,
    minWidth: 0
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    font: "600 14px/1.25 var(--font-ui)",
    color: "var(--nyan-text)",
    whiteSpace: "nowrap",
    overflow: "hidden",
    textOverflow: "ellipsis"
  }
}, book.title), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 12px/1.3 var(--font-ui)",
    color: "var(--nyan-text-muted)",
    marginTop: 1,
    whiteSpace: "nowrap",
    overflow: "hidden",
    textOverflow: "ellipsis"
  }
}, book.author)), /*#__PURE__*/React.createElement("div", {
  style: {
    height: 18,
    padding: "0 7px",
    flexShrink: 0,
    borderRadius: 999,
    background: "var(--nyan-surface-muted)",
    border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)",
    display: "flex",
    alignItems: "center"
  }
}, /*#__PURE__*/React.createElement("span", {
  style: {
    font: "600 9px/1 var(--font-ui)",
    color: "var(--nyan-primary-deep)"
  }
}, book.fmt)));
const SelectionHeader = ({
  count
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    padding: "14px 8px 8px",
    display: "flex",
    alignItems: "center",
    gap: 4,
    flexShrink: 0
  }
}, /*#__PURE__*/React.createElement("button", {
  style: {
    all: "unset",
    cursor: "pointer",
    width: 40,
    height: 40,
    borderRadius: "var(--r-control)",
    display: "grid",
    placeItems: "center",
    flexShrink: 0
  }
}, /*#__PURE__*/React.createElement("i", {
  className: "ph ph-x",
  style: {
    fontSize: 22,
    color: "var(--nyan-text)"
  }
})), /*#__PURE__*/React.createElement("div", {
  style: {
    flex: 1,
    minWidth: 0,
    font: "600 18px/1.15 var(--font-ui)",
    color: "var(--nyan-text)",
    letterSpacing: "-0.2px"
  }
}, count, " selected"), /*#__PURE__*/React.createElement("button", {
  style: {
    all: "unset",
    cursor: "pointer",
    height: 36,
    padding: "0 12px",
    borderRadius: "var(--r-chip)",
    display: "flex",
    alignItems: "center",
    gap: 6,
    font: "600 13px/1 var(--font-ui)",
    color: "var(--nyan-primary-deep)",
    background: "color-mix(in srgb, var(--nyan-primary) 10%, transparent)"
  }
}, /*#__PURE__*/React.createElement("i", {
  className: "ph ph-list-checks",
  style: {
    fontSize: 16
  }
}), "Select all"));
const SelectActionBar = ({
  count
}) => {
  const actions = [{
    icon: "lock-simple",
    label: "Make Private"
  }, {
    icon: "export",
    label: "Export"
  }, {
    icon: "trash",
    label: "Delete",
    danger: true
  }];
  const disabled = count === 0;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: "var(--inset)",
      right: "var(--inset)",
      bottom: "var(--inset)",
      background: "var(--nyan-surface)",
      border: "1px solid var(--chrome-edge)",
      borderRadius: "var(--r-dock)",
      boxShadow: "var(--shadow-light-card)",
      padding: "7px 6px",
      display: "flex",
      opacity: disabled ? 0.5 : 1,
      zIndex: 40
    }
  }, actions.map((a, i) => /*#__PURE__*/React.createElement(React.Fragment, {
    key: a.label
  }, i > 0 && /*#__PURE__*/React.createElement("div", {
    style: {
      width: "0.5px",
      alignSelf: "stretch",
      margin: "8px 0",
      background: "color-mix(in srgb, var(--nyan-divider) 40%, transparent)"
    }
  }), /*#__PURE__*/React.createElement("button", {
    style: {
      all: "unset",
      cursor: "pointer",
      flex: 1,
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      gap: 5,
      padding: "8px 4px",
      borderRadius: 12
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: `ph ph-${a.icon}`,
    style: {
      fontSize: 22,
      color: a.danger ? "var(--error-primary)" : "var(--nyan-primary-deep)"
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "500 11px/1 var(--font-ui)",
      color: a.danger ? "var(--error-primary)" : "var(--nyan-text-secondary)"
    }
  }, a.label)))));
};
const DeleteConfirmSheet = ({
  count
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    position: "absolute",
    inset: 0,
    zIndex: 50
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    position: "absolute",
    inset: 0,
    background: "var(--scrim)",
    backdropFilter: "blur(var(--scrim-blur))",
    WebkitBackdropFilter: "blur(var(--scrim-blur))",
    animation: "nyanFade 220ms ease-out"
  }
}), /*#__PURE__*/React.createElement("div", {
  style: {
    position: "absolute",
    left: "var(--inset)",
    right: "var(--inset)",
    bottom: "var(--inset)",
    background: "var(--nyan-surface)",
    border: "1px solid var(--chrome-edge)",
    borderRadius: "var(--r-sheet)",
    boxShadow: "var(--shadow-light-card)",
    overflow: "hidden",
    animation: "nyanSlideUp 280ms cubic-bezier(0.33,0.9,0.36,1)"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    padding: "24px 20px 18px",
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    textAlign: "center"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    width: 56,
    height: 56,
    borderRadius: "var(--r-card-nested)",
    background: "var(--error-bg)",
    border: "0.7px solid color-mix(in srgb, var(--error-primary) 22%, transparent)",
    display: "grid",
    placeItems: "center",
    marginBottom: 14
  }
}, /*#__PURE__*/React.createElement("i", {
  className: "ph ph-trash",
  style: {
    fontSize: 26,
    color: "var(--error-primary)"
  }
})), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "600 18px/1.25 var(--font-ui)",
    color: "var(--nyan-text)",
    marginBottom: 8
  }
}, "Delete ", count, " books?"), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 13.5px/1.5 var(--font-ui)",
    color: "var(--nyan-text-secondary)",
    maxWidth: 282,
    textWrap: "pretty"
  }
}, "Their reading progress, bookmarks and notes are removed too. The source files on your device are kept.")), /*#__PURE__*/React.createElement("div", {
  style: {
    padding: "0 16px 16px",
    display: "flex",
    flexDirection: "column",
    gap: 10
  }
}, /*#__PURE__*/React.createElement("button", {
  style: {
    all: "unset",
    cursor: "pointer",
    boxSizing: "border-box",
    height: 50,
    borderRadius: 16,
    background: "var(--error-primary)",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    gap: 8
  }
}, /*#__PURE__*/React.createElement("i", {
  className: "ph ph-trash",
  style: {
    fontSize: 18,
    color: "var(--nyan-surface)"
  }
}), /*#__PURE__*/React.createElement("span", {
  style: {
    font: "600 15px/1 var(--font-ui)",
    color: "var(--nyan-surface)"
  }
}, "Delete ", count, " books")), /*#__PURE__*/React.createElement("button", {
  style: {
    all: "unset",
    cursor: "pointer",
    boxSizing: "border-box",
    height: 50,
    borderRadius: 16,
    background: "var(--nyan-surface-muted)",
    border: "1px solid var(--nyan-divider)",
    display: "grid",
    placeItems: "center",
    font: "600 15px/1 var(--font-ui)",
    color: "var(--nyan-text)"
  }
}, "Cancel"))));
const BookshelfManage = ({
  dark,
  view = "grid",
  phase = "select"
}) => {
  const selecting = phase === "select" || phase === "confirm" || phase === "deleting";
  const items = BOOKS.concat(BOOKS).slice(0, 6).map((b, i) => ({
    key: i,
    book: b,
    selected: SELECT_IDS.includes(i)
  }));
  const visible = phase === "deleted" ? items.filter(it => !it.selected) : items;
  const count = SELECT_IDS.length;
  return /*#__PURE__*/React.createElement(Shell, {
    dark: dark
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      flex: 1,
      display: "flex",
      flexDirection: "column",
      minHeight: 0
    }
  }, phase === "deleted" ? /*#__PURE__*/React.createElement(ShelfToolbar, {
    view: view,
    sort: false,
    onSearch: () => {}
  }) : /*#__PURE__*/React.createElement(SelectionHeader, {
    count: count
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: "auto",
      padding: "6px 16px 104px"
    }
  }, view === "grid" ? /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr 1fr",
      gap: "16px 12px"
    }
  }, visible.map(it => /*#__PURE__*/React.createElement("div", {
    key: it.key,
    style: {
      opacity: phase === "deleting" && it.selected ? 0.4 : 1,
      transition: "opacity 220ms ease"
    }
  }, /*#__PURE__*/React.createElement(SelectBookCard, {
    book: it.book,
    selected: selecting && it.selected
  })))) : /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--nyan-surface)",
      borderRadius: 16,
      border: "1px solid var(--chrome-edge)",
      boxShadow: "var(--shadow-grouped)",
      overflow: "hidden"
    }
  }, visible.map((it, idx) => /*#__PURE__*/React.createElement(React.Fragment, {
    key: it.key
  }, idx > 0 && /*#__PURE__*/React.createElement("div", {
    style: {
      height: "0.5px",
      background: "color-mix(in srgb, var(--nyan-divider) 34%, transparent)",
      margin: "0 12px"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      opacity: phase === "deleting" && it.selected ? 0.4 : 1,
      transition: "opacity 220ms ease"
    }
  }, /*#__PURE__*/React.createElement(SelectBookListRow, {
    book: it.book,
    selected: selecting && it.selected
  })))))), phase === "select" && /*#__PURE__*/React.createElement(SelectActionBar, {
    count: count
  }), phase === "confirm" && /*#__PURE__*/React.createElement(DeleteConfirmSheet, {
    count: count
  }), phase === "deleting" && /*#__PURE__*/React.createElement(NyanResponse, {
    placement: "bottom",
    status: "loading",
    title: `Deleting ${count} books…`
  }), phase === "deleted" && /*#__PURE__*/React.createElement(NyanResponse, {
    placement: "bottom",
    status: "success",
    title: `${count} books deleted`,
    action: {
      label: "Undo"
    }
  })));
};

/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, {
  BOOKS,
  BookCard,
  ContinueCard,
  BookListRow,
  BookshelfHome,
  SEARCH_RECENT,
  SEARCH_SUGGEST,
  SearchField,
  SearchChip,
  BookshelfSearch,
  BookDetails,
  IMPORT_QUEUE,
  ImportFileRow,
  ImportSheet,
  RemovingRow,
  BOOKMARKS,
  BookmarkCard,
  BookmarkList,
  HL_COLORS,
  HIGHLIGHTS,
  HighlightCard,
  NotesList,
  SELECT_IDS,
  SelectCheck,
  SelectBookCard,
  SelectBookListRow,
  SelectionHeader,
  SelectActionBar,
  DeleteConfirmSheet,
  BookshelfManage
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "screens/bundle3.jsx", error: String((e && e.message) || e) }); }

// screens/bundle4.jsx
try { (() => {
/* ============================================================================
   Nyan Read — Screens: U14 Settings · U15 Reader Progress · U16 Privacy PIN · U17 Read Aloud · U18 Admin · U19 Shelf Toolbar
   ----------------------------------------------------------------------------
   Full-screen compositions assembled from components/*. Extracted verbatim from
   the bundle gallery so Claude Code can read/edit one screen without the HTML.
   Self-exports to window; the bundle HTML imports this then renders the gallery.
   ============================================================================ */

const {
  useState,
  useRef,
  useEffect
} = React;

/* Screen scaffold helpers (PageHdr / SectionHdr / RowGroup / ListRow / NyanToggle)
   are shared from screens/_chrome.jsx. */

/* ──────────────────────────────────────────────────────────────────────
   U14 · SETTINGS PAGE
   Appearance / Reading / Data Management / Pro / About
   ────────────────────────────────────────────────────────────────────── */
const SettingsPage = ({
  dark,
  reminderOn,
  isPro
}) => {
  const [reminder, setReminder] = useState(reminderOn);
  return /*#__PURE__*/React.createElement(Shell, {
    dark: dark
  }, /*#__PURE__*/React.createElement(PageHdr, {
    title: "Settings"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: "auto",
      padding: "0 16px 32px"
    }
  }, /*#__PURE__*/React.createElement(SectionHdr, {
    label: "Appearance"
  }), /*#__PURE__*/React.createElement(RowGroup, null, /*#__PURE__*/React.createElement(ListRow, {
    icon: "palette",
    title: "Theme Preset",
    subtitle: dark ? "Sumi Dark" : "Cream Light",
    chevron: true
  }), /*#__PURE__*/React.createElement(ListRow, {
    icon: "translate",
    title: "Language",
    subtitle: "English",
    chevron: true
  })), /*#__PURE__*/React.createElement(SectionHdr, {
    label: "Reading"
  }), /*#__PURE__*/React.createElement(RowGroup, null, /*#__PURE__*/React.createElement(ListRow, {
    icon: "book-open",
    title: "Page Turn Mode",
    subtitle: "Left & Right",
    chevron: true
  }), /*#__PURE__*/React.createElement(ListRow, {
    icon: "bell",
    title: "Reading Reminder",
    subtitle: "Chapter seek and position",
    trailing: /*#__PURE__*/React.createElement(NyanToggle, {
      on: reminder
    })
  }), reminder && /*#__PURE__*/React.createElement(ListRow, {
    indent: true,
    title: "Reminder Interval",
    subtitle: "Every 30 min",
    chevron: true
  }), /*#__PURE__*/React.createElement(ListRow, {
    icon: "trash",
    title: "Delete Files on Remove",
    subtitle: "Remove source files when deleting a book",
    trailing: /*#__PURE__*/React.createElement(NyanToggle, {
      on: false
    })
  })), /*#__PURE__*/React.createElement(SectionHdr, {
    label: "Data Management"
  }), /*#__PURE__*/React.createElement(RowGroup, null, /*#__PURE__*/React.createElement(ListRow, {
    icon: "export",
    title: "Export Data",
    subtitle: "Save to device or share",
    chevron: true
  }), /*#__PURE__*/React.createElement(ListRow, {
    icon: "cloud-arrow-down",
    title: "Import Data",
    subtitle: "Restore from a backup file",
    chevron: true
  }), /*#__PURE__*/React.createElement(ListRow, {
    icon: "wrench",
    title: "Admin Panel",
    chevron: true
  })), isPro && /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(SectionHdr, {
    label: "Pro"
  }), /*#__PURE__*/React.createElement(RowGroup, null, /*#__PURE__*/React.createElement(ListRow, {
    icon: "lock-open",
    title: "Lock Privacy Shelf",
    subtitle: "Require PIN to open",
    chevron: true
  }))), /*#__PURE__*/React.createElement(SectionHdr, {
    label: "About"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--nyan-surface)",
      borderRadius: 16,
      border: "0.72px solid color-mix(in srgb, var(--nyan-divider) 36%, transparent)",
      padding: "16px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 56,
      height: 56,
      borderRadius: "var(--r-card-nested)",
      background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface-muted))",
      display: "grid",
      placeItems: "center",
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-book-open",
    style: {
      fontSize: 26,
      color: "var(--nyan-primary)"
    }
  })), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 18px/1.2 var(--font-ui)",
      color: "var(--nyan-text)"
    }
  }, "Nyan Read"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 13px/1.3 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      marginTop: 2
    }
  }, "v1.0.0 \xB7 \u0E05^\u2022\uFECC\u2022^\u0E05"))))));
};

/* ── U14 picker overlays — the option sheets that open from each settings row.
   Theme Preset / Language / Page Turn / Reminder Interval are single-select
   radio sheets; Export Data is an action sheet. Composed over the live
   SettingsPage so the picker reads in its real context. ──────────────────── */
const SETTINGS_PICKERS = {
  theme: {
    title: "Theme Preset",
    subtitle: "How Nyan Read looks while you read.",
    selected: 0,
    options: [{
      label: "Cream Light",
      hint: "Warm paper — the default",
      swatch: "#F7F5EF"
    }, {
      label: "Sumi Dark",
      hint: "Ink night for low light",
      swatch: "#262422"
    }, {
      label: "Match System",
      hint: "Follow your device setting",
      swatch: "linear-gradient(135deg, #F7F5EF 50%, #262422 50%)"
    }]
  },
  language: {
    title: "Language",
    subtitle: "App display language.",
    selected: 0,
    options: [{
      label: "English",
      hint: "English"
    }, {
      label: "中文",
      hint: "Chinese · 简体中文"
    }]
  },
  pageturn: {
    title: "Page Turn Mode",
    subtitle: "The direction pages move as you read.",
    selected: 0,
    options: [{
      label: "Left & Right",
      hint: "Turn pages horizontally",
      icon: "arrows-horizontal"
    }, {
      label: "Up & Down",
      hint: "Turn pages vertically",
      icon: "arrows-vertical"
    }]
  },
  reminder: {
    title: "Reminder Interval",
    subtitle: "How often to nudge you back to reading.",
    selected: 1,
    options: ["Every 15 minutes", "Every 30 minutes", "Every hour", "Every 2 hours", "Daily"]
  },
  export: {
    title: "Export Data",
    subtitle: "Choose where your reading data goes.",
    variant: "action",
    options: [{
      label: "Save to Device",
      hint: "Store a JSON backup in your Files",
      icon: "download-simple"
    }, {
      label: "Share…",
      hint: "Send via Gmail, Drive or another app",
      icon: "share-network"
    }]
  }
};
const SettingsWithPicker = ({
  dark,
  picker
}) => {
  const cfg = SETTINGS_PICKERS[picker] || SETTINGS_PICKERS.theme;
  return /*#__PURE__*/React.createElement("div", {
    "data-theme": dark ? "sumi" : undefined,
    style: {
      position: "relative",
      width: "100%",
      height: "100%",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement(SettingsPage, {
    dark: dark,
    reminderOn: picker === "reminder",
    isPro: false
  }), /*#__PURE__*/React.createElement(NyanOptionSheet, {
    title: cfg.title,
    subtitle: cfg.subtitle,
    options: cfg.options,
    selected: cfg.selected || 0,
    variant: cfg.variant || "radio",
    onClose: () => {}
  }));
};

/* ──────────────────────────────────────────────────────────────────────
   U15 · READER PROGRESS & CHAPTER NAV
   In One Paper there is no standalone progress card — progress and chapter
   navigation live in the DOCK FOOTER (thin progress bar + chapter stepper +
   the 3 actions). This shows the resting dock (collapsed, footer only) over
   a reader page. Tap the ‹ › stepper to move chapters.
   ────────────────────────────────────────────────────────────────────── */
const ReaderCanvasBg = ({
  dark,
  children
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    position: "relative",
    width: "100%",
    height: "100%",
    background: dark ? "#262422" : "#F7F5EF",
    overflow: "hidden"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    position: "absolute",
    inset: 0,
    padding: "44px 28px 24px",
    pointerEvents: "none"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 13.5px/1.85 var(--font-ui)",
    color: dark ? "#E5DED3" : "#4A453E",
    opacity: 0.55,
    textIndent: "2em"
  }
}, "The cat sat on the threshold for a long while, watching the rain darken the stones and the wisteria release its scent into the late spring evening.")), children);
const U15Artboard = ({
  dark,
  startIndex = 2
}) => {
  const [ci, setCi] = useState(startIndex);
  const TOTAL = 18;
  return /*#__PURE__*/React.createElement("div", {
    "data-theme": dark ? "sumi" : undefined,
    style: {
      width: "100%",
      height: "100%"
    }
  }, /*#__PURE__*/React.createElement(ReaderCanvasBg, {
    dark: dark
  }, /*#__PURE__*/React.createElement(OnePaperDock, {
    visible: true,
    sheetOpen: false,
    chapterIndex: ci,
    chapterCount: TOTAL,
    progress: (ci + 0.4) / TOTAL,
    activeAction: null,
    onAction: () => {},
    onPrevChapter: () => setCi(i => Math.max(0, i - 1)),
    onNextChapter: () => setCi(i => Math.min(TOTAL - 1, i + 1)),
    onStopProp: false
  })));
};

/* ──────────────────────────────────────────────────────────────────────
   U16 · PRIVACY PIN OVERLAY (FULL-SCREEN)
   Corrective: Colors.black @ 0.95 → #1D211E (ink-night)
               W300 → W400 (minimum weight in design system)
   Modes: setup · verify (error) · change
   ────────────────────────────────────────────────────────────────────── */
const PinDots = ({
  count,
  hasError,
  dotColor
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    gap: 20,
    justifyContent: "center",
    animation: hasError ? "pin-shake 320ms ease" : "none"
  }
}, [0, 1, 2, 3].map(i => /*#__PURE__*/React.createElement("div", {
  key: i,
  style: {
    width: 16,
    height: 16,
    borderRadius: "50%",
    background: i < count ? dotColor : "transparent",
    border: `1.5px solid ${hasError ? `color-mix(in srgb, ${dotColor} 38%, transparent)` : `color-mix(in srgb, ${dotColor} 56%, transparent)`}`,
    transition: "background 120ms ease"
  }
})));
const NumPad = ({
  onDigit,
  onDelete,
  keyColor
}) => {
  const keys = [[1, 2, 3], [4, 5, 6], [7, 8, 9], [null, 0, "⌫"]];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 12,
      alignItems: "center"
    }
  }, keys.map((row, ri) => /*#__PURE__*/React.createElement("div", {
    key: ri,
    style: {
      display: "flex",
      gap: 16
    }
  }, row.map((k, ki) => k === null ? /*#__PURE__*/React.createElement("div", {
    key: "empty",
    style: {
      width: 72,
      height: 72
    }
  }) : /*#__PURE__*/React.createElement("button", {
    key: k,
    onClick: () => k === "⌫" ? onDelete() : onDigit(k),
    style: {
      all: "unset",
      cursor: "pointer",
      width: 72,
      height: 72,
      borderRadius: "50%",
      background: `color-mix(in srgb, ${keyColor} 10%, transparent)`,
      border: `1px solid color-mix(in srgb, ${keyColor} 16%, transparent)`,
      display: "grid",
      placeItems: "center",
      font: k === "⌫" ? "400 22px/1 var(--font-ui)" : "400 26px/1 var(--font-ui)",
      color: keyColor,
      transition: "background 100ms ease"
    }
  }, k)))));
};
const PinOverlay = ({
  mode = "verify",
  hasError,
  dark = true
}) => {
  const [digits, setDigits] = useState(hasError ? [1, 2, 3, 4] : []);
  const titles = {
    setup: "Set PIN",
    verify: "Enter PIN",
    change: "New PIN",
    confirm: "Confirm PIN"
  };
  const onDigit = d => setDigits(p => p.length < 4 ? [...p, d] : p);
  const onDelete = () => setDigits(p => p.slice(0, -1));

  // Dark = ink-night takeover; Light = warm-paper takeover. Same layout, themed.
  const bg = dark ? "#1D211E" : "var(--nyan-bg)";
  const fg = dark ? "#E8E1D5" : "var(--nyan-text)";
  const subtle = dark ? "color-mix(in srgb, #E8E1D5 52%, transparent)" : "var(--nyan-text-muted)";
  const lockTint = dark ? "color-mix(in srgb, #E8E1D5 12%, transparent)" : "color-mix(in srgb, var(--nyan-primary) 12%, transparent)";
  const lockIcon = dark ? "#E8E1D5" : "var(--nyan-primary-deep)";
  return /*#__PURE__*/React.createElement("div", {
    "data-theme": dark ? "sumi" : undefined,
    style: {
      width: "100%",
      height: "100%",
      background: bg,
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "center",
      position: "relative",
      gap: 0
    }
  }, /*#__PURE__*/React.createElement("button", {
    style: {
      all: "unset",
      cursor: "pointer",
      position: "absolute",
      top: 14,
      right: 14,
      width: 44,
      height: 44,
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-x",
    style: {
      fontSize: 22,
      color: subtle
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 56,
      height: 56,
      borderRadius: "var(--r-card-nested)",
      background: lockTint,
      display: "grid",
      placeItems: "center",
      marginBottom: 22
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-lock-simple",
    style: {
      fontSize: 26,
      color: lockIcon
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "500 20px/1.2 var(--font-ui)",
      color: fg,
      letterSpacing: "0.4px",
      marginBottom: hasError ? 16 : 48
    }
  }, titles[mode]), hasError && /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 13px/1.3 var(--font-ui)",
      color: subtle,
      letterSpacing: "0.3px",
      marginBottom: 20,
      textAlign: "center"
    }
  }, "PINs don't match \u2014 try again"), /*#__PURE__*/React.createElement("div", {
    style: {
      marginBottom: 48
    }
  }, /*#__PURE__*/React.createElement(PinDots, {
    count: digits.length,
    hasError: hasError,
    dotColor: fg
  })), /*#__PURE__*/React.createElement(NumPad, {
    onDigit: onDigit,
    onDelete: onDelete,
    keyColor: fg
  }));
};

/* ──────────────────────────────────────────────────────────────────────
   U17 · TTS SHEET (DESIGNED — source is a stub)
   Bottom sheet: voice chip · speed selector · play/pause · skip · progress
   ────────────────────────────────────────────────────────────────────── */
const TTS_SPEEDS = ["0.75×", "1.0×", "1.25×", "1.5×"];
const TTSSheet = ({
  dark
}) => {
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState(1);
  const [progress, setProgress] = useState(0.3);
  const trackRef = useRef(null);
  const dragging = useRef(false);
  const seek = e => {
    if (!trackRef.current) return;
    const rect = trackRef.current.getBoundingClientRect();
    const cx = e.touches ? e.touches[0].clientX : e.clientX;
    setProgress(Math.max(0, Math.min(1, (cx - rect.left) / rect.width)));
  };
  useEffect(() => {
    const mm = e => {
      if (dragging.current) seek(e);
    };
    const mu = () => {
      dragging.current = false;
    };
    window.addEventListener("mousemove", mm);
    window.addEventListener("mouseup", mu);
    return () => {
      window.removeEventListener("mousemove", mm);
      window.removeEventListener("mouseup", mu);
    };
  }, []);
  return /*#__PURE__*/React.createElement("div", {
    "data-theme": dark ? "sumi" : undefined,
    style: {
      position: "relative",
      width: "100%",
      height: "100%",
      background: dark ? "#262422" : "#F7F5EF",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      padding: "44px 28px 24px",
      pointerEvents: "none"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 13.5px/1.85 var(--font-ui)",
      color: dark ? "#E5DED3" : "#4A453E",
      opacity: 0.5,
      textIndent: "2em"
    }
  }, "The cat sat on the threshold for a long while, watching the rain darken the stones and the wisteria release its scent into the late spring evening.")), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      background: "var(--scrim)",
      backdropFilter: "blur(var(--scrim-blur))",
      WebkitBackdropFilter: "blur(var(--scrim-blur))"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: "var(--inset)",
      right: "var(--inset)",
      bottom: "var(--inset)",
      background: "var(--nyan-surface)",
      border: "1px solid var(--chrome-edge)",
      borderRadius: "var(--r-sheet)",
      boxShadow: "var(--shadow-light-card)",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      paddingTop: 10,
      display: "flex",
      justifyContent: "center"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 40,
      height: 5,
      borderRadius: 999,
      background: "var(--grabber)"
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "14px 20px 28px",
      display: "flex",
      flexDirection: "column",
      gap: 16
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between"
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 17px/1.2 var(--font-ui)",
      color: "var(--nyan-text)",
      letterSpacing: "-0.1px"
    }
  }, "Read Aloud"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 13px/1.3 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      marginTop: 2
    }
  }, "Chapter 3 \u2014 A Cup of Still Water")), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 34,
      padding: "0 12px",
      borderRadius: 999,
      background: "color-mix(in srgb, var(--nyan-primary) 10%, var(--nyan-surface-muted))",
      border: "1px solid color-mix(in srgb, var(--nyan-primary) 18%, transparent)",
      display: "flex",
      alignItems: "center",
      gap: 6,
      cursor: "pointer"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-user-sound",
    style: {
      fontSize: 14,
      color: "var(--nyan-primary)"
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "500 13px/1 var(--font-ui)",
      color: "var(--nyan-primary-deep)"
    }
  }, "System Voice"))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    ref: trackRef,
    onMouseDown: e => {
      dragging.current = true;
      seek(e);
    },
    style: {
      position: "relative",
      height: 12,
      cursor: "pointer"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      borderRadius: 8,
      background: "color-mix(in srgb, var(--nyan-divider) 30%, var(--nyan-surface-muted))"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      top: 0,
      left: 0,
      height: "100%",
      width: `${Math.round(progress * 100)}%`,
      borderRadius: 8,
      background: "var(--nyan-primary)"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      top: -1,
      left: `calc(${Math.round(progress * 100)}% - 7px)`,
      width: 14,
      height: 14,
      borderRadius: 8,
      background: "var(--nyan-primary)",
      border: "1.2px solid color-mix(in srgb, var(--nyan-surface) 82%, transparent)"
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "400 12px/1 var(--font-ui)",
      color: "var(--nyan-text-muted)",
      fontVariantNumeric: "tabular-nums"
    }
  }, "2:14"), /*#__PURE__*/React.createElement("span", {
    style: {
      font: "400 12px/1 var(--font-ui)",
      color: "var(--nyan-text-muted)",
      fontVariantNumeric: "tabular-nums"
    }
  }, "7:30"))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      background: "var(--nyan-surface-muted)",
      borderRadius: 14,
      padding: 3,
      gap: 2
    }
  }, TTS_SPEEDS.map((s, i) => /*#__PURE__*/React.createElement("button", {
    key: s,
    onClick: () => setSpeed(i),
    style: {
      all: "unset",
      cursor: "pointer",
      flex: 1,
      height: 32,
      borderRadius: 11,
      background: speed === i ? "var(--nyan-surface)" : "transparent",
      boxShadow: speed === i ? "0 1px 3px rgba(0,0,0,0.06)" : "none",
      font: `${speed === i ? 600 : 500} 13px/1 var(--font-ui)`,
      color: speed === i ? "var(--nyan-text)" : "var(--nyan-text-muted)",
      display: "grid",
      placeItems: "center",
      transition: "background 160ms ease"
    }
  }, s))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      gap: 12
    }
  }, ["skip-back", "rewind", "play"].map((ic, i) => {
    const isPlay = i === 2;
    return /*#__PURE__*/React.createElement("button", {
      key: ic,
      onClick: isPlay ? () => setPlaying(p => !p) : undefined,
      style: {
        all: "unset",
        cursor: "pointer",
        width: isPlay ? 60 : 48,
        height: isPlay ? 60 : 48,
        borderRadius: isPlay ? 18 : 14,
        background: isPlay ? "var(--nyan-primary)" : "var(--nyan-surface-muted)",
        border: isPlay ? "none" : "1px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)",
        display: "grid",
        placeItems: "center"
      }
    }, /*#__PURE__*/React.createElement("i", {
      className: `ph ph-${isPlay ? playing ? "pause" : "play" : ic}`,
      style: {
        fontSize: isPlay ? 28 : 22,
        color: isPlay ? "var(--nyan-surface)" : "var(--nyan-primary)"
      }
    }));
  }), ["fast-forward", "skip-forward"].map(ic => /*#__PURE__*/React.createElement("button", {
    key: ic,
    style: {
      all: "unset",
      cursor: "pointer",
      width: 48,
      height: 48,
      borderRadius: 14,
      background: "var(--nyan-surface-muted)",
      border: "1px solid color-mix(in srgb, var(--nyan-divider) 44%, transparent)",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: `ph ph-${ic}`,
    style: {
      fontSize: 22,
      color: "var(--nyan-primary)"
    }
  })))))));
};

/* ── U17 (active) · Reading aloud — the state AFTER TTS starts ─────────────
   The setup sheet collapses to a slim floating mini-player; the book content
   stays visible and auto-scrolls so the spoken sentence is highlighted in
   matcha. The mini-player speaks the One Paper dock language (inset, rounded,
   lightCard) and carries the essential transport: play/pause + stop. */
const TTS_PARAS = [["She would sometimes say that of all the noises in the city, only the bell and the rain felt honest.", false], ["The trams, the merchants, the cries of the gulls upriver — all of them wanted something.", false], ["The bell never did. It simply marked the hour and let you fold the page however you liked.", true], ["He set the lacquer cup down on the low table and looked, again, at the calligraphy in the alcove.", false], ["An old hand, careful and not particularly clever; he had read it perhaps three hundred times.", false]];
const TTSActiveReading = ({
  dark
}) => {
  const [playing, setPlaying] = useState(true);
  const ink = dark ? "#E5DED3" : "#4A453E";
  return /*#__PURE__*/React.createElement("div", {
    "data-theme": dark ? "sumi" : undefined,
    style: {
      position: "relative",
      width: "100%",
      height: "100%",
      background: dark ? "#262422" : "#F7F5EF",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      padding: "52px 26px 120px",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: `400 12px/1.4 ${"var(--font-ui)"}`,
      color: ink,
      opacity: 0.5,
      marginBottom: 20,
      letterSpacing: 0.4
    }
  }, "Chapter 3 \xB7 A Cup of Still Water"), TTS_PARAS.map(([text, active], i) => /*#__PURE__*/React.createElement("p", {
    key: i,
    style: {
      font: "400 16px/1.72 var(--font-serif)",
      color: active ? "var(--nyan-primary-deep)" : ink,
      opacity: active ? 1 : 0.66,
      background: active ? "color-mix(in srgb, var(--nyan-primary) 15%, transparent)" : "transparent",
      borderRadius: active ? 10 : 0,
      padding: active ? "6px 10px" : "0",
      margin: active ? "0 -10px 16px" : "0 0 16px",
      transition: "background 200ms var(--ease-paper)"
    }
  }, text))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: "var(--inset)",
      right: "var(--inset)",
      bottom: "var(--inset)",
      background: "var(--nyan-surface)",
      border: "1px solid var(--chrome-edge)",
      borderRadius: "var(--r-dock)",
      boxShadow: "var(--shadow-light-card)",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 3,
      background: "color-mix(in srgb, var(--nyan-text) 11%, transparent)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: "46%",
      height: "100%",
      background: "var(--nyan-primary)"
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 12,
      padding: "10px 12px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 38,
      height: 38,
      flex: "none",
      borderRadius: 12,
      background: "color-mix(in srgb, var(--nyan-primary) 12%, transparent)",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-waveform",
    style: {
      fontSize: 20,
      color: "var(--nyan-primary-deep)"
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 13.5px/1.2 var(--font-ui)",
      color: "var(--nyan-text)",
      whiteSpace: "nowrap",
      overflow: "hidden",
      textOverflow: "ellipsis"
    }
  }, "Reading aloud"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 11.5px/1.2 var(--font-ui)",
      color: "var(--nyan-text-muted)"
    }
  }, "System Voice \xB7 1.0\xD7 \xB7 2:14 / 7:30")), /*#__PURE__*/React.createElement("button", {
    onClick: () => setPlaying(p => !p),
    style: {
      all: "unset",
      cursor: "pointer",
      width: 44,
      height: 44,
      flex: "none",
      borderRadius: 14,
      background: "var(--nyan-primary)",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: `ph-fill ph-${playing ? "pause" : "play"}`,
    style: {
      fontSize: 20,
      color: "var(--nyan-surface)"
    }
  })), /*#__PURE__*/React.createElement("button", {
    style: {
      all: "unset",
      cursor: "pointer",
      width: 44,
      height: 44,
      flex: "none",
      borderRadius: 14,
      background: "var(--nyan-surface-muted)",
      border: "1px solid var(--nyan-divider)",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph-fill ph-stop",
    style: {
      fontSize: 18,
      color: "var(--nyan-text-secondary)"
    }
  })))));
};
const FlagBadge = ({
  on,
  dark
}) => {
  const accent = on ? "var(--nyan-primary-deep)" : "var(--nyan-text-secondary)";
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: 28,
      padding: "0 12px",
      borderRadius: "var(--r-chip)",
      background: `color-mix(in srgb, ${accent} ${on ? 10 : 8}%, var(--nyan-surface-muted))`,
      border: `1px solid color-mix(in srgb, ${accent} ${on ? 30 : 22}%, transparent)`,
      display: "flex",
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: "500 12px/1 var(--font-ui)",
      color: accent
    }
  }, on ? "On" : "Off"));
};
const AdminPanel = ({
  dark,
  isPro
}) => {
  const [proOn, setPro] = useState(isPro);
  const [unlocked, setUnlocked] = useState(false);
  const flags = {
    Ads: true,
    Privacy: isPro,
    TTS: false
  };
  return /*#__PURE__*/React.createElement(Shell, {
    dark: dark
  }, /*#__PURE__*/React.createElement(PageHdr, {
    title: "Admin Panel"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: "auto",
      padding: "0 16px 32px"
    }
  }, /*#__PURE__*/React.createElement(SectionHdr, {
    label: "Mode"
  }), /*#__PURE__*/React.createElement(RowGroup, null, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "12px 16px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "flex-start",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 15px/1.2 var(--font-ui)",
      color: "var(--nyan-text)",
      marginBottom: 4
    }
  }, "Pro Mode Enabled"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 13px/1.3 var(--font-ui)",
      color: "var(--nyan-text-secondary)"
    }
  }, "Unlocks all Pro features in this session.")), /*#__PURE__*/React.createElement("div", {
    onClick: () => setPro(p => !p)
  }, /*#__PURE__*/React.createElement(NyanToggle, {
    on: proOn
  })))), proOn && /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      height: "0.5px",
      background: "color-mix(in srgb, var(--nyan-divider) 34%, transparent)",
      margin: "0 16px"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "12px 16px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "flex-start",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 15px/1.2 var(--font-ui)",
      color: "var(--nyan-text)",
      marginBottom: 4
    }
  }, "Force Unlock Privacy Shelf"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 13px/1.3 var(--font-ui)",
      color: "var(--nyan-text-secondary)"
    }
  }, "Bypass PIN for this session.")), /*#__PURE__*/React.createElement("div", {
    onClick: () => setUnlocked(p => !p)
  }, /*#__PURE__*/React.createElement(NyanToggle, {
    on: unlocked
  })))))), /*#__PURE__*/React.createElement(SectionHdr, {
    label: "Feature Flags"
  }), /*#__PURE__*/React.createElement(RowGroup, null, Object.entries(flags).map(([name, on], i) => /*#__PURE__*/React.createElement("div", {
    key: name,
    style: {
      display: "flex",
      alignItems: "center",
      padding: "12px 16px",
      minHeight: 44
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      font: "500 15px/1.2 var(--font-ui)",
      color: "var(--nyan-text)"
    }
  }, name), /*#__PURE__*/React.createElement(FlagBadge, {
    on: on,
    dark: dark
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 12,
      background: "color-mix(in srgb, var(--nyan-primary) 5%, var(--nyan-surface))",
      borderRadius: 16,
      border: "0.72px solid color-mix(in srgb, var(--nyan-primary-deep) 22%, transparent)",
      padding: "14px 16px",
      display: "flex",
      gap: 10,
      alignItems: "flex-start"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-info",
    style: {
      fontSize: 18,
      color: "var(--nyan-primary-deep)",
      flexShrink: 0,
      marginTop: 1
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 14px/1.2 var(--font-ui)",
      color: "var(--nyan-text)",
      marginBottom: 4
    }
  }, "For testing only"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 13px/1.35 var(--font-ui)",
      color: "var(--nyan-text-secondary)"
    }
  }, "Changes here affect only this session. Restart the app to reset to defaults.")))));
};

/* ──────────────────────────────────────────────────────────────────────
   U19 · BOOKSHELF SHELF TOOLBAR (PINNED HEADER)
   NyanInfoCard wrapper + SegmentedTabControl + sort/view actions above
   ────────────────────────────────────────────────────────────────────── */
const BOOKS_SHELF = [{
  id: 1,
  title: "The Stillwater Diaries",
  author: "Matsuno Eri",
  fmt: "EPUB",
  pct: 42
}, {
  id: 2,
  title: "Borrowed Light",
  author: "Yuen Lai-Ying",
  fmt: "TXT",
  pct: 0
}, {
  id: 3,
  title: "A Long Slope Down",
  author: "Park Hyun-joo",
  fmt: "PDF",
  pct: 88
}, {
  id: 4,
  title: "Sand and Memoir",
  author: "Unknown",
  fmt: "EPUB",
  pct: 12
}];
const SmallBookCard = ({
  book
}) => /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    flexDirection: "column",
    cursor: "pointer"
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    width: "100%",
    aspectRatio: "120/156",
    borderRadius: 12,
    background: "color-mix(in srgb, var(--nyan-primary) 12%, var(--nyan-surface))",
    border: "0.5px solid color-mix(in srgb, var(--nyan-divider) 28%, transparent)",
    display: "grid",
    placeItems: "center",
    marginBottom: 6
  }
}, /*#__PURE__*/React.createElement("i", {
  className: "ph ph-book-open",
  style: {
    fontSize: 26,
    color: "var(--nyan-primary)"
  }
})), book.pct > 0 && /*#__PURE__*/React.createElement("div", {
  style: {
    height: 2.5,
    borderRadius: 999,
    background: "color-mix(in srgb, var(--nyan-primary) 16%, var(--nyan-surface))",
    marginBottom: 6
  }
}, /*#__PURE__*/React.createElement("div", {
  style: {
    width: `${book.pct}%`,
    height: "100%",
    borderRadius: 999,
    background: "var(--nyan-primary)"
  }
})), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "600 12.5px/1.25 var(--font-ui)",
    color: "var(--nyan-text)",
    overflow: "hidden",
    display: "-webkit-box",
    WebkitLineClamp: 2,
    WebkitBoxOrient: "vertical",
    marginBottom: 2
  }
}, book.title), /*#__PURE__*/React.createElement("div", {
  style: {
    font: "400 11px/1.3 var(--font-ui)",
    color: "var(--nyan-text-muted)",
    whiteSpace: "nowrap",
    overflow: "hidden",
    textOverflow: "ellipsis"
  }
}, book.author));
const ShelfToolbarScreen = ({
  dark,
  sort,
  isPro = false
}) => {
  const [tab, setTab] = useState(0);
  return /*#__PURE__*/React.createElement(Shell, {
    dark: dark
  }, /*#__PURE__*/React.createElement(ShelfToolbar, {
    sort: sort,
    isPro: isPro,
    unlocked: isPro,
    onSearch: () => {}
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "0 16px 0",
      flexShrink: 0,
      borderBottom: "1px solid color-mix(in srgb, var(--nyan-divider) 30%, transparent)",
      background: "var(--nyan-bg)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--nyan-surface)",
      borderRadius: 16,
      border: "0.72px solid color-mix(in srgb, var(--nyan-divider) 36%, transparent)",
      padding: 12,
      marginBottom: 10
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      background: "color-mix(in srgb, var(--nyan-bg) 66%, var(--nyan-surface-muted))",
      borderRadius: 12,
      padding: 3,
      gap: 2,
      height: 40
    }
  }, ["Public Shelf", "Private Shelf"].map((t, i) => /*#__PURE__*/React.createElement("button", {
    key: t,
    onClick: () => setTab(i),
    style: {
      all: "unset",
      cursor: "pointer",
      flex: 1,
      borderRadius: 9,
      background: tab === i ? "var(--nyan-surface)" : "transparent",
      boxShadow: tab === i ? "0 1px 3px rgba(0,0,0,0.06)" : "none",
      font: `${tab === i ? 600 : 500} 14px/1 var(--font-ui)`,
      color: tab === i ? "var(--nyan-text)" : "var(--nyan-text-muted)",
      display: "grid",
      placeItems: "center",
      transition: "background 160ms ease"
    }
  }, t))))), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: "auto",
      padding: "14px 16px 32px"
    }
  }, tab === 1 ? /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "center",
      height: "100%",
      gap: 14,
      textAlign: "center",
      paddingTop: 40
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 80,
      height: 80,
      borderRadius: "50%",
      background: "color-mix(in srgb, var(--nyan-primary) 7%, var(--nyan-surface))",
      border: "0.7px solid color-mix(in srgb, var(--nyan-divider) 18%, transparent)",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "ph ph-lock",
    style: {
      fontSize: 32,
      color: "var(--nyan-primary)",
      opacity: 0.72
    }
  })), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: "600 17px/1.25 var(--font-ui)",
      color: "var(--nyan-text)",
      opacity: 0.82,
      marginBottom: 8
    }
  }, "This private space is empty."), /*#__PURE__*/React.createElement("div", {
    style: {
      font: "400 14px/1.5 var(--font-ui)",
      color: "var(--nyan-text-secondary)",
      opacity: 0.72,
      maxWidth: 260,
      margin: "0 auto"
    }
  }, "Select books from the public shelf and tap the Lock icon to move them here."))) : /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr 1fr",
      gap: "16px 12px"
    }
  }, BOOKS_SHELF.concat(BOOKS_SHELF).slice(0, 9).map((b, i) => /*#__PURE__*/React.createElement(SmallBookCard, {
    key: i,
    book: b
  })))));
};

/* ──────────────────────────────────────────────────────────────────────
   DESIGN CANVAS
   ────────────────────────────────────────────────────────────────────── */

/* ── Exports ─────────────────────────────────────────────────────────────── */
Object.assign(window, {
  SettingsPage,
  SETTINGS_PICKERS,
  SettingsWithPicker,
  ReaderCanvasBg,
  U15Artboard,
  PinDots,
  NumPad,
  PinOverlay,
  TTS_SPEEDS,
  TTSSheet,
  TTS_PARAS,
  TTSActiveReading,
  FlagBadge,
  AdminPanel,
  BOOKS_SHELF,
  SmallBookCard,
  ShelfToolbarScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "screens/bundle4.jsx", error: String((e && e.message) || e) }); }

})();
