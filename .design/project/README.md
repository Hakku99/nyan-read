# Nyan Read Design System

> **喵阅 Nyan Read** — a fully-offline Flutter e-book reader for TXT / EPUB / PDF.
> Source: <https://github.com/Hakku99/nyan-read>
> This design system distills its visual language so agents and designers can produce on-brand mocks, slides, prototypes, and production-aligned UI without re-reading the codebase every time.

---

## What Nyan Read is

**Nyan Read (喵阅)** is a Chinese-first, fully-offline e-book reader. Its product manifesto (translated from `AGENTS.md`):

1. **"A book, not an app."** The UI is meant to feel like a paper book on a desk, not a Material widget gallery. The aesthetic guide the maintainer wrote is *"Muji × paper-book reading × restrained matcha."*
2. **Privacy-first.** No cloud, no account, no telemetry. Everything lives in local SQLite + SharedPreferences. The Pro tier adds an AES-256 encrypted "Privacy Shelf" guarded by a PIN.
3. **Long-session friendly.** Anything that causes the device to heat, drop frames, or drain battery during a real reading session is treated as a bug — even if the feature works.

There is **one product, two surfaces**:

| Surface | Where it lives | Purpose |
|---|---|---|
| **Bookshelf shell** | Home → Public / Private shelf tabs → Settings | Library management, import, search, sort, theme |
| **Reader canvas** | Tap any book | The actual page-by-page reader: chapter list, bookmarks, highlights, brightness/warmth, typography, theme swatches |

The product is bilingual — Simplified Chinese (`zh`) and English (`en`) live in `lib/l10n/`. CJK typography is a first-class concern.

---

## Sources used to build this system

