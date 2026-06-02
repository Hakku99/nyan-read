# Design System Handoff (2026-06) — Implementation Plan & Progress Tracker

> Source of truth: `nyan-read-design-system/project/` handoff bundle (Claude Design, 2026-06-01).
> Bridge doc: `HANDOFF-flutter.md`. Token truth: `colors_and_type.css`.
>
> **The design-system bundle has the highest priority.** Where it conflicts with
> `AGENTS.md`, the bundle wins and `AGENTS.md` is updated to match (see §2). This
> doc is the single tracker for the work; update the checklist (§7) as tasks land.

---

## 0. How to read this file

- Each task is tagged with **Model** + **Reasoning effort** required to execute it well.
  Before starting a task, that tag is restated; after finishing, a *"What changed / How to test"*
  note is appended to the task and the §7 checkbox is ticked.
- Status legend: `☐ TODO` · `◐ IN PROGRESS` · `☑ DONE` · `⊘ BLOCKED (needs decision)`.
- Phases are ordered by dependency. **Do not skip ahead** — tokens (Phase A) gate everything.
- Protected Surfaces (`AGENTS.md §3.5`) touched: the **One Paper reader chrome** (Phase C)
  borders the reader-progress UI; it carries a three-part *Impact / Risk / Verification*
  analysis inside its task before any code is written.

---

## 1. Executive summary — what this handoff changes

A prior wave (commits `e35f4fd → 241054d`, "sections 4.1–4.15 / P1–P9 / T1–T15") already
landed: AA color fixes for **Cream Light**, the Phosphor icon migration (`nyan_icons.dart`,
**0** raw `Icons.*` call sites remain), the component cosmetic refit, and a **sticky bottom
strip** reader overlay (P4).

This 2026-06 bundle introduces a fresh, larger delta on top of that. Confirmed gaps:

| # | Area | Current state | Bundle requires |
|---|---|---|---|
| 1 | **Pill / chip shape** | `StadiumBorder` (`nyan_pill_button.dart`) | **Squared `r-chip` 12pt**, outline-on-select. No more stadium. |
| 2 | **Radius scale** | `small/input/card/panel/sheet` | Add **`chip 12`** (new) + semantic `control 14 / cardNested 16 / dock 24`. |
| 3 | **Type scale** | 5 sizes (32/24/20/16/13) | Add **`caption 11`** olive eyebrow (6 sizes). |
| 4 | **Sumi Dark colors** | bg `#1D211E`, surface `#262B27`, … | Full re-tone → bg `#181B16`, surface `#242922`, surfaceMuted `#1D211B`, divider `#3D443A`, text `#ECE6DB`, etc. |
| 5 | **`surfaceRaised`** | absent | New layer `#2E342B` (dark) for dialogs/sheets/popovers; new `NyanTheme` field. |
| 6 | **Explicit dark border** | reuses divider | New `border #474E42`. |
| 7 | **Dark-mode shadows** | zero / flat (same recipe both themes) | **Elevation ladder**: luminous 0.75px ring + 1px inset catch-light + soft ambient. "No shadow in dark" rule is **retired**. |
| 8 | **Error palette** | clinical red (`#C62828`/`#FFF0F0`) | **Warm clay** — light `#A85A38` on `#FBF2EC`; dark `#D89B7E` on `#241D18`. |
| 9 | **Reader chrome** | sticky edge-welded bottom strip (P4) | **One Paper**: floating inset-12 dock (`r-dock` 24) that *grows* into a sheet (`r-sheet` 28, `dur-grow` 320ms); footer = chapter stepper `‹ ›` + thin progress bar + 3 actions (Chapters/Bookmarks/Settings). |
| 10 | **Brightness affordance** | a tile in the dock | Out of the dock → **edge-gesture capsule** (left-third vertical drag) + **top-bar sun popover** (inline slider). |
| 11 | **Depth response** | slide/fade only | Scrim (`rgba(40,36,30,.34)` light / `rgba(0,0,0,.58)` dark) + **2px blur** + page recede `scale(0.97)`. |
| 12 | **Brand mark v2** | old `nyan_read_logo.png` / `splash_screen.png` | New flat marks: `nyan_mark_v2.png`, `nyan_app_icon{,_matcha,_sumi}.png` (in bundle, **not yet in repo**). |
| — | **Phosphor icons** | ✅ done | no work — kept for reference. |
| — | **Cream Light AA tokens** | ✅ done (code matches bundle) | no work. |

