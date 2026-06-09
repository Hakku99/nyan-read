---
name: nyan-read-design
description: Use this skill to generate well-branded interfaces and assets for Nyan Read (喵阅), a Muji-leaning, paper-book-feeling, matcha-accented offline e-book reader — either for production code or throwaway prototypes, slides, and mocks. Contains essential design guidelines, color and typography tokens, fonts, brand assets, and ready-to-paste UI kit components.
user-invocable: true
---

Read the `README.md` file within this skill, and explore the other available files.

If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets out and create static HTML files for the user to view. The minimum onboarding is:

1. `README.md` — product context, voice & tone, visual foundations, iconography.
2. `colors_and_type.css` — all CSS variables (colors, type, spacing, radii, shadows) plus base classes (`.nyan-display`, `.nyan-title`, etc.). Include this in every HTML output.
3. `components/` — drop-in React components mirroring the Flutter source, split into `primitives.jsx`, `headers.jsx`, `surfaces.jsx`, `cards.jsx`, `reader.jsx` (load in that order). See `components/README.md` for the full API and the Flutter widget map.Card`, `NyanBookmarkCard`, `PillButton`, etc.).
4. `mocks/UNN-*.html` + `screens/*.jsx` — 21 assembled screen mocks to crib patterns from.
5. `assets/images/nyan_read_logo*.png` — the only mascot art used in-product.
6. `assets/fonts/NotoSansSC-*.ttf` (UI, 400/500/600) bundled locally. Source Han Serif SC (reading serif) is currently **missing** — falls back to platform CJK serif. See README font flag.

If working on production code, you can copy assets and read the rules here to become an expert in designing with this brand. Cross-reference with the Flutter source at <https://github.com/Hakku99/nyan-read> when fidelity matters.

If the user invokes this skill without any other guidance, ask them what they want to build or design, ask some questions (audience, format, tone, length, mobile vs marketing surface), and act as an expert designer who outputs HTML artifacts _or_ production code, depending on the need.

**Hard rules — never violate without explicit user override:**
- No pure `#FFFFFF` or `#000000`. Use the cream / ink / sumi tokens.
- One strong color: matcha green. Orange is reserved for warmth/warning semantics.
- Only 5 type sizes (32, 24, 20, 16, 13) and 3 weights (400, 500, 600).
- Only 5 corner radii (14, 16, 20, 24, 28). Pill buttons override with stadium.
- Shadows from tokens only (`--shadow-light-card`, `--shadow-subtle`, `--shadow-grouped`). Sumi Dark has no shadows.
- No emoji, no Unicode dingbats inline, no gradients, no glass blur, no custom SVG illustrations besides the Nyan cat logo.
- **Iconography is Phosphor Regular**, not Material Round. The JSX `<Icon name="menu_book"/>` component maps Material-style names to Phosphor kebab-case internally, so existing call sites read naturally. Load `https://unpkg.com/@phosphor-icons/web@2.1.1/src/regular/style.css` (+ `/fill/style.css` for set bookmarks).
- The Nyan cat logo (`assets/images/nyan_read_logo*.png`) is the **only illustration** in the product.
- Selected pill-button state is **outline-only** (primaryDeep border + primaryDeep text, no fill) — the project's signature interaction.
- Copy is calm, Title-Case headings, sentence-case subtitles, second-person, no exclamation marks except inside friendly recoveries.
