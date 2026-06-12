# Nyan Read DS — Audit: E-book Reader Readiness & Code Quality

**Scope:** all `.md`, `.jsx`, `.html`, `.css` in this repo, plus the design-system compiler report.
**Date:** 2026-06-10

Verdict up front: the system is **strong on visual language and reader chrome** (One Paper dock, tokens, voice) but has **(1) real component gaps for a complete local e-book reader, (2) measurable doc↔code drift in three of four MD files, and (3) a structural flaw — zero components are registered with the DS compiler**, so consuming projects currently get tokens and cards but no usable component namespace.

---

## TASK 1 — Component & Code Gaps for a Local E-book Reader

### 1A. MISSING — kit components that exist only as screen-level code (not reusable)

These are implemented inside `screens/bundle*.jsx` and are therefore unreachable as kit parts. Anyone building a new reader surface must copy-paste from a bundle:

| Needed kit component | Where it's trapped today | Why it's needed |
|---|---|---|
| `NyanSearchField` / text input | `SearchField` in `screens/bundle3.jsx` | There is **no text-input primitive at all** in `components/`. Search, note editing (U02), PIN, rename — all need one. |
| `NyanDialog` (centered confirm) | ad-hoc in mocks (e.g. "Reset all reading appearance?") | Sheets cover "adjust"; there is no kit surface for destructive confirms (delete book, reset settings). |
| `HighlightSwatchRow` (5-pen picker) | `HL_SWATCHES` in `screens/bundle1.jsx` | Highlighting is a core e-book flow; the pen palette is tokenized but the picker isn't a component. |
| `TextSelectionMenu` | `screens/bundle2-screens.jsx` | Copy/Highlight/Note popover — core reader interaction. |
| `NyanProgressBar` | re-implemented **inline ≥5 times** (`NyanBookGridCard`, `NyanContinueReadingCard`, `DockFooter`, `NyanSplash`, U15) with subtly different track colors | Reading progress is the product's most repeated visual. Five hand-rolled copies = guaranteed drift. |
| `BookListRow` (list-view shelf row) | `screens/bundle3.jsx` | README promises grid/list toggle; only the grid card is in the kit. |
| `PinPad` / `PinDots` | `screens/bundle4.jsx` | Privacy Shelf is a headline feature (Pro tier). |
| `TTSSheet` / read-aloud mini-player | `screens/bundle4.jsx` | U17 exists as a mock; not composable elsewhere. |
| `NyanCheckbox` | inline `<svg>` check in `NyanBookGridCard` | Multi-select (U21) uses a one-off; settings will need checkboxes. |

### 1B. MISSING — flows/components with no representation anywhere

- **In-book search.** U06 is *bookshelf* search. There is no UI for "search inside this book" (results list with excerpt + chapter + jump). For TXT/EPUB readers this is table-stakes.
- **PDF-specific affordances.** The product reads PDF (per README line 1), but there is no zoom control, page-thumbnail strip, "Go to page N" input, or fit-width/fit-page toggle. The One Paper dock model has no documented answer for PDF.
- **Book metadata edit** (rename title/author, change cover) — import exists (U11), editing doesn't.
- **Skeleton/loading placeholders** for shelf and import parsing — only the `nyan-spin` keyframe exists. Long EPUB parses need a calm loading treatment per the "long-session friendly" doctrine.
- **First-run / onboarding** and **About screen** (the README says the mascot title appears "on the about screen only" — there is no About screen).
- **Reading statistics** — optional, but `alarm`/`schedule` icons are mapped, suggesting it was planned.

### 1C. ENHANCE — components that exist but are under-specified for production

- **`NyanPrimaryButton`** (`components/primitives.jsx`): no `disabled`, no `loading` state. An import CTA mid-parse has no honest state to show.
- **`PillButton`**: no `disabled`. (Page Turn "Disabled" option ≠ a disabled chip.)
- **`NyanSlider`**: pointer-only. No keyboard arrows, no `step`, no ARIA (`role="slider"`, `aria-valuenow`). Brightness/font-size are accessibility-critical controls.
- **`NyanBottomSheet`** (`components/surfaces.jsx`): `if (!open) return null;` — **exit animation is impossible**; the sheet pops out of existence, violating the `--dur-chrome` dismiss doctrine the README specifies. Needs a mounted-while-closing pattern.
- **`NyanOptionSheet`** (`components/surfaces.jsx`): **functionally broken as an input** — every option does `onClick={onClose}`; there is **no `onSelect(i)` prop**, so the "single bottom-sheet for pick-one" can never change a value. Cosmetic-only today.
- **`Icon`**: `onClick` on an `<i>` (no button semantics, no `aria-label`); the fill rule is the fragile special case `name === "bookmark"` instead of a `fill` prop. DockFooter's default `highlighter` action only works by accident of the kebab-case fallthrough.
- **Tap-target doctrine violations** — README/tokens declare `--min-tap: 44px` as "the single hardcoded dimension," yet: `stepBtn` 34px (`reader.jsx`), DockFooter stepper 36px, `ShelfToolBtn` 40px, `NyanSwitch` 44×26. The system breaks its own hardest rule in four of its most-tapped controls.
- **i18n hardcoding** — the product is bilingual, but components embed English: `"Chapter {n} of {n}"`, `"Previous chapter"` (`DockFooter`), `"Continue Reading"` (`NyanContinueReadingCard`), `"Opening your shelf…"` (`NyanSplash`). These should be props with defaults.