---

## 2. Conflicts with `AGENTS.md` (bundle wins; AGENTS.md to be amended)

Per `AGENTS.md §0`, conflicts must be flagged before execution. These are the hard-rule
conflicts; the resolution is "design bundle wins" because the user declared it highest
priority and authorised editing `AGENTS.md`:

1. **§4.2.2 / §4.3 — Pills MUST use `StadiumBorder`.** ⛔ Bundle requires **squared `r-chip` 12**.
   → Amend §4.2.2 (add `chip 12`), §4.3 (pill = squared outline-on-select, not stadium).
2. **§4.2.5 — only 5 type sizes.** Bundle adds **`caption 11`** (olive eyebrow, load-bearing).
   → Amend §4.2.5 to 6 sizes with the 11pt caption restricted to eyebrow captions.
3. **§4.1 / §4.2.4 — "Sumi Dark: all shadows zero; layering by tone only."** ⛔ Bundle's
   **revised v3** dark elevation uses a ring + catch-light + ambient shadow.
   → Amend §4.2.4 + §4.4 anti-pattern list; document the elevation ladder.
4. **§4.2 dark color table** lists the old `#1D211E/#262B27/...` values. → Replace with the
   re-toned ladder + add `surfaceRaised` / `border` rows.
5. **Error palette** — `AGENTS.md` describes warm clay intent but the code shipped clinical
   red. → Align code to warm clay; no AGENTS text change needed beyond confirming hex.

> All amendments are confined to **Phase E** so code and doc move together and the diff is reviewable.

---

## 3. Decisions (RESOLVED 2026-06-01)

| ID | Question | **Decision** | Affects |
|---|---|---|---|
| D1 | `surfaceRaised` light value (bundle only defines dark `#2E342B`). | ✅ **Reuse `surface #FFFDF8`** — raised == surface in light; the elevation ladder is dark-only. | Phase A3 |
| D2 | One Paper scope (replaces P4 sticky strip). | ✅ **Full rework per bundle** — dock→sheet grow + DockFooter stepper + brightness relocation + scrim/blur depth response. | Phase C |
| D3 | Launcher icon regeneration platforms. | ✅ **Skip launcher regen for now** — import assets + update About/splash art only; defer `flutter_launcher_icons` re-run to a follow-up. | Phase D |
| D4 | Reader-progress determinism under One Paper. | ✅ **Chrome-only** — no change to `ReadingPosition`/pagination math; invariants `§3.6` must still hold. | Phase C |

---

## 4. Model & reasoning-effort policy

| Task character | Model | Reasoning effort |
|---|---|---|
| Mechanical token edits, asset swaps, doc text | **Haiku** / **Sonnet** | low |
| Component rewrites with theme wiring + tests | **Sonnet** | medium |
| Theme-aware shadow engine, cross-cutting color re-tone | **Opus** | medium–high |
| One Paper reader chrome (state machine + gesture + animation, Protected Surface) | **Opus** | high |
| AGENTS.md reconciliation (precision-critical, irreversible-ish) | **Opus** | medium |

---

## 5. Phased task plan

### Phase A — Token foundation (gates everything)

- **A1 · Radius scale** — add `chip = 12`; add semantic `control = 14`, `cardNested = 16`,
  `dock = 24` to `nyan_radius.dart` (alias existing where equal). Keep old names for compat.
  **Model: Haiku · effort: low.** Files: `lib/core/theme/nyan_radius.dart`.
- **A2 · Caption type** — add `NyanTypography.caption = 11` + an eyebrow `TextStyle`
  (w500, +0.22 letter-spacing, uppercase, `primaryDeep`). **Model: Haiku · effort: low.**
  Files: `nyan_typography.dart`.
