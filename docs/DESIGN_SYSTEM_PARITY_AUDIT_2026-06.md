# Design System Parity Audit — 2026-06 bundle vs. live app

> Source of truth: `Nyan Read Design System-handoff.zip` → `nyan-read-design-system/project/`.
> Token truth `colors_and_type.css`; bridge `HANDOFF-flutter.md`; canonical screens
> `ui_kits/nyan_read_app/*.jsx`; components `…/components/{primitives,surfaces,cards,headers,reader}.jsx`.
>
> This audit compares the **shipped app** (35 device screenshots + the live Dart source)
> against the bundle, lists every difference, and proposes a phased plan to reach parity.
> It supersedes nothing in `DESIGN_SYSTEM_HANDOFF_2026-06_PLAN.md` — that plan's tokens
> (Phase A) and One Paper chrome (Phase C) **did land**; this audit is the *remaining* delta
> the maintainer flagged after a visual pass.

Legend: **[FIX]** clear non-conformance · **[DECIDE]** the app is a functional superset / product
choice — confirm before changing · **[VERIFY]** no screenshot, audit against the mock.

---

## 0. What already conforms (no work)

- **Tokens** — Cream Light + Sumi Dark v3 ladder, `surfaceRaised`, warm-clay error palette, dark
  elevation ring shadows. (Plan Phase A.)
- **One Paper reader chrome** — floating inset dock that grows into a sheet, footer pinned, scrim +
  2px blur depth response. (Plan Phase C; screenshots 10, 23, 24, 26–29.)
- **Pill chips** — squared `r-chip` outline-on-select in reader settings (Tap/Swipe, Compact/
  Standard, Sans/Serif, Low/Med/High). (Plan B1.)
- **Reader Theme panel** — 2×2 Cream/Sepia/Sumi/Charcoal, matcha border + check badge. (≈ design.)
- **Brightness popover** — centered card, sun badge, %, moon–slider–sun, follow-system. (Plan C4.)
- **Brand v2 mark** in the About card (screenshot 5).
- **Warm-clay destructive** action (bookmark swipe "Delete", screenshot 21).

---

## 1. [FIX] Selection sheets — Theme / Language / Sort use list-rows-with-checks