- **GitHub repo** — [`Hakku99/nyan-read`](https://github.com/Hakku99/nyan-read)
  - `AGENTS.md` — the design constitution; §4 is the UI/UX style guide we mirrored
  - `ARCHITECTURE.md`, `READER_ARCHITECTURE.md` — module map + reader engine contracts
  - `lib/core/theme/nyan_*.dart` — the **five token files** (colors, radii, shadows, spacing, typography). Everything in this design system traces back to one of them.
  - `lib/core/ui/components/nyan_*.dart` — 28 shared widgets; we re-implemented the most visible ones as JSX in `components/`.
  - `lib/modules/{bookshelf, reader, settings}/` — the screens we modeled.
  - `lib/l10n/app_localizations_en.dart` — source of truth for English copy and tone.
  - `assets/images/nyan_read_logo.png`, `nyan_read_logo_transparent.png`, `splash_screen.png` — official brand assets (copied here under `assets/`).
  - `assets/fonts/SourceHanSerifSC-Regular.otf` + `SemiBold.otf` — reading-mode serif (copied here under `assets/fonts/`).

> **Reader: if you can access the GitHub repo above, browse it.** The Dart source has hundreds of small design decisions (animation timings, optical micro-adjustments, recessed-surface tones) that this system summarizes but does not exhaustively reproduce. When in doubt, the Dart files are the spec.

---

## Index — what's in this folder

```
README.md                ← you are here
SKILL.md                 ← Claude Code / agent-skill descriptor
colors_and_type.css      ← all CSS vars (colors, type, spacing, radii, shadows) + base classes

assets/
  fonts/SourceHanSerifSC-*.otf   ← reading-mode serif (Adobe, OFL)
  images/nyan_read_logo.png      ← square cream-card logo
  images/nyan_read_logo_transparent.png  ← transparent canvas, for overlays
  images/splash_screen.png       ← splash artwork

preview/                  ← Design-system cards rendered for the review pane
  type-scale.html
  type-weights.html
  font-families.html
  palette-cream-core.html
  palette-cream-text.html
  palette-sumi-core.html
  palette-highlights.html
  palette-reader-canvas.html
  radii.html
  spacing.html
  shadows.html
  buttons.html
  pill-segmented.html
  segmented-tab.html
  cards.html
  bookmark-card.html
  continue-reading.html
  shelf-grid.html
  list-row.html
  bottom-sheet.html
  section-header.html
  empty-state.html
  brand-logo.html
  iconography.html

components/                ← component library (load in this order)
  README.md
  primitives.jsx           ← Icon, buttons, switch, slider, FAB
  headers.jsx              ← page / section headers, segmented tabs
  surfaces.jsx             ← info card, bottom sheet, response toast, empty state
  cards.jsx                ← book grid / continue-reading / bookmark cards, list rows
  reader.jsx               ← One-Paper dock, reader paragraph

screens/                  ← full-screen compositions assembled from components/*
  _chrome.jsx              ← shared phone-frame + overlay wrappers
  bundle1.jsx … bundle4.jsx
```

Each `mocks/UNN-*.html` loads `colors_and_type.css`, the five `components/*.jsx`
files, and the relevant `screens/*.jsx` — so every screen is an editable file
rather than HTML-embedded script.

---

## Content fundamentals

The product copy is **bilingual** and the English (which agents will mostly write) is calm, low-emoji, and unmistakably *"a cute reader, not a productivity tool."*

### Voice & tone
- **Quiet, friendly, second-person.** "Your shelf," "Ready to start," "Continue Reading." First-person never appears outside the marketing line "Nyan cannot read this format."
- **Errors are described, not blamed.** Real strings from `app_localizations_en.dart`:
  - File missing → *"This book seems to have lost its way. The file cannot be found, it may have been moved or deleted."*
  - Bad format → *"Nyan cannot read this format. This file type is not supported yet."*
  - Parse failure → *"The pages are stuck together. Failed to parse file, it might be corrupted."*
- **Empty states are inviting, not instructional.** *"Bookshelf is waiting for stories"* / *"It's empty here. Import a book?"* / *"Passages worth returning to will gather here."*
- **Numbers are unitless when possible.** Progress is `42%`, never `42 percent` or `42.0%`. Chapter counters are `12 / 184 chapters`. Bookmarks are `Bookmarks (3)` with the count parenthesised, not "3 Bookmarks."

### Casing
- **Title Case** for screen titles, dialog titles, section headers, button labels: *Reading Settings, Privacy Shelf, Start Reading, Reset to defaults*. Note "to defaults" — the **first word + proper nouns** get the cap, helper prepositions don't.
- **Sentence case** for subtitles, descriptions, hints: *"Chapter seek and position"*, *"Save reading data as JSON"*, *"Adjust the reading light."*
- **lowercase units** in tight chips: `min`, `pt`, `%`.

### Vocabulary — Nyan-specific
- "Bookshelf," "Public Shelf," "Privacy Shelf" — not "Library."
- "Highlights & Notes," not "Annotations."
- "Warmth," not "Color temperature."
- "Page Turn Mode" → values are **Tap**, **Swipe**, **Disabled** (verb noun pairs).
- "Continue Reading" / "Start Reading" — never just "Read" or "Open."
- "Cream Light" / "Sumi Dark" — themes are named after materials, never "Light/Dark."
- Typography density: **Compact / Standard / Comfortable** (not Small/Medium/Large).
- Warmth level: **Low / Medium / High** (single word, sentence-cased in chips).

### Emoji & decoration
- **One mascot, used sparingly.** `appTitle` in the English locale is literally `'Nyan Read ฅ^•ﻌ•^ฅ'`. That's the only emoji-like decoration anywhere in the product; we use it on the marketing splash and the about screen only.
- **No Unicode dingbats inline** (no `✓`, `→`, `★` inside copy). When you need a checkmark, it's a Material icon `check_rounded`.
- **No exclamation marks** except in friendly recoveries: *"Successfully restored {n} books!"* That single exception is from the source.

### Sample copy
| Where | Source string |
|---|---|
| App title | `Nyan Read ฅ^•ﻌ•^ฅ` |
| Reading hello | `Enjoy reading time` |
| Empty shelf | `Bookshelf is waiting for stories` / `Import a book to start reading` |
| Empty Privacy | `This private space is empty.\nSelect books from the public shelf and tap the Lock icon to move them here.` |
| No bookmarks | `Passages worth returning to will gather here.` / `Tap the bookmark while reading to save one.` |
| Reset all | `Reset all reading appearance?` / `This restores defaults for font, spacing, theme, warmth, and brightness.` |
| File copy success | `File path copied to clipboard` |

When writing new copy, **read three or four of those out loud** before you commit. If yours sounds louder, more clinical, or more "SaaS," rewrite it.

---

## Visual foundations

This section answers the questions in the design-system brief. **Every choice below is enforced by `AGENTS.md §4`** in the source repo; deviations should be flagged.

### Color philosophy
- **No pure `#FFFFFF`, no pure `#000000`.** All "white" is cream (`#F6F3EA` background, `#FFFDF8` surface). All "black" is warm ink (`#3F3A34`) in light mode, or ink-night green-black (`#181B16`) in dark.
- **One strong color: matcha green** (`#98A27C` and the deeper `#7E8B61`). It is the only thing allowed to fill a button, the only thing allowed to draw a progress bar, the only thing allowed to be a "selected" border.
- **Orange (`#F2BE7E`) is reserved** for warmth-related semantics: night-mode warmth slider track, warning state. It is *never* a brand color.
- **Highlight pens are a separate fixed palette** of five soft pastels (yellow / green / blue / pink / orange). They don't shift between themes — same hex in Cream Light and Sumi Dark.

### Typography
- **UI face:** Noto Sans SC (CJK Sans). Latin glyphs in the same family render cleanly so we don't need a second roman face.
- **Reading face (optional):** Source Han Serif SC — Adobe's open-source CJK serif. Used **only inside the reader canvas** when the user picks serif mode.
- **Scale: only 5 sizes.** Display `32`, Title `24`, Section `20`, Body `16`, Meta `13`. No `14`, no `18`, no `36`. If you find yourself wanting an in-between size, restructure the hierarchy instead.
- **Weight: only 3.** `400` regular, `500` medium, `600` semibold. `700+` is rejected. Display + Title + Section + section-headers use `600`; buttons + labels use `500`; everything else is `400`.
- **Letter-spacing.** Display `-0.4`, Title `-0.15`. The olive section header gets `+0.22` (subtle wide-tracking on the matcha mini-caption).

### Spacing
- **8-point grid + the 4 / 12 / 20 exceptions** (`4, 8, 12, 16, 20, 24, 32`). `10`, `14`, `18`, `22` are banned. The single hardcoded UI dimension that escapes the grid is `44px` — `minTapTarget` — applied to every tappable thing.
- Padding inside cards is **always `16`** (or `12` for compact). Gap between cards in a list is **`14`** for the shelf, **`8`** elsewhere. Grid gutters on the shelf are `14 × 14`.

### Backgrounds
- **No images, no patterns, no gradients.** The cream paper background (`#F6F3EA`) is uniform and intentional. Layering is done through *color steps* (background → surface-muted → surface), not blur, glass, or texture.
- Reader canvas can swap to 4 paper variants (Cream, Sepia, Sumi, Charcoal). Those are **flat color fills** too; the only "warmth" comes from an overlay tint applied by the brightness orchestrator.

### Animation
- **Slow, paper-soft.** The default curve is `--ease-paper` = `cubic-bezier(0.33, 0.9, 0.36, 1)`. Durations are short and named: `--dur-chrome 280ms` (bars reveal/dismiss), `--dur-grow 320ms` (the dock growing into a sheet, incl. its `max-height` and the `24→28` radius ease), `150–240ms` for small control state changes.
- **No bounces, no springs, no overshoots.** No physics-based motion anywhere.
- **No page-turn haptics.** Sliders fire `HapticFeedback.lightImpact` at most once per drag.

### Hover, press, focus
- Web target hover (this design system) uses **opacity 0.88 + 1px lift via transform on plain icon buttons**, or background tint shift on InkWell-style rows. Native InkWell is the source-of-truth interaction.
- Press states are **a soft darken** (`primary-deep` on a primary button, or the InkWell ripple in surface-muted on rows). No shrink, no scale animation.
- Selected state on **pill / option chips** is uniquely *outline-only* — the unselected state has a recessed muted fill; the selected state drops the fill to transparent and adds a `primaryDeep` border + `primaryDeep` text, so the chip "lifts off the track." Chips are squared at `--r-chip` (12), the deepest member of the concentric radius family — **no longer stadium pills**. This is the project's signature interaction (`AGENTS.md §4.3`).

### Borders, dividers, hairlines
- Divider color is the warm-toned `#E5DED2` (light) / `#3A3F3A` (dark). It is **never grey**.
- Hairlines on grouped cards are `0.72px` at `16%` divider alpha (light) — barely visible, optical only. Standard cards use `0.5px` at `30%`.
- **Cards never share a divider between them** — separation is done by background-color step, not by `<hr/>`.

### Shadows
- Two shadow recipes, both ≤12px blur, ≤5% alpha:
  - **lightCard** — `0 4px 12px @ 4% + 0 2px 6px @ 2%` — the standard floating-chrome lift (dock, top bar, sheets, dialogs, popovers).
  - **subtle** — `0 2px 8px @ 5%` — secondary overlays (toasts).
  - **settingsGrouped** — `0 2px 10px @ 1.4%` — ultra-quiet lift for grouped settings cards.
- **Sumi Dark — elevation by tone, not drop shadow (revised v3).** The old rule ("zero shadow in dark") flattened the UI: cards sat one tonal step off the page with no shadow and a near-invisible border, so nothing read as a distinct plane. Dark mode now uses a deliberate **elevation ladder** — surfaces step *lighter* as they rise — finished by a luminous hairline ring + a 1px inset top catch-light, both folded into the shadow tokens so they apply system-wide:
  - **Ladder:** `bg #181B16` (page void) → `surfaceMuted #1D211B` (recessed track) → `surface #242922` (cards/bars, +1) → `surfaceRaised #2E342B` (dialogs/sheets/popovers, highest). Adjacent layers keep a visible ~5–8 L\* gap.
  - **lightCard (sumi):** `0 0 0 0.75px divider@88%` ring + `inset 0 1px 0 white@5%` catch-light + `0 10px 24px @44%` + `0 3px 8px @34%` ambient.
  - **subtle / settingsGrouped (sumi):** same ring at lower alpha + a single soft ambient shadow.
  - Floating chrome still carries the `--chrome-edge` ring (`--nyan-divider` in Sumi); the scrim deepens to `rgba(0,0,0,0.58)`.
- **You may never write a custom `box-shadow`**. If you need a new one, define a token first. Do **not** opt a card out of shadow in dark (`dark ? "none"`) — the tokens now carry the correct dark elevation.

### Transparency & blur — the depth response
- When a sheet or dialog rises, the page behind it gives **one consistent response**, defined by tokens: a warm-ink scrim `--scrim` (`rgba(40,36,30,0.34)` light, deepened to `rgba(0,0,0,0.58)` in Sumi), a **gentle `--scrim-blur` of 2px**, and the page recedes to `--page-recede` (`scale(0.97)`). This is the only place blur is used, and it's deliberately slight — a soft recede, **not frosted glass**. The aesthetic is paper, not iOS.
- Nothing else uses `backdrop-filter`. No glass surfaces, no heavy blur.

### Imagery
- **Cool-warm cream**, never saturated. Book covers (when present) are shown 1:1, rounded `20px`, with a `0.5px @ 30%` divider hairline. **There are no fallback book-cover photos** — covers absent use the matcha "open book" logo mark on a surface-tinted `12%` matcha wash.
- Generic full-bleed photography is **not part of this product**. If a marketing context demands one, prefer washed-out warm tones, no people, paper / desk subject matter.

### Corner radii (recap)
A **concentric family**, scaling with elevation: `--r-chip 12` (option chips, nested deepest) · `--r-control 14` (segmented-control track, tinted list-row icon chip) · `--r-card-nested 16` (cards inside a sheet, inputs, buttons) · `--r-dock 24` (the resting dock / floating bars) · `--r-sheet 28` (the dock grown into a sheet; all bottom sheets + dialogs). A card nested inside a sheet rounds just enough that its arc sits parallel to the parent's. **Nothing is a stadium pill, and nothing but the reading canvas touches a screen edge.**

### Layout rules
- Mobile-first; everything is designed for 360–414dp width portrait. Tablet/desktop reuses the same tokens with a max content width.
- **Everything floats; nothing is welded.** Every bar, dock, sheet, and dialog insets `--inset` (12px) from the screen edge, is rounded on all four corners, and lifts on the single `lightCard` shadow. The only thing that reaches a screen edge is the reading canvas (and the full-screen security PIN takeover).
- **Sheets vs. destinations.** A bottom sheet is for transient adjustments to the current context (settings, sort, import, read-aloud). Anything you *go to and browse* is a destination that pushes a full page, not a sheet — e.g. **Bookmarks** and **Highlights & Notes** slide in as pages with a back arrow. The rule: *adjust → sheet; browse → page.*
- Sticky bottom CTA is rare. The FAB (rounded-square `16px`, matcha-deep) is the import affordance on the bookshelf only.
- Status bar matches the page background (no separate chrome tint).

---

## One Paper — the reader chrome model

The reader's chrome is the spine of the system. It used to read like two apps stitched together — a flat, edge-to-edge bottom control bar fighting a floating, high-radius settings card. **One Paper** unifies them: the control bar and the settings/chapters sheet are *the same object at two sizes*.

- **The dock is the collapsed sheet.** A single floating paper panel sits inset at the bottom (`--r-dock 24`). Tapping **Settings** or **Chapters** doesn't swap views — the same panel **grows upward** into a sheet (radius eases to `--r-sheet 28`, `max-height` animates over `--dur-grow`), and the **dock footer stays pinned** at its base with the tapped action lit in matcha. This is implemented once as `OnePaperDock` + `DockFooter` in `components.jsx`; the live reader and every spec mock render the same component.
- **The dock footer** carries, in order: a **chapter stepper** (`‹ ›` carets) flanking a thin progress bar, then the **three actions** — Chapters / Bookmarks / Settings. Chapter stepping lives here and nowhere else; there is no standalone progress card.
- **Settings body is shared.** The Display / Text / Theme controls are one component (`ReaderSettingsBody`) rendered inside the grown dock — the same body the standalone preview sheet uses.
- **Depth response** when the dock grows: the page recedes + dims + blurs (see *Transparency & blur*). Tapping the dimmed page or the grabber collapses it back to a dock.
- **Brightness** is not in the dock. It has two One Paper affordances: an **edge gesture** (vertical drag on the left third of the page, surfacing a slim floating capsule) for immersive use, and a **top-bar sun popover** (one inline `NyanSlider`, no full sheet) for discoverability.
- **Immersive first.** With no interaction the reader shows only the canvas; a tap reveals the floating top bar + dock, which never weld to the edge.

---

## Iconography

- **Phosphor Regular** is the icon system. ~1.5 px stroke, MIT-licensed, ~1,300 glyphs in 6 weights. Sleeker than Material Round, pairs better with Noto Sans SC ink weight, keeps the paper-book calm. Load via CDN:
  ```html
  <link rel="stylesheet" href="https://unpkg.com/@phosphor-icons/web@2.1.1/src/regular/style.css" />
  <!-- Optional fill weight for set bookmarks + matcha selected check -->
  <link rel="stylesheet" href="https://unpkg.com/@phosphor-icons/web@2.1.1/src/fill/style.css" />
  <i class="ph ph-book-open"></i>
  <i class="ph-fill ph-bookmark-simple"></i>
  ```
- **Naming convention.** The JSX `<Icon name="..." />` component in the UI kit accepts Material-style snake_case names (`menu_book`, `chevron_right`, `bookmark_border`) and maps them to Phosphor's kebab-case equivalents internally. This keeps screen code legible to anyone reading the upstream Flutter source.
- **Sizes.** 16 / 18 / 20 / 24 / 26 pt depending on context. Stroke weight is constant; mass changes via the `size` prop.
- **Fill is reserved.** Only two icons ever use Phosphor's fill weight — toggle by swapping the parent class from `ph` to `ph-fill` (the leaf icon name stays the same): `<i class="ph-fill ph-bookmark-simple">` when a bookmark exists on the page, and `<i class="ph-fill ph-check">` for the matcha selected-card check. Everything else uses the default outline weight.
- **No emoji.** No Unicode dingbats. No custom SVG illustrations besides the Nyan cat logo. If Phosphor doesn't have a glyph, omit the icon and rely on text — never invent one.

### Source-fidelity note

The Flutter source uses Material `Icons.*_rounded` from the built-in font. Designs produced with this design system will look **sleeker than live screenshots** of the running app — that is intentional. For UI bug repros, screenshot annotations, or other pixel-parity work, load both icon fonts and use Material Round explicitly:
```html
<link rel="stylesheet" href="https://fonts.googleapis.com/icon?family=Material+Icons+Round" />
<span class="material-icons-round">menu_book</span>
```
The "Brand — Iconography" preview card shows all three weights (Material Round, Phosphor Regular, Phosphor Light) side-by-side for reference.

---

## Token deviations from upstream

This design system **intentionally diverges from the source `lib/core/theme/nyan_colors.dart`** in one well-scoped way: foreground inks and the matcha primary have been darkened (light) / lightened (dark) just enough to clear WCAG&nbsp;AA on their respective surfaces. The change is surgical — surfaces, dividers, highlight pens, radii, spacing, shadows, type are all unchanged.

### What changed and why

| Token | Upstream | This system | Why |
|---|---|---|---|
| `--nyan-text-secondary` (cream) | `#8A8377` | **`#5F5950`** | 3.69:1 → 6.81:1 AA. Source value fails AA for body text on cream surface. |
| `--nyan-text-muted` (cream) | `#B0ACA5` | **`#706A5A`** | 2.22:1 → 5.30:1 AA. Source value fails every WCAG tier. |
| `--nyan-primary` (cream matcha) | `#98A27C` | **`#6E7A55`** | 2.65:1 → 4.51:1 AA. Source matcha-on-white-button fails for any text it carries. |
| `--nyan-primary-deep` (cream) | `#7E8B61` | **`#5A6644`** | 3.59:1 → 6.04:1 AA. Used for selected outlines + accent text. |
| `--nyan-success` (cream) | `#6B8E23` | **`#4F6B1E`** | 3.74:1 → 5.98:1 AA. |
| `--nyan-text-secondary` (sumi) | `#AAA396` | **`#B4AC9F`** | 6.51 → 7.25:1 AAA. Tiny lift; reads better on warm background. |
| `--nyan-text-muted` (sumi) | `#8F8A84` | **`#9C968D`** | 4.76 → 5.56:1. Clears AA on **both** background and surface (source value fails AA on surface at 3.86). |
| `--nyan-primary` (sumi) | `#93A07C` | **`#A9B690`** | 5.87 → 7.59:1 AAA. |
| `--nyan-primary-deep` (sumi) | `#9AAD86` | **`#B3C29A`** | Lifted in parallel. |

### What stayed identical

- All surfaces (`background`, `surface`, `surfaceMuted`) — the paper feel is the brand.
- Primary ink (`#3F3A34` light, `#E8E1D5` dark) — already AAA.
- Divider, all 5 highlight pens, error palette, reader paper variants.
- All radii, spacing, shadows, typography.

### Source-fidelity escape hatch

If you need pixel-parity with the live Flutter app — for example, a screenshot annotation or a marketing comp that has to match a captured screen — every original token is preserved alongside the AA values:

```css
/* Use these only when the brief is "match the live app exactly" */
var(--nyan-text-secondary-src)   /* #8A8377 */
var(--nyan-text-muted-src)       /* #B0ACA5 */
var(--nyan-primary-src)          /* #98A27C */
var(--nyan-primary-deep-src)     /* #7E8B61 */
var(--nyan-success-src)          /* #6B8E23 */
```

The AA values are the **default** because the upstream's own `AGENTS.md` says *"long-time reading-friendly"* and *"anything causing eye-strain is a Bug, even if functional."* Failing-contrast text fits that definition. The upstream maintainer may want to upstream these changes after a quick visual review.

### Visual character preservation

The new values stay in the **warm-olive / warm-brown** hue family — we darkened/lightened luminance only. Side-by-side, the system reads as a slightly more confident, slightly less hazy version of the original; the Muji × paper × matcha character is intact. Compare:

- Old matcha `#98A27C` → New matcha `#6E7A55`: same olive temperature, ~12 L\* darker. Still distinctly matcha, not olive-brown.
- Old cream-muted `#B0ACA5` → New `#706A5A`: same warm-grey, ~25 L\* darker. Reads as ink, not fog.

---



The UI face is bundled and works fully offline. The reading-mode serif is **not** — and likely won't be in this design system, for reasons worth documenting:

| Family | Status |
|---|---|
| **Noto Sans SC** (UI, weights 400/500/600) | ✅ Bundled — `assets/fonts/NotoSansSC-{Regular,Medium,SemiBold}.ttf` |
| **Source Han Serif SC** (reading serif, 400/600) | ⚠️ **Substitution flag** — falls back to Songti SC (macOS/iOS) → STSong / SimSun (Windows) → Georgia (web). |

### Why the serif isn't bundled

1. **The upstream Nyan Read repo doesn't ship the font either.** Its own `assets/fonts/README.md` states *"字体文件未纳入 Git 仓库（体积原因）"* — files are git-ignored; the maintainer instructs contributors to download them from Adobe manually. The 206 KB file in the repo's font folder is a placeholder (HTML stub), not a real OTF.
2. **Adobe's official files are 24 MB each** — `SourceHanSerifSC-Regular.otf` (24,543,332 B) + `SemiBold.otf` (24,700,532 B). Bundling ~48 MB of fonts into a design-system project is a non-starter.
3. **The right fix is subsetting**, not bundling. The upstream repo ships `scripts/subset_fonts.py` which uses `fonttools` + GB2312 to produce ~2 MB subsets. If serif fidelity matters for your use case, run that script locally and upload the resulting `assets/fonts/subset/SourceHanSerifSC-*.otf` here.

Until then, the fallback chain in `--font-serif` produces a *visually convincing* CJK serif on every major platform — same letterforms, slightly different metrics. The reader-canvas preview, the reader Theme picker's `Aa 永` specimens, and the `font-families` card all render the substitution gracefully.

---

## Quick-start for agents

1. **Always** include `colors_and_type.css` at the top of any HTML you make.
2. **Read tokens, never invent.** If you need a new color/shadow/radius/spacing, stop and ask — adding one is a design-system change, not a feature.
3. For component implementations, look first in `components/` (split into `primitives` / `headers` / `surfaces` / `cards` / `reader`). It contains plain-JSX recreations of: `NyanPrimaryButton`, `NyanInfoCard`, `NyanBookGridCard`, `NyanContinueReadingCard`, `SegmentedTabControl`, `NyanBookmarkCard`, `NyanSectionHeader`, `NyanPageHeader`, `NyanEmptyState`, `NyanActionSheetRow`, `NyanBottomSheet`, `PillButton` (the squared outline-on-select chip), `NyanListRow`, `NyanResponse` (the shared action-feedback toast — completed / failed / skipped / in-progress), and the **One Paper reader chrome**: `OnePaperDock` + `DockFooter` (dock that grows into a sheet, with the chapter stepper + 3 actions), `ReaderSettingsBody` (Display/Text/Theme), and `ReaderChapterList`. Build reader-surface mocks by composing these, not by hand-rolling a sheet.
4. **Pages are mobile-first.** Default to a 390 × 844 canvas (iPhone-ish) wrapped in a phone frame for any mock you produce; the kit shows how.
5. When in doubt about voice: read the *Sample copy* table again.