- **A3 · Sumi Dark re-tone + new fields** — update `nyan_colors.dart` ink values to the v3
  ladder; add `surfaceRaised` + `border` atomic constants; add `surfaceRaised` field to
  `NyanTheme` (+ `copyWith`/`lerp`/both presets) using D1 for light. **Model: Opus · effort:
  medium.** Files: `nyan_colors.dart`, `theme_presets.dart`. ⚠ Re-test every dark screen.
- **A4 · Warm-clay error palette** — replace `errorBackground/Primary/Secondary/Accent`
  light+dark constants with bundle hex. **Model: Sonnet · effort: low.** Files: `nyan_colors.dart`.
- **A5 · Theme-aware shadow engine** — make `NyanShadows.{lightCard,subtle,settingsGrouped}`
  brightness-aware: light = current recipe; dark = `0 0 0 .75px ring@88/66/50%` + `inset 0 1px 0 white@5%`
  + ambient. Add a `Brightness`/`isDark` param (or read `surfaceRaised`); migrate call sites.
  **Model: Opus · effort: medium-high.** Files: `nyan_shadows.dart` + all callers.

### Phase B — Component conformance

- **B1 · Squared pill** — rewrite `nyan_pill_button.dart`: `StadiumBorder` →
  `RoundedRectangleBorder(NyanRadius.chip)`; unselected = `surfaceMuted` fill + `divider`
  border; selected = transparent fill + `primaryDeep` border + `primaryDeep` text. Update
  tests. **Model: Sonnet · effort: medium.** Files: `nyan_pill_button.dart`, related tests.
- **B2 · Segmented control audit** — verify track `card`(20)/indicator `input`(16)/240ms
  ease-out-cubic still matches; fix if drifted. **Model: Sonnet · effort: low.**
- **B3 · Eyebrow caption adoption** — route section eyebrows through the A2 caption style
  where the bundle screens use it (settings groups, reader settings). **Model: Sonnet · effort: low.**
- **B4 · Raised-surface wiring** — point dialogs/bottom-sheets/popovers at `surfaceRaised`
  + the dark ring shadow. **Model: Sonnet · effort: medium.** Files: `nyan_bottom_sheet.dart`,
  `nyan_confirm_dialog.dart`, `nyan_sheet_appearance.dart`, `theme_presets.dart` (dialog/sheet themes).

### Phase C — One Paper reader chrome ⚠ Protected Surface

> **Impact / Risk / Verification analysis is authored inside this task before any edit.**
> Reference: `components/reader.jsx` (`OnePaperDock`, `DockFooter`, `ReaderSettingsBody`),
> `ui_kits/.../ReaderScreen.jsx`, README "One Paper" section.

- **C1 · Plan & spec lock** — write the 3-part analysis; map current
  `reader_page_overlay.dart` / `reader_menu.dart` / `reader_settings/*` onto
  `OnePaperDock` + `DockFooter` + shared `ReaderSettingsBody`. **Model: Opus · effort: high.**
- **C2 · OnePaperDock widget** — floating inset-12 dock (`r-dock` 24) that animates
  `max-height` + radius (→`r-sheet` 28) over `dur-grow` 320ms `ease-paper`; footer pinned;
  tapped action lit matcha. Replaces the sticky strip. **Model: Opus · effort: high.**
- **C3 · DockFooter** — chapter stepper `‹ ›` + thin progress bar + 3 actions
  (Chapters/Bookmarks/Settings). Wire to existing controllers/`ValueListenable`s. **Model:
  Opus · effort: high.**
- **C4 · Brightness relocation** — remove brightness tile from dock; add left-third
  edge-drag capsule + top-bar sun popover (single inline `NyanSlider`). **Model: Opus · effort:
  high.** Files: `brightness_hud_widget.dart`, top bar, gesture handler.
- **C5 · Depth response** — scrim + `--scrim-blur` 2px + page `scale(0.97)` recede when the
  dock grows; tap-scrim / grabber collapses. **Model: Opus · effort: medium.** Mind
  `AGENTS.md §3.4` saveLayer/Opacity rules — use `BackdropFilter` sparingly, `AnimatedScale`.
