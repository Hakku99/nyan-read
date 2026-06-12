/* ============================================================================
   Nyan Read — Icon
   Compiled into the DS bundle; consume as window.<Namespace>.Icon.
   Props contract: ./Icon.d.ts
   ============================================================================ */

/* ── Icon shortcut ───────────────────────────────────────────────────────
   Renders Phosphor icons (Regular by default). Accepts Material-style names
   (menu_book, bookmark, chevron_right, ...) and maps them to Phosphor's
   kebab-case equivalents — so callers stay legible and source-aligned.
   `weight` ("regular" | "fill" | "bold" | ...) picks the Phosphor weight class;
   pass an `onClick` to get button semantics (role, focus, Enter/Space).
   See preview/iconography.html for rationale on the Phosphor swap. */
const MATERIAL_TO_PHOSPHOR = {
  menu_book: "book-open", bookmark: "bookmark-simple",
  bookmark_border: "bookmark-simple", lock: "lock-simple",
  lock_open: "lock-simple-open", add: "plus", remove: "minus",
  settings: "gear-six", search: "magnifying-glass",
  more_horiz: "dots-three", chevron_right: "caret-right", chevron_left: "caret-left", check: "check",
  keyboard_arrow_up: "caret-up", keyboard_arrow_down: "caret-down",
  arrow_back: "arrow-left", close: "x", share: "share-network",
  ios_share: "share-fat", delete: "trash", delete_outline: "trash",
  alarm: "alarm", auto_stories: "books", view_list: "list",
  grid_view: "squares-four", sort: "arrows-down-up", schedule: "clock",
  library_add: "book-bookmark", title: "text-aa", palette: "palette",
  language: "translate", format_size: "text-aa",
  cloud_download: "cloud-arrow-down", cloud_upload: "cloud-arrow-up",
  auto_awesome: "sparkle", folder_open: "folder-open",
  content_copy: "copy", tune: "sliders-horizontal",
  format_list_bulleted: "list-bullets", wb_sunny: "sun", block: "prohibit",
};
const Icon = ({ name, size = 20, color, weight, style, onClick, "aria-label": ariaLabel }) => {
  const phName = MATERIAL_TO_PHOSPHOR[name] || name.replace(/_/g, "-");
  // weight overrides the default; `bookmark` keeps its historical filled look.
  const resolvedWeight = weight || (name === "bookmark" ? "fill" : "regular");
  const baseClass = resolvedWeight === "regular" ? "ph" : `ph-${resolvedWeight}`;
  const interactive = typeof onClick === "function";
  const onKeyDown = interactive
    ? (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); onClick(e); } }
    : undefined;
  return (
    <i
      className={`${baseClass} ph-${phName}`}
      onClick={onClick}
      onKeyDown={onKeyDown}
      role={interactive ? "button" : "img"}
      tabIndex={interactive ? 0 : undefined}
      aria-label={ariaLabel}
      aria-hidden={!interactive && !ariaLabel ? "true" : undefined}
      style={{ fontSize: size, color: color || "var(--nyan-text)", lineHeight: 1, display: "inline-flex", alignItems: "center", justifyContent: "center", cursor: interactive ? "pointer" : undefined, ...style }}
    />
  );
};

export { Icon };