### 1D. FIX — concrete bugs / doctrine violations in code

1. **`ThemePanel` swatches diverge from tokens** (`components/reader.jsx`): hard-coded `#FFFCF5 / #F5ECD8 / #302D2B / #1B1A19` vs the actual tokens `--reader-bg-cream #F7F5EF / --reader-bg-sepia #EDE3C7 / --reader-bg-sumi #262422 / --reader-bg-charcoal #141312`. **All four swatches preview colors the reader will not render.**
2. **`ReaderBg` hard-codes theme colors** (`screens/_chrome.jsx`): `#262422`, `#F7F5EF`, `#E5DED3`, `#4A453E` instead of `var(--reader-bg-*)` / `var(--reader-ink-*)`. Token changes won't propagate to every reader-backdrop mock.
3. **Pure `#FFFFFF` in product UI** (`components/cards.jsx`, selection check `stroke="#FFFFFF"`) — directly violates the №1 hard rule "No pure #FFFFFF." (The catch-light `#FFFFFF` color-mixes in `colors_and_type.css` are defensible as physics; an SVG stroke is not.)
4. **`NyanSwitch` no-op `color-mix`**: `color-mix(in srgb, var(--nyan-divider) 100%, transparent)` ≡ `var(--nyan-divider)`.
5. **Off-scale typography everywhere.** The doctrine is "only 5 sizes"; the components use `9, 10, 10.5, 11, 11.5, 12, 12.5, 13.5, 14, 15, 17, 18, 22, 26, 28px`. Either the doctrine needs an honest "component micro-scale" amendment, or the components need sweeping. Right now the docs lie about the code.
6. **Inline SVG checkmark** in `NyanBookGridCard` contradicts "No custom SVG… if Phosphor doesn't have a glyph, omit" — `ph-check` exists and is used elsewhere for the same semantic.

---

## TASK 2 — Doc↔Code Consistency, Architecture, Structure

### 2A. Doc-to-Code drift (specific, per file)

**`SKILL.md` — stale + corrupted. Highest-priority doc fix.**
- Line 13 contains a **corrupted sentence fragment**: `…the Flutter widget map.Card`, `NyanBookmarkCard`, `PillButton`, etc.).` — a botched merge artifact.
- "**Sumi Dark has no shadows**" — contradicts `colors_and_type.css` (v4 dark shadow tokens) and `HANDOFF-flutter.md` ("the old rule … is **retired**").
- "Only 5 corner radii (14, 16, 20, 24, 28). **Pill buttons override with stadium**" — contradicts README ("**no longer stadium pills**") and the One Paper family that adds `--r-chip: 12`.
- "Only 5 type sizes" — the CSS now ships 6 (`--fz-caption: 11px` is documented as load-bearing).

**`HANDOFF-flutter.md` — one revision behind the tokens.**
- §2 Sumi values are the **v3 ladder** (`bg:#181B16 surface:#242922 muted:#1D211B raised:#2E342B divider:#3D443A textMuted:#9A948B`), but `colors_and_type.css` ships **v4** (`#14170F / #31372E / #1A1E15 / #3E453A / #4C5448 / #A39D93`). A Flutter dev following this file ports the wrong dark theme.
- §2 lists `error:#A85A38`; the CSS token is `--error-primary: #9C5C49`.
- §1 says "the **19** screen compositions"; there are **21** mocks (U01–U21).

**`README.md`**
- One Paper section: "implemented once as `OnePaperDock` + `DockFooter` in **`components.jsx`**" — stale reference to the pre-split monolith.
- One Paper + `components/README.md` both say the dock footer carries "**the three actions** — Chapters / Bookmarks / Settings", but `DockFooter`'s default is **four** (adds Highlights). Pick one; today the spec and the default render differ.
- Vocabulary section mandates chapter counters as `12 / 184 chapters`; `DockFooter` renders `Chapter 1 of 12`.
- Index tree omits `mocks/`, `brand/`, `HANDOFF-flutter.md`; the `preview/` list omits 3 real files (`option-sheet.html`, `response-feedback.html`, `shelf-toolbar.html`); the assets list omits `nyan_mark_v2.png` + the 3 app icons.
- Sources section says Source Han Serif **Regular + SemiBold** were "copied here under `assets/fonts/`" — they are **not in the repo at all**, and the `@font-face` actually references Regular + **Medium**. Three mutually inconsistent statements about one font.