- **C6 · Reader tests** — update/extend `reader_menu_test`, overlay/progress-card tests for
  the new structure; keep determinism invariants (`§3.6`). **Model: Sonnet · effort: medium.**

### Phase D — Brand v2 assets (launcher regen DEFERRED per D3)

- **D1 · Import assets** — copy `nyan_mark_v2.png`, `nyan_app_icon{,_matcha,_sumi}.png`,
  `splash_screen.png` (v2) into `assets/images/`; register in `pubspec.yaml`. **Model: Haiku ·
  effort: low.**
- **D2 · Splash art swap** — swap splash artwork in `splash_page.dart` to v2.
  **Launcher-icon regeneration is deferred** (D3) — leave `flutter_launcher_icons.yaml`
  untouched for now, note it as a follow-up. **Model: Sonnet · effort: low.**
- **D3 · About logo** — point About/welcome logo at `nyan_mark_v2.png`. **Model: Haiku · effort: low.**

### Phase E — `AGENTS.md` + docs reconciliation

- **E1 · Amend AGENTS.md** — apply the §2 amendments (chip radius, caption type, dark
  elevation ladder, dark color table + `surfaceRaised`/`border`, pill = squared, error
  palette). **Model: Opus · effort: medium.**
- **E2 · Update token docs** — refresh any token tables in `docs/` referencing the old dark
  values / stadium pills. **Model: Sonnet · effort: low.**

### Phase F — Verification & regression

- **F1 · Static** — `flutter analyze` clean (no new findings); grep guards: no `StadiumBorder`
  in pill, no raw `Color(0xFF` in `lib/modules/`, no `.withOpacity(`. **Model: Sonnet · effort: low.**
- **F2 · Tests** — full `flutter test`; reconcile against the known pre-existing failures
  baseline. **Model: Sonnet · effort: low.**
- **F3 · Visual parity sweep** — both themes across the 19 bundle screens; dark elevation
  reads as distinct planes; pills squared; One Paper grows correctly. **Model: Opus · effort:
  medium** (manual / device).

---

## 6. Per-task execution log

### C1 — One Paper: Impact / Risk / Verification + mapping (2026-06-01)

**Spec sources:** `components/reader.jsx` (`OnePaperDock`, `DockFooter`, `ReaderSettingsBody`, `ReaderChapterList`, `Knob`, panels); `ReaderScreen.jsx` (composition, gesture model, brightness popover).

**Current implementation (what changes):**
- `reader_page.dart` orchestrates a `Stack` with: reader body + corner progress/chapter labels; error view; **edge brightness gesture (already present**, lines ~438–462, `edgeBrightnessGestureEnabled`); a **sticky bottom strip** `_ReaderBottomOverlay` (4 tiles: Chapters/Bookmarks/Brightness/Settings); a **sticky top strip** `_ReaderTopOverlay` (back / title / bookmark / more); `BrightnessHudWidget`.
- Chrome visibility = single `bool _showControls`.
- Settings + Chapters + Brightness each open as **separate `showModalBottomSheet`** destinations (`_showReaderSettingsSheet` → `ReaderMenu`; `_openChapterList` → `ChapterListWidget`; `_showReaderBrightnessSheet` → `ReaderSettingsDisplayPanel`).

**Target (One Paper):**
- One floating **`OnePaperDock`** (inset 12, `r-dock` 24) that **grows into a sheet** (`r-sheet` 28, `dur-grow` 320ms) in place — no modal push for Settings/Chapters.
- **`DockFooter`** pinned at base: chapter stepper `‹ ›` + thin progress bar (collapsed only) + **3 actions** (Chapters/Bookmarks/Settings). **Brightness leaves the dock.**
- Bookmarks stays a **pushed page** (already is).
- Brightness → **top-bar sun popover** (centered glass dialog) + the **existing edge-gesture** (kept).
- Sheet rise → canvas **recede `scale(0.97)` + warm scrim + 2px blur**; tap scrim / grabber collapses.