**Biggest single divergence.** The bundle's signature is outline-on-select **PillButton chips** and it
says so explicitly (README *"option chips use the single outline-selected pill pattern, **not
list-rows-with-checks**"*; `BookshelfScreen.jsx` Sort sheet).

The app does the opposite — `NyanSelectionSheet` + `NyanSelectionSheetRow`
(`lib/core/ui/components/nyan_selection_sheet.dart`) render a rounded card of full-width rows with a
trailing `check` icon. Used by:

| Sheet | Current | Design target |
|---|---|---|
| **Theme Preset** (screenshot batch-1 #1) | 2 rows "Cream Light ✓ / Sumi Dark" | 2 chips, outline-on-select |
| **Language** (screenshot batch-2 #2) | 2 rows "中文 / English ✓" | 2 chips |
| **Sort by** (screenshot batch-1 #3) | 6 rows (Last Read Desc/Asc, Added Desc/Asc, Title Asc/Desc) | **3 key chips** (Last Read / Added / Title) **+ an Ascending/Descending `SegmentedTabControl`** |

---

## 2. [FIX] Bookshelf header

`home_screen.dart:686-688` + `bookshelf_shelf_toolbar.dart`.

1. **Title.** App shows the branded `loc.appTitle` *"Nyan Read ฅ^•ﻌ•^ฅ"* + `loc.enjoyReading`
   *"Enjoy your reading"* subtitle. `BookshelfScreen.jsx` uses a plain **"Bookshelf"** (600/22, no
   subtitle); the README reserves the mascot title for **splash + About only**. → Drop the mascot
   title/subtitle on Home, use "Bookshelf". *(If the maintainer prefers brand-on-home, this is the
   one spot to keep it — flag.)*
2. **Action buttons.** App uses `NyanRecessedIconButton` (muted recessed fill, borderless). Design
   `SquareAction` = `surface` fill + `r-control 14` + **1px divider border**. → Reskin to bordered
   surface squares. Order should read **Sort · View-toggle · Settings**.
3. **Shelf tabs.** App shows a single "Public Shelf" tab; design shows a **Public / Private** 2-up
   segmented track. *(Private is Pro-gated — DECIDE whether to always show both.)*

---

## 3. [FIX] Bookmarks destination page

Design (`ReaderScreen.jsx` bookmarks page + `NyanBookmarkCard`): pushed page titled **"Bookmarks"**
with a **"{n} saved"** meta, then a flat list of bookmark cards — each card: label `Chapter · title ·
pct`, optional **Note** chip, an excerpt with a 2px matcha tick bar, and a `time ago` meta.

App (screenshots 1, 21, 25):
1. Title is **"Bookmarks (1)"** + book-title subtitle → design wants "Bookmarks" + "{n} saved".
2. Has a top **"Reading marks / Tap a passage to return. Swipe left to delete."** instruction info
   card — not in the design.
3. Cards are **date-grouped** ("2026.06.03") with label "Bookmark 1" + excerpt; design is ungrouped
   with the richer `NyanBookmarkCard` (note chip + meta time-ago).
4. Empty state copy ✓ ("No bookmarks yet" / "Passages worth returning to will gather here.").

→ Re-tone the page to the design header + `NyanBookmarkCard` layout. *(Date grouping + the
instruction card are DECIDE items — they may be deliberate UX the maintainer wants to keep.)*

---

## 4. [FIX] One Paper dock footer — collapsed label & icons

`one_paper_dock.dart`. The chrome model conforms; two cosmetic gaps:

1. **Collapsed stepper center label.** App shows the **chapter title text + %** (screenshot 10:
   "‹ PS7：第一卷… 0% ›"). Design `DockFooter` shows **"Chapter {n} of {count}"** + a thin progress bar
   + %. → Swap the center label to the "Chapter n of N" form over the progress bar.
2. **Action icons.** Design = `list` / `bookmark_border` / `title` (text-aa "Aa" for Settings). App
   uses a sliders glyph for Settings. → Align the Settings icon to the text-aa/`title` glyph.

---

## 5. [FIX] Reader Settings panels — nesting & ordering

`reader_settings_display_panel.dart`, `reader_settings_text_panel.dart`.

1. **Knob nesting.** Design wraps **each** control in a `Knob` — a `surface-muted`, `r-card-nested 16`
   sub-card with a 15/600 label + meta hint. The app wraps the **whole panel** in one `NyanSheetCard`
   (`r-card 20`) with inline `ReaderSettingsSliderTile`s. → Adopt the per-control muted Knob card so
   the concentric "card-in-sheet" reads as designed.
2. **Display order.** App = Page Turn Mode → Brightness → Warmth. Design = **Brightness → Warmth →
   Page Turn Mode**. → Reorder.

---

## 6. [FIX] Copy / label nits

| Where | App | Design |
|---|---|---|
| Settings section header | "READING SETTINGS" | "Reading" (still uppercased by the caption style) |
| Delete-files subtitle | "Original files will also be removed from your device." | "Also delete originals from your device" |
| Import-assets subtitle | "Restore reading data from JSON backup" | "Restore reading data from JSON backup" ✓ |
| Reader theme reset | "Reset Theme" (+ refresh icon) | "Reset to defaults" (plain text, no icon) |
| Reading Settings row subtitle | "18pt · Sans" | "Font, spacing, theme, warmth" |

---

## 7. [FIX] Import sheet format chips

`import_book_sheet.dart` `_FormatChip` / `_ShelfBadge` use `r-input 16`. The concentric family puts
option chips at `r-chip 12`. Low-impact (they're static labels, not interactive), but snap to
`r-chip 12` for consistency.

---

## 8. [DECIDE] Functional supersets — confirm before removing

The app intentionally carries controls the simplified mocks omit. "Exactly the same" would remove
them; that's a product call, not a styling one:

1. **Brightness presets + Auto.** App adds **Dim / Normal / Bright** preset pills + an **Auto** chip
   (`_BrightnessPresetRow`). Design Brightness = slider + "Follow system" switch only.
2. **Typography density presets.** App's Compact/Standard/Comfortable set **font-size + line-height
   together**, with a collapsible **Fine-tune** (size −/+, line-height −/+). Design uses those three
   words for **line-height only**, and Font Size is a stepper+slider with a `pt` readout.
3. **Per-tab reset.** App has **Reset Display / Reset Text / Reset Theme**. Design has **one** "Reset
   to defaults" in the Theme panel.
4. **Public/Private tab** (see §2.3).

> Recommendation: keep 1–3 (richer, on-brand, and the chips are already squared/conformant); only
> the *labels/placement* differ. If the maintainer wants literal mock parity, these become removals.

---

## 9. [VERIFY] Screens with no screenshot

Audit these app widgets against their mocks (likely fine post-Phase-C, but unconfirmed visually):

| Mock | App widget |
|---|---|
| U02 Highlight Note Dialog | `reader/widgets/highlight_note_dialog.dart` |
| U05 Text Selection Menu | `reader/widgets/text_selection_menu.dart` |
| U06 / U16 PIN Entry · Privacy PIN | privacy / secure entry (`nyan_secure_entry_dialog.dart`) |
| U07 Splash | `settings`/splash page + `SplashScreen.jsx` |
| U08 Reader Error View | `reader/widgets/reader_error_view.dart` |
| U10 Book Details | `bookshelf/book_details_page.dart` (`BookDetailsScreen.jsx`) |
| U13 Notes & Highlights | `nyan_highlight_card.dart` + highlights page |
| U17 Read Aloud (TTS) | TTS UI (if present) |
| U18 Admin Panel | admin module |

---

## 10. [VERIFY] Assets / fonts

- **Fonts.** Noto Sans SC is bundled in the design; the repo git-ignores font binaries (manual drop
  per `assets/fonts/README.md`). Screenshots render CJK fine → fonts are present locally. Confirm CI
  / fresh clones still warn-and-fallback gracefully.
- **Launcher icon regen** remains deferred (`DESIGN_SYSTEM_HANDOFF…PLAN.md` D3): `nyan_app_icon*.png`
  are imported but `flutter_launcher_icons.yaml` not re-run.

---

## Plan — phased to parity

Ordered by impact ÷ risk. None touch Protected Surfaces (§3.5) except where noted; reader changes are
chrome-only and must preserve §3.6 invariants.

### Phase P1 — Selection sheets → pill chips  *(highest impact, self-contained)* ✅ done 2026-06-03
- **P1a** ✅ New `nyan_chip_selection_sheet.dart` — `showNyanChipSelectionSheet<T>` renders a bounded
  `Row` of `Expanded` `NyanPillButton` outline-on-select chips (a `Wrap` would overflow the chips'
  internal `Flexible`); single-select pops the value. `NyanSelectionOption<T>` relocated here.
- **P1b** ✅ New `bookshelf_sort_sheet.dart` — `showBookshelfSortSheet`: 3 key chips (Last Read /
  Added / Title) + Ascending/Descending `SegmentedTabControl` (subtle), applied **live** via
  `onChanged` while the sheet stays open (matches `BookshelfScreen.jsx`). Wired into
  `home_screen.dart` `_showSortMenu`.
- **P1c** ✅ Theme Preset + Language + Reminder-Interval settings sheets repointed at the chip sheet;
  `nyan_selection_sheet.dart` + `nyan_selection_sheet_row.dart` deleted, barrel updated. New widget
  tests in `test/selection_chip_sheet_test.dart` (pass). `flutter analyze` clean (only a pre-existing
  unrelated unused-element warning in `anchor_healer.dart`).

### Phase P2 — Bookshelf header ✅ done 2026-06-03
- **P2a** ✅ Header title → plain "Bookshelf" (maintainer chose design-faithful); subtitle dropped, mascot stays on Splash/About. New `bookshelf` l10n key (书架 / Bookshelf); dead `Theme`/`theme` wrapper removed.
- **P2b** ✅ Header actions → new `NyanSquareActionButton` (surface fill + `r-control` 14 + 1px divider border), replacing the borderless `NyanRecessedIconButton` here only (shared component left intact for reader/settings chrome). Reordered **Sort · View · (Lock, Pro) · Settings** per `BookshelfScreen.jsx`. Tests: `test/nyan_square_action_button_test.dart`.
- **P2c** ✅ NO-OP — Public/Private tabs already design-faithful (`bookshelf_shelf_toolbar.dart` shows Private when Pro-unlocked; matches U19).

### Phase P3 — Bookmarks page re-tone ✅ done 2026-06-03
- **P3a** ✅ Header → plain "Bookmarks" (`loc.bookmarks`) + "{n} saved" meta (new `bookmarksSavedCount`
  l10n, en + zh); dropped the "Bookmarks (n)" counter and the book-title subtitle (`_headerSubtitle`
  removed). Per the design bookmarks page (you're already in the book's context).
- **P3b** ✅ NO-OP — the page already renders the design `NyanBookmarkCard` layout (icon+label, Note
  chip, 2px tick-bar excerpt, optional meta) and already uses swipe-to-delete. Card component
  unchanged; its 19 tests still green.
- **P3c** ✅ KEEP — corrected the audit: U12 ("Date-grouped cards, **context panel**, swipe-delete
  reveal rail") confirms both the date grouping and the context panel ("Reading marks") are design
  features, so both stay. *(Context-panel exact styling unverified — design bundle was deleted; flag
  if Claude Design's U12 mock diverges.)*

### Phase P4 — Reader settings polish  *(chrome-only; preserve §3.6)* 🟡 partial 2026-06-03
- **P4b** ✅ Display panel reordered → **Brightness · Warmth · Page Turn Mode** per `reader.jsx`.
- **P4c** ✅ Dock footer collapsed centre now reads **"Chapter n of N"** (new `chapterOfCount` l10n,
  en + zh) built from the same `chapterIndex`/`chapterCount` as the TOC (§3.6 consistency preserved);
  `chapterLabel` param dropped from `DockFooter` + caller. Settings dock action icon → `NyanIcons.fontSize`
  (Phosphor `textAa`, the design's "title"/Aa glyph). `one_paper_dock_test` updated, 12/12 green.
- **P4a** ⏸ DEFERRED — verified against `reader.jsx`: the `Knob` is `surfaceMuted` / `r-card-nested 16` /
  pad-14 / `600 15px` label + hint, **no icon badge**. But the design's **Brightness** Knob (slider +
  "Follow system" switch, *no* Dim/Normal/Bright, *no* Auto chip) and **Text** panel (font-size
  stepper+slider + line-height pills, *no* density model) ARE the app-only supersets being re-mocked by
  Claude Design (§8). Wrapping them now would be throwaway, and carding only Warmth/Page-Turn/Theme
  would look half-finished. Resume the full Knob nesting once the §8 superset mocks land.

> **Pre-existing (NOT from P4):** `reader_menu_test` has 2 failing cases ("renders brightness controls",
> "uses custom reset all dialog") — both reproduce on a clean `git stash` tree. The "Reset all" text the
> tests look for isn't rendered; impl/test drift predating this work. Tracked separately.

### Phase P5 — Copy & chip-radius nits ✅ 2026-06-05
- **P5a** ✅ Hardcoded locale-sniffing in `reader_menu.dart` `_resetLabelForSection` eliminated.
  Added `readerResetSection("{section}")` l10n key (en + zh); the per-tab reset button now reads
  `loc.readerResetSection(sectionLabel)` — proper parametric l10n, no more `isChinese ?` branching.
  The two other `languageCode == 'zh'` usages in the codebase are legitimate (settings page shows
  native language name; ads_ui uses it for targeting — neither is visible copy through l10n).
- **P5b** ✅ DECIDED: **keep per-tab reset** (more granular than the design's single "Reset to defaults";
  an app superset). Dead keys `readerResetAll / readerResetCurrentTab / readerResetAppearance` stay in
  ARB until the `reader_menu_test` fix chip (spawned separately) resolves the failing test assertions.
- **P5c** ✅ Import sheet chips radius → **`NyanRadius.chip` (12pt)** per §4.3 "option chip / pill":
  `_FormatChip` (TXT/EPUB/PDF tags) + `_ShelfBadge` (shelf pill label) both updated.
  `_SheetLeadingIcon` (44×44 icon container) correctly stays at `NyanRadius.cardNested` (16pt) — it is
  not a chip; also migrated from the legacy alias `input` to the semantic name `cardNested`.

**Test gate:** 25/27 pass (+0 new failures vs pre-§5 baseline); 2 pre-existing `reader_menu_test`
failures unchanged (tracked in the separate fix chip).

### Phase P6 — Verify-only sweep
- **P6** Walk U02/U05/U06/U07/U08/U10/U13/U16/U17/U18 against their widgets; file follow-ups for any
  drift. *Opus/medium (manual).*

### Phase P7 — Assets follow-up
- **P7** Launcher-icon regen (`flutter_launcher_icons` across Android+iOS) when the maintainer is
  ready. *Sonnet/low.*

### Gate (every phase)
`flutter analyze` clean · `flutter test` against the known baseline · grep guards (no `StadiumBorder`,
no raw `Color(0xFF` in `lib/modules/`, no `.withOpacity(`) · both themes visual check.