**`components/README.md`**
- Table puts `NyanFAB` in `primitives.jsx` — it lives in **`surfaces.jsx`**.
- Table puts `SegmentedTabControl` in `headers.jsx` — it lives in **`primitives.jsx`**.
- Export list omits `NyanOptionSheet`, `Knob`, `DisplayPanel`, `TextPanel`, `ThemePanel`, `ReaderSettingsBody`, `ReaderChapterList`, `DockFooter` — half of `reader.jsx`'s actual `window` exports are undocumented.

### 2B. Architecture & clean-code smells

1. **Zero compiler-registered components.** `check_design_system` reports **Components: (none)** — no `<Name>.d.ts` files exist, so nothing is exposed on `window.NyanReadDesignSystem_019e2f` and consuming projects can't use the bundle. The whole `components/` library is invisible to the DS pipeline. Every public component needs a sibling `.d.ts`.
2. **No starting points / templates.** `templates/` doesn't exist; consumers start from a blank file instead of a wired-up phone-frame screen.
3. **Two parallel component vocabularies** — the acknowledged-but-real duplication between `screens/_chrome.jsx` and `components/`: `PageHdr`↔`NyanPageHeader`, `SectionHdr`↔`NyanSectionHeader`, `RowGroup`↔`NyanRowGroup`, `ListRow`↔`NyanListRow`, `NyanToggle`↔`NyanSwitch`, `NyanSplash`↔`SplashScreen` (bundle2). The `_chrome` versions are *richer* (icon tiles, chevrons, indent), so screens use them and the kit atoms rot. Merge: promote the rich props into the `Nyan*` kit versions, delete the `_chrome` twins.
4. **Two radius token systems coexist**: legacy `--radius-small/input/card/panel/sheet` and One Paper `--r-chip/control/card-nested/dock/sheet`. They disagree (`--radius-small: 14 /* tab capsule, chip */` vs `--r-chip: 12`). `NyanInfoCard`/`NyanListRow` consume the legacy set; `reader.jsx` consumes One Paper. Deprecate `--radius-*` (alias them) and migrate.
5. **Bundle files named by number, not domain.** `bundle1…bundle4` tells you nothing; `bundle2-screens.jsx` breaks even that convention. `bundle3.jsx` is **857 lines** spanning two unrelated domains (bookshelf + annotations) and also hosts shelf **data fixtures** (`BOOKS`, `SEARCH_RECENT`) inline.
6. **21 mock files duplicate ~30 lines of identical boilerplate each** — the `Frame` component and the `.screen-head/.screen-wrap/.frame*` CSS are copy-pasted into every `mocks/U*.html`. One edit = 21 files. Extract `mocks/_mock-chrome.css` + put `Frame` in `screens/_chrome.jsx`.
7. **No prop contracts anywhere.** No `.d.ts`, no PropTypes, no JSDoc `@param`. `OnePaperDock` silently spreads `{...footer}` into `DockFooter` — the implicit prop pass-through is undiscoverable without reading source.
8. **Magic numbers despite the "never hard-code" rule** — raw `borderRadius: 12/14/16`, ad-hoc `color-mix` alpha percentages (9%, 12%, 13%, 16%, 44%…) repeated across files with near-miss values (icon-tile tint is 8%, 9%, 10%, and 13% in four places). The tint scale deserves tokens (`--tint-faint/--tint-soft/--tint-active`).
9. **Misplaced/odd files**: `screenshots/` (working artifacts: `dark-after.png`, `u14-pickers.png`) committed at root — move under `_scratch/` or delete; `brand/nyan-mark.jsx` is component source living outside `components/`; mock filename `U17 - Read Aloud -TTS-.html` uses `-TTS-` as parenthesis surrogate.

### 2C. Recommended folder structure

