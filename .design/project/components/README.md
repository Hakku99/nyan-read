# Nyan Read — Component Library

Plain-JSX recreations of the **Nyan Read** Flutter widgets (`lib/core/ui/components/nyan_*.dart`), at the cosmetic level. These are the foundation every mock in `mocks/` is built from.

## Files (load in this order)

| File | Contains |
|---|---|
| `primitives.jsx` | `Icon`, `NyanPrimaryButton`, `PillButton` (outline-on-select), `NyanSwitch`, `NyanSlider`, `NyanFAB` |
| `headers.jsx`    | `NyanPageHeader`, `NyanSectionHeader`, `SegmentedTabControl` |
| `surfaces.jsx`   | `NyanInfoCard`, `NyanBottomSheet`, `NyanActionSheetRow`, `NyanResponse` (shared feedback toast), `NyanEmptyState` |
| `cards.jsx`      | `NyanBookGridCard`, `NyanContinueReadingCard` (collapsible), `NyanBookmarkCard`, `NyanListRow`, `NyanRowGroup` |
| `reader.jsx`     | `OnePaperDock`, `ReaderParagraph`, reader-chrome helpers |

All components are exported onto `window` so other `<script type="text/babel">` files can use them without imports.

## Usage

```html
<link rel="stylesheet" href="../colors_and_type.css" />
<!-- React + Babel UMD tags … -->
<script type="text/babel" src="../components/primitives.jsx"></script>
<script type="text/babel" src="../components/headers.jsx"></script>
<script type="text/babel" src="../components/surfaces.jsx"></script>
<script type="text/babel" src="../components/cards.jsx"></script>
<script type="text/babel" src="../components/reader.jsx"></script>
```

Full-screen compositions assembled from these live in `screens/` (`_chrome.jsx` + `bundle1–4`); the `mocks/` files load both layers.

## Exported on `window`

`Icon` · `NyanPrimaryButton` · `PillButton` · `NyanInfoCard` · `NyanSectionHeader` · `NyanPageHeader` · `NyanListRow` · `NyanRowGroup` · `NyanSwitch` · `SegmentedTabControl` · `NyanBookGridCard` · `NyanContinueReadingCard` · `NyanBookmarkCard` · `NyanEmptyState` · `NyanBottomSheet` · `NyanActionSheetRow` · `NyanFAB` · `NyanResponse` · `NyanSlider` · `OnePaperDock` · `ReaderParagraph`

## Tokens

Every component reads CSS variables from `colors_and_type.css` (colors, type, radii, shadows, spacing). Never hard-code values — if a token is missing, that's a design-system change.