**Component mapping (JSX → Dart):**
| JSX | Dart target | Reuse? |
|---|---|---|
| `OnePaperDock` | new `widgets/one_paper_dock.dart` | new shell |
| `DockFooter` | new (same file or `dock_footer.dart`) | new; wires `progressListenable` + `jumpToChapter` |
| `ReaderSettingsBody` (Display/Text/Theme) | existing `reader_settings/*` panels + `ReaderMenu` body | **reuse** (render chromeless in dock) |
| `ReaderChapterList` | existing `ChapterListWidget` | **reuse** (render chromeless in dock) |
| Brightness dialog | existing `ReaderSettingsDisplayPanel` brightness block / `BrightnessHudWidget` | **reuse** in a centered dialog |

**Controller API available (no new engine contract needed):** `chapters`, `currentChapterIndex` (int?), `currentProgress`, `progressListenable`, `jumpToChapter(index, locator)`, `nextPage`/`previousPage`, `addBookmark`, `setWarmth`, `setPageTurnMode`, `syncChapterAfterScroll`, `backgroundColor`. Stepper prev/next = `jumpToChapter(idx∓1, chapters[idx∓1].locator)`.

**IMPACT:** Chrome-only (D4). No change to `ReaderEngine` / `ReadingPosition` / `ChapterLocator` / pagination. The stepper and chapter list call the *existing* `jumpToChapter`; progress reads the *existing* `progressListenable`. The §3.5 protected algorithms are untouched.

**RISK:**
1. **Gesture collisions** — page-turn taps (`SmoothPageReader` center/edge taps), chrome toggle tap, tap-scrim-to-collapse, and left-third edge brightness drag must stay disjoint. *Mitigation:* keep `SmoothPageReader` center-tap → chrome toggle; when a sheet is open, the scrim layer (above canvas, below dock) absorbs taps → collapse; edge-gesture zone unchanged.
2. **Animation cost** — `max-height` grow + canvas blur could jank on low-end (`AGENTS §3.4` saveLayer/Opacity rules). *Mitigation:* `AnimatedSize`/`AnimatedContainer` for grow; scrim via animated-opacity `Container` (no saveLayer); 2px `BackdropFilter` mounted **only while a sheet is open**; `RepaintBoundary` around the dock.
3. **BrightnessOverlayWidget scoping** — modal sheets currently re-wrap the brightness overlay; growing in place means the dock lives under the *existing* top-level `BrightnessOverlayWidget`, so the warmth/dim tint now also colors the dock. *Mitigation:* acceptable (dock is chrome over the page); verify legibility both themes.
4. **State migration** — `_showControls` → `{chrome, sheet}` touches several call sites (`_handleOverlayTile`, `_open*`). *Mitigation:* land C2–C5 behind the same `_setControlsVisible` entry points; keep old `_open*` helpers callable until cutover.

**VERIFICATION (per task):** widget tests for DockFooter (stepper enable/disable at ends, 3 actions, progress bind), grow/collapse state machine, and the §3.6 invariants (TOC current-chapter == footer chapter; cold-resume position unchanged). Manual: both themes, immersive→dock→sheet→collapse, edge brightness, sun popover, page-turn still works with chrome hidden.

**Status:** ✅ analysis complete; approved; C2+C3 landed.

---

### C2 + C3 — OnePaperDock + DockFooter + reader_page rewire (2026-06-01)

**What changed:**
- **New** `lib/modules/reader/widgets/one_paper_dock.dart` — `OnePaperDock` (floating inset-12 panel; radius `r-dock`24→`r-sheet`28; body reveal via `AnimatedAlign(heightFactor)` over `dur-grow` 320ms; immersive slide/opacity via `AnimatedSlide`/`AnimatedOpacity`; grabber + title/meta header) and `DockFooter` (chapter stepper `‹ ›` + thin progress bar shown only when collapsed + 3 actions Chapters/Bookmarks/Settings; `DockAction` enum; active = matcha tint). Progress/% bind to `progressListenable`.
- `chapter_list_widget.dart` — added `showSheetChrome` / `showHeader` flags; embedded path returns a chromeless `Column[sort, Expanded(virtualized list)]` for the dock.
- `reader_page.dart` — replaced the P4 sticky strip with `OnePaperDock` + scrim. New state `DockAction? _openSheet`; methods `_sheetTitle/_sheetMeta/_buildSheetChild/_handleDockAction/_toggleSheet/_collapseSheet/_stepChapter`; `_setControlsVisible` now collapses the sheet on hide. Settings → `ReaderMenu(showSheetChrome:false, showHeader:false)`; Chapters → chromeless `ChapterListWidget`; Bookmarks → existing pushed page. Top-bar "more" now grows the Settings sheet. Removed dead modal helpers + unused imports.
- `reader_page_overlay.dart` — removed the sticky bottom strip + brightness/settings modal-sheet helpers; kept the floating top bar.