```
nyan-read-design-system/
├── README.md                     ← index regenerated; stale refs fixed
├── SKILL.md                      ← rewrite hard-rules to match v4 tokens
├── HANDOFF-flutter.md            ← resync Sumi v4 + error palette
├── styles.css                    ← rename of colors_and_type.css (compiler-canonical name)
│
├── assets/
│   ├── fonts/
│   └── images/
│
├── brand/
│   ├── nyan-mark.jsx
│   └── Nyan Mark - One Paper.html
│
├── components/
│   ├── README.md                 ← corrected file↔export map
│   ├── primitives/
│   │   ├── Icon.jsx + Icon.d.ts
│   │   ├── NyanPrimaryButton.jsx + .d.ts      (+ disabled/loading)
│   │   ├── PillButton.jsx + .d.ts
│   │   ├── NyanSwitch.jsx + .d.ts
│   │   ├── NyanSlider.jsx + .d.ts             (+ ARIA/keyboard)
│   │   ├── NyanCheckbox.jsx + .d.ts           (NEW)
│   │   ├── NyanProgressBar.jsx + .d.ts        (NEW — kill 5 inline copies)
│   │   └── NyanTextField.jsx + .d.ts          (NEW — search/note/PIN input)
│   ├── navigation/
│   │   ├── NyanPageHeader.jsx, NyanSectionHeader.jsx,
│   │   ├── SegmentedTabControl.jsx, ShelfToolbar.jsx   (promoted from _chrome)
│   ├── surfaces/
│   │   ├── NyanInfoCard, NyanListRow, NyanRowGroup, NyanEmptyState,
│   │   ├── NyanBottomSheet (animated dismiss), NyanOptionSheet (+onSelect),
│   │   ├── NyanDialog (NEW), NyanActionSheetRow, NyanFAB, NyanResponse
│   ├── cards/
│   │   ├── NyanBookGridCard, NyanBookListRow (promoted),
│   │   ├── NyanContinueReadingCard, NyanBookmarkCard
│   └── reader/
│       ├── OnePaperDock, DockFooter, ReaderSettingsBody (+panels/Knob),
│       ├── ReaderChapterList, ReaderParagraph,
│       ├── TextSelectionMenu (promoted), HighlightSwatchRow (promoted),
│       ├── TTSSheet (promoted), PinPad (promoted),
│       └── InBookSearch (NEW), PdfControls (NEW)
│
├── screens/                      ← thin compositions ONLY; no kit-grade widgets
│   ├── _chrome.jsx               ← Shell/ThemeWrap/ReaderBg/Frame only
│   ├── _fixtures.js              ← BOOKS, TOC_DATA, SEARCH_*, TTS_PARAS…
│   ├── reader.jsx                ← was bundle1 + bundle2 reader screens
│   ├── bookshelf.jsx             ← was bundle3 (shelf half)
│   ├── annotations.jsx           ← was bundle3 (bookmarks/highlights half)
│   └── settings.jsx              ← was bundle4
│
├── mocks/
│   ├── _mock-chrome.css          ← shared head/frame styles (extracted ×21)
│   └── U01…U21 *.html
│
├── preview/                      ← @dsCard token/component cards (as-is)
└── templates/                    ← NEW — at least one starting point
    └── phone-screen/
        ├── index.html            ← <!-- @template … --> wired phone frame
        └── ds-base.js
```

---

## Prioritized fix list

| P | Item | Files |
|---|---|---|
| **P0** | Add `.d.ts` for every public component (compiler shows 0 registered) | `components/*` |
| **P0** | `NyanOptionSheet` can't select (`onClick={onClose}`, no `onSelect`) | `components/surfaces.jsx` |
| **P0** | `ThemePanel` swatch hexes ≠ `--reader-bg-*` tokens (all 4 wrong) | `components/reader.jsx` |
| **P0** | SKILL.md corrupted line + 3 contradicted hard rules | `SKILL.md` |
| **P1** | HANDOFF Sumi v3 values vs CSS v4; error hex; "19 screens" | `HANDOFF-flutter.md` |
| **P1** | Extract `NyanProgressBar`; kill 5 inline progress implementations | cards/reader/_chrome/bundles |
| **P1** | Promote SearchField, TextSelectionMenu, HL swatches, PinPad, TTSSheet, BookListRow into kit | `screens/bundle*` → `components/` |
| **P1** | Tap targets <44px (stepBtn 34, stepper 36, toolbar 40) vs `--min-tap` doctrine | primitives/reader/_chrome |
| **P1** | Bottom-sheet unmount-on-close = no exit animation | `components/surfaces.jsx` |
| **P2** | Merge `_chrome` twins into kit atoms; one source of truth per pattern | `screens/_chrome.jsx` |
| **P2** | Deprecate `--radius-*` in favor of `--r-*`; fix `--radius-small` comment | `colors_and_type.css` |
| **P2** | Extract mock boilerplate (`_mock-chrome.css` + shared `Frame`) | `mocks/*` ×21 |
| **P2** | Rename bundles by domain; split bundle3; move fixtures to `_fixtures.js` | `screens/*` |
| **P2** | i18n: lift hardcoded strings to props; decide `Chapter X of Y` vs `X / Y chapters` | reader/cards/_chrome |
| **P3** | Add missing flows: in-book search, PDF controls, dialog, metadata edit, About, skeletons | new |
| **P3** | `#FFFFFF` SVG stroke → `ph-check`; no-op color-mix; tint-alpha tokens | cards/primitives |
| **P3** | Doc index/regen: README tree, preview list, components README table | docs |
