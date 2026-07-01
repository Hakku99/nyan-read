# Nyan Read — Flutter Handoff

How to carry the reorganised JSX design system into the Flutter source
(`github.com/Hakku99/nyan-read`). This doc is the bridge: the JSX kit is the
visual source of truth; this maps it onto Dart structure, tokens, and widgets.

> The JSX kit can't push to the Flutter repo directly. Apply these changes there
> by hand or hand this file to Claude Code with write access to the repo.

---

## 1. Structure mapping (JSX → Flutter)

The component library is now split by concern. Mirror the split in
`lib/core/ui/components/`:

| JSX module | Exports | Flutter target |
|---|---|---|
| `components/primitives.jsx` | `Icon`, `NyanPrimaryButton`, `PillButton`, `NyanSwitch`, `SegmentedTabControl`, `NyanSlider` | `components/primitives/` (`nyan_button.dart`, `nyan_pill.dart`, `nyan_switch.dart`, `nyan_segmented.dart`, `nyan_slider.dart`) |
| `components/headers.jsx` | `NyanSectionHeader`, `NyanPageHeader` | `components/headers/` |
| `components/surfaces.jsx` | `NyanInfoCard`, `NyanListRow`, `NyanRowGroup`, `NyanEmptyState`, `NyanBottomSheet`, `NyanActionSheetRow`, `NyanFAB`, `NyanResponse` | `components/surfaces/` |
| `components/cards.jsx` | `NyanBookGridCard`, `NyanContinueReadingCard`, `NyanBookmarkCard` | `components/cards/` |
| `components/reader.jsx` | `OnePaperDock`, `DockFooter`, `ReaderSettingsBody`, `Display/Text/ThemePanel`, `Knob`, `ReaderChapterList`, `ReaderParagraph` | `modules/reader/widgets/` |
| `screens/*.jsx` | the 19 screen compositions | `lib/modules/{bookshelf,reader,settings}/` pages |
| `screens/_chrome.jsx` | `Shell`, `ReaderBg`, `ThemeWrap` | `core/ui/scaffold/` |

---

## 2. Tokens → `ThemeData` / `NyanTheme`

Source of truth is `colors_and_type.css`. Build two `ThemeData`s (Cream Light,
Sumi Dark) from a single `NyanColors` extension. Key values:

### Cream Light
```dart
bg:#F6F3EA  surface:#FFFDF8  surfaceMuted:#F1ECDD  divider:#E5DED2
text:#3F3A34  textSecondary:#5F5950  textMuted:#706A5A
primary:#6E7A55  primaryDeep:#5A6644  success:#4F6B1E
error:#A85A38 on errorBg:#FBF2EC
```
> ⚠️ The light **text/primary** values here are **AA-revised** and diverge from
> upstream Flutter (originals kept as `--*-src`). If the app must match the live
> build pixel-for-pixel, use the `-src` set; otherwise adopt these (they pass
> WCAG AA). Decide once and record it.

### Sumi Dark — v6 MONO (neutral surfaces, off-white accent)
```dart
bg:#121212  surface:#1E1E1E  surfaceMuted:#181818  surfaceRaised:#303030
overlayField:#3A3A3A  divider:#333333  border:#474747
text:#ECECEC  textSecondary:#ABABAB  textMuted:#8A8A8A
primary:#E2E2E2  primaryDeep:#F4F4F4  success:#8FBF8F
primaryFill:#ECECEC  onPrimary:#1A1A1A  selectFill:#ECECEC
errorFill:#C24A38  onError:#FBF3E6
```
The dark theme is **true-neutral grey + a MONO (off-white) accent** — no brown,
no green, no amber. The primary button is an **off-white fill with a DARK ink
label** (`onPrimary:#1A1A1A`) — the inverse of light mode's cream-on-matcha.
The only chromatic color left in the dark is the clay error red (danger only).
Reader paper variants are neutral too: Sumi `#242424`, Charcoal `#141414`.
The old rule *"Sumi Dark has no shadows"* stays **retired** — dark elevation =
lighter surface as it rises + a neutral hairline ring + a 1px inset top
catch-light; port the shadow tokens (`--shadow-light-card` etc.). Use the
**`surfaceRaised`** layer for dialogs/sheets/popovers/floating mini-players (it
must clearly out-step the page behind it), and **`overlayField`** for any field
or tray nested *inside* an overlay — it steps UP (lighter) so inputs never sink
into a near-black hole.

### Scale, radii, spacing
- **Type:** 6 sizes (32 / 24 / 20 / 16 / 13 / 11) · 3 weights (400 / 500 / 600). The 11px size is the olive eyebrow caption only (`.nyan-caption` / `--fz-caption`), never body. UI face Noto Sans SC; reader serif Source Han Serif SC.
- **Radii:** chip 12 · control 14 · cardNested 16 · card 20 · panel 24 · dock 24 · sheet 28. Concentric inner = outer − padding (e.g. a 14 track with 3 padding → 11 inner; that 11 is intentional, not off-scale).
- **Spacing:** 4 / 8 / 12 / 16 / 20 / 24 / 32; min tap 44.
- **One Paper chrome:** every bar/sheet/dock floats `--inset: 12` from the edge; the dock *is* the collapsed sheet (`OnePaperDock` grows dock→sheet). Scrim `rgba(40,36,30,0.34)` + 2px blur in light; deepens to `0.58` in Sumi.

---

## 3. Brand mark

The app icon / splash mark was redesigned flat to the One Paper language (the old
gradient/3D render is retired). Production PNGs:
`assets/images/nyan_mark_v2.png` (transparent), `nyan_app_icon{,_matcha,_sumi}.png` (1024²).
Source geometry: `brand/nyan-mark.jsx`. Replace the Flutter launcher icon + splash
art with these; update the About-screen logo to `nyan_mark_v2.png`.

---

## 4. Conformance status (Phase 4 — DONE)

The structural split (Phases 1–3) and the conformance sweep (Phase 4) are both
complete. What Phase 4 changed:

1. **Local re-implementations removed.** `PageHdr` / `SectionHdr` / `RowGroup` /
   `ListRow` are now ONE canonical superset each in `screens/_chrome.jsx`; the
   divergent per-bundle copies in `bundle3.jsx` / `bundle4.jsx` are deleted.
   `NyanToggle` delegates to the kit `NyanSwitch` — a single switch impl.
2. **SplashScreen collapsed.** One presentational `NyanSplash` in `_chrome.jsx`;
   the kit's launch screen is a thin interactive wrapper (timer + tap-to-skip),
   the bundle-2 gallery a static `loading` snapshot. Splash keyframes moved to
   `colors_and_type.css` so the composition is self-contained anywhere.
3. **Radii snapped to scale** (16 values): icon buttons/tiles 13→14 (`--r-control`),
   small chips/thumbs 10→12 (`--r-chip`), 56px tiles 18→16 (`--r-card-nested`),
   brightness/dialog 22/24→`--r-dock`. Concentric inners (11 inside a 14 track) left intact.
4. **Scrims/sheets tokenised.** Warm-ink scrim blur now uses `--scrim-blur`;
   all sheets use `--r-sheet`, dialogs `--r-dock`. The brightness dialog keeps its
   intentional glassmorphism blur (a deliberate, user-requested exception).
5. **Type scale widened** to formally include the 11px eyebrow caption
   (`--fz-caption` / `.nyan-caption`).

When mirroring to Flutter, fold the equivalent header/row scaffolds into shared
widgets, give `NyanSwitch` the single toggle role, and add a `caption` text style.