**Reused (no rebuild):** Display/Text/Theme panels (`ReaderMenu`), `ChapterListWidget`, `progressListenable`, `jumpToChapter`. **No pagination/position change** (§3.5 / §3.6 intact).

**Known gaps (next tasks):** brightness sun popover not yet added (C4) — brightness is reachable via the **existing left-edge drag** meanwhile; sheet **close** clears content instantly (open is smooth) — C5 will keep content mounted during the collapse + add canvas recede/blur.

**How to test:**
1. `flutter analyze` → clean (only pre-existing `_runAnchorHealingInIsolate`).
2. `flutter test` reader suite → 22 pass; the only 2 failures are pre-existing `reader_menu_test` "Reset all" cases (a separate reset-section design, confirmed via stash — unrelated to One Paper).
3. Manual: open a book → tap center → dock appears floating inset; tap **Settings**/**Chapters** → dock grows into a sheet in place; tap scrim or grabber → collapses; stepper carets change chapter; **Bookmarks** pushes a page; page-turn still works with chrome hidden.

---

### C4 — Brightness relocation (2026-06-01)

**What changed:**
- **New** `lib/modules/reader/widgets/reader_brightness_popover.dart` — `ReaderBrightnessPopover`: centered glass dialog (BackdropFilter 13.6px, **mounted only while open**) with sun badge + "Brightness" + live `%` + moon–slider–sun row (reuses `ReaderSettingsSlider`, bound to `BrightnessController.uiBrightnessValue`/`setFromSlider`) + "Follow system brightness" switch (`toggleFollowSystem`). Card on `surfaceRaised` + `lightCard` shadow.
- `reader_page_overlay.dart` — added a **sun button** to the top bar (between title and bookmark); `_TopOverlayIconButton` gained an `active` state (matcha-tint chip when the popover is open).
- `reader_page.dart` — `_brightnessPopoverOpen` state + `_toggleBrightnessPopover`/`_closeBrightnessPopover`; popover added to the Stack (above dock). Brightness popover and grown sheet are mutually exclusive. The **existing left-edge drag brightness gesture is retained** (now there are two affordances, per spec).

### C5 — Depth response (2026-06-01)

**What changed (`reader_page.dart`):**
- Scrim now wraps a **2px `BackdropFilter`** (the one sanctioned blur) — **mounted only while a sheet is open**, so no idle saveLayer cost during reading.
- **Smooth close**: added `_displayedSheet` (+ a 320ms `_sheetCloseTimer`) so the sheet body stays mounted through the collapse animation and clears after, instead of vanishing on the first frame. Title/meta/body read `_displayedSheet`; `sheetOpen`/`activeAction` read `_openSheet`.

**Deferred:** the canvas `scale(0.97)` recede — wrapping the ~200-line reader-body subtree in `AnimatedScale` risked corrupting the protected `reader_page.dart` for a subtle 3% transform. The scrim + 2px blur already deliver the depth cue; the scale can be added later as an isolated, low-risk follow-up.

**How to test:** `flutter analyze` clean; reader tests pass except the 2 pre-existing "Reset all" cases. Manual: tap the **sun** in the top bar → glass brightness dialog; drag the left edge → brightness HUD; open Settings/Chapters → page dims + softly blurs behind the sheet; collapse → content fades with the dock (no snap).


### A1 — Radius `chip 12` + semantic names (2026-06-01)

**What changed:** `lib/core/theme/nyan_radius.dart`
- Added `chip = 12` (option chips / pill buttons, nested deepest).
- Added `control = 14` (segmented-control track), `cardNested = 16` (cards-in-sheet), `dock = 24` (floating bars).
- Old names `small / input / panel` are now `const` aliases for the semantic names — no existing call site breaks.

**How to test:**
1. `flutter analyze lib/core/theme/nyan_radius.dart` → no issues.
2. Confirm existing callers compile: `flutter build apk --debug` (or `flutter test`).
3. Verify `NyanRadius.small == 14`, `NyanRadius.input == 16`, `NyanRadius.panel == 24` still hold.

---

### A2 — Caption `11` type + eyebrow style (2026-06-01)

**What changed:** `lib/core/theme/nyan_typography.dart`
- Added `NyanTypography.caption = 11` (6th type size, olive eyebrow only).
- Added `NyanTypography.eyebrowStyle(Color color)` factory → 11pt / w500 / +0.22 letter-spacing / h=1.0 / uppercase, takes `nyan.primaryDeep` at call site.

**How to test:**
1. `flutter analyze lib/core/theme/nyan_typography.dart` → no issues.
2. In a screen that has a section eyebrow (e.g. Settings groups, reader settings headers), replace the inline `TextStyle` with `NyanTypography.eyebrowStyle(nyan.primaryDeep)` and confirm the visual output matches the bundle spec (11pt, uppercase, olive).

---

### A3 — Sumi Dark re-tone + `surfaceRaised`/`border` (2026-06-01)

**What changed:**
- `lib/core/theme/nyan_colors.dart` — Sumi Dark atomic constants re-toned to the v3 elevation ladder: `inkNightBackground #1D211E→#181B16`, `inkNightSurface #262B27→#242922`, `inkNightSurfaceMuted #202520→#1D211B`, `inkNightDivider #3A3F3A→#3D443A`, `inkNightTextMain #E8E1D5→#ECE6DB`, `inkNightTextSecondary #B4AC9F→#BBB3A6`, `inkNightTextMuted #A6A099→#9A948B`, `inkNightPrimaryDeep #B3C29A→#B7C69E`, `inkNightSuccess #8FBC8F→#94C194`. `inkNightPrimary` unchanged (`#A9B690`). **New** constants: `inkNightSurfaceRaised #2E342B`, `inkNightBorder #474E42`.
- `lib/core/theme/theme_presets.dart` — added `surfaceRaised` field to `NyanTheme` (+ constructor / `copyWith` / `lerp`). Light preset `surfaceRaised = creamSurface` (D1); dark preset `surfaceRaised = inkNightSurfaceRaised`. Dark `borderColor` switched `inkNightDivider → inkNightBorder`.

**Notes / dependencies:** Widgets that reference `NyanColors.inkNight*` constants pick up the new tones automatically. The ladder only *fully* reads once **A5** (dark shadow ring + catch-light) and **B4** (dialogs/sheets → `surfaceRaised`) land. `accent` for dark is still `highlightOrange` (pre-existing; out of A3 scope — revisit if the bundle wants `primaryDeep`).

**How to test:**
1. `flutter analyze lib/core/theme/` → no issues (confirmed). Full `flutter analyze` → only the pre-existing `_runAnchorHealingInIsolate` warning.
2. Run the app, switch to **Sumi Dark**: page void should read clearly darker than cards; recessed tracks (tab/slider rails) sit just above the page. Confirm no regressions in text legibility.
3. `flutter test` to confirm theme-dependent widget tests still pass.

---

### A5 — Theme-aware shadow engine / dark elevation ladder (2026-06-01)

**What changed:**
- `lib/core/theme/nyan_shadows.dart` — `lightCard` / `subtle` / `settingsGrouped` now take a `NyanTheme` instead of a `Color`. Light = the previous warm-ink recipe (sourced from `nyan.textPrimary`). **Dark = v3 ladder**: a `0.75px` non-blurred spread ring (`nyan.divider` @ 88/66/50%) + gentle black ambient (`lightCard` 44%@24px + 34%@8px; `subtle` 34%@14px; `grouped` 24%@8px). Private `_ring()` helper draws the CSS `0 0 0 0.75px` outline as a `BoxShadow(blurRadius:0, spreadRadius:0.75)`.
- **Retired the `dark ? const [] : …` opt-outs** at two call sites: `bookmark_list_page.dart:315` and `nyan_info_card.dart:56`. Dark cards now carry the ring. (`nyan_info_card` keeps the **muted-tone** opt-out — muted = recessed/inset, correctly shadowless.)
- Migrated all 6 call sites to pass the theme: `bookmark_list_page`, `animated_book_card`, `nyan_book_grid_card`, `nyan_fab`, `nyan_info_card`, `nyan_row_group`.

**Known limitation:** Flutter `BoxShadow` has no **inset** mode, so the spec's `inset 0 1px 0 white@5%` top catch-light is not carried in the shadow token. The ring (the load-bearing plane cue) is represented; raised surfaces wanting the catch-light add a top `BorderSide` @5% white in their own decoration during **B4**.

**How to test:**
1. `flutter analyze` → only the pre-existing `_runAnchorHealingInIsolate` warning.
2. Sumi Dark: cards / FAB / grouped settings / bookmark rows should now show a faint luminous edge ring + soft ambient (previously flat). Cream Light should look unchanged.
3. `flutter test` (baseline reconciliation).

---

## 7. Progress checklist

### Phase A — Tokens
- [x] A1 Radius `chip 12` + semantic names — *Haiku/low*
- [x] A2 Caption `11` type + eyebrow style — *Haiku/low*
- [x] A3 Sumi Dark re-tone + `surfaceRaised`/`border` fields — *Opus/medium* (D1: light raised = surface)
- [ ] A4 Warm-clay error palette — *Sonnet/low*
- [x] A5 Theme-aware shadow engine (dark elevation ladder) — *Opus/medium-high*

### Phase B — Components
- [x] B1 Squared pill (outline-on-select) — *Sonnet/medium*
- [x] B2 Segmented control aligned to June 2026 bundle — *Sonnet/low* (track r-control 14, 280ms, surfaceMuted bg, no border)
- [x] B3 Eyebrow caption — *no-op* (caption=11 token added in A2; `.nyan-caption` unused in app screens; `NyanSectionHeader` correctly uses meta=13/w600 per JSX)
- [x] B4 Raised-surface wiring (dialogs/sheets/popovers) — *Sonnet/medium*

### Phase C — One Paper reader chrome ⚠ Protected Surface
- [x] C1 Impact/Risk/Verification + mapping — *Opus/high* (D2: full rework; D4: chrome-only)
- [x] C2 `OnePaperDock` grow-to-sheet — *Opus/high*
- [x] C3 `DockFooter` + reader_page state-machine rewire — *Opus/high*
- [x] C4 Brightness relocation (edge gesture kept + top-bar sun popover) — *Opus/high*
- [x] C5 Depth response (scrim + 2px blur + smooth close) — *Opus/medium* (canvas scale recede deferred — see log)
- [ ] C6 Reader tests — *Sonnet/medium*

### Phase D — Brand v2
- [ ] D1 Import + register assets — *Haiku/low*
- [ ] D2 Splash art swap (launcher regen deferred per D3) — *Sonnet/low*
- [ ] D3 About logo — *Haiku/low*

### Phase E — Docs
- [ ] E1 Amend AGENTS.md — *Opus/medium*
- [ ] E2 Update token docs — *Sonnet/low*

### Phase F — Verification
- [ ] F1 Static / grep guards — *Sonnet/low*
- [ ] F2 Tests — *Sonnet/low*
- [ ] F3 Visual parity sweep (both themes, 19 screens) — *Opus/medium*

---

## 8. Source map (where each spec lives in the bundle)

- Tokens → `colors_and_type.css`
- Flutter bridge → `HANDOFF-flutter.md`
- Components → `ui_kits/nyan_read_app/components/{primitives,headers,surfaces,cards,reader}.jsx`
- Screens (19) → `mocks/U01–U19 *.html`, `screens/bundle{1-4}.jsx`, `screens/_chrome.jsx`
- One Paper → README "One Paper" + `components/reader.jsx`
- Brand v2 → `assets/images/nyan_mark_v2.png`, `nyan_app_icon*.png`; geometry `brand/nyan-mark.jsx`
