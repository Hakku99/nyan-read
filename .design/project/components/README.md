# Nyan Read — Component Library

Plain-JSX recreations of the **Nyan Read** Flutter widgets (`lib/core/ui/components/nyan_*.dart`), at the cosmetic level. These are the foundation every mock in `mocks/` is built from.

## How these are loaded

This project **is** a design system: the compiler reads every `<Name>.jsx` that has a sibling `<Name>.d.ts` and bundles them into `_ds_bundle.js`. **Do not load the individual `.jsx` files** — load the one bundle and read components off the namespace:

```html
<link rel="stylesheet" href="../colors_and_type.css" />
<link rel="stylesheet" href="https://unpkg.com/@phosphor-icons/web@2.1.1/src/regular/style.css" />
<link rel="stylesheet" href="https://unpkg.com/@phosphor-icons/web@2.1.1/src/fill/style.css" />
<!-- React + ReactDOM UMD … -->
<script src="../_ds_bundle.js"></script>
<script>
  // exact namespace is printed by the compiler; it starts with NyanReadDesignSystem_
  const NS = window[Object.keys(window).find(k => k.startsWith("NyanReadDesignSystem_"))];
  const { NyanBookGridCard, PillButton, OnePaperDock } = NS;
</script>
```

The `mocks/*.html` files do exactly this and then flatten `NS` onto `window`, so the screen code reads `NyanBookGridCard` unqualified.

## One file per component

Each component lives in its own file next to a `.d.ts` prop contract and is grouped by layer:

| Folder | Components |
|---|---|
| `primitives/` | `Icon`, `NyanPrimaryButton`, `PillButton` (outline-on-select), `NyanSwitch`, `SegmentedTabControl`, `NyanSlider`, `SearchField`, `TextField`, `Checkbox`, `ProgressBar` (the one reading-progress track), `Skeleton` |
| `navigation/` | `NyanPageHeader`, `NyanSectionHeader` |
| `surfaces/`   | `NyanInfoCard`, `NyanListRow`, `NyanRowGroup`, `NyanEmptyState`, `NyanBottomSheet`, `NyanActionSheetRow`, `NyanFAB`, `NyanResponse` (the shared feedback toast), `NyanOptionSheet`, `NyanDialog` (centered confirm / alert) |
| `cards/`      | `NyanBookGridCard`, `NyanContinueReadingCard` (collapsible), `NyanBookmarkCard`, `BookListRow` |
| `reader/`     | `OnePaperDock`, `DockFooter`, `ReaderSettingsBody`, `DisplayPanel`, `TextPanel`, `ThemePanel`, `ReaderChapterList`, `ReaderParagraph`, `Knob`, `TextSelectionMenu`, `HighlightSwatchRow`, `TTSPlayer`, `PdfControls`, `InBookSearch` |
| `security/`   | `PinDots`, `PinPad` (the privacy-shelf gate) |

Cross-component dependencies use real `import` statements (e.g. `cards/NyanContinueReadingCard.jsx` imports `Icon` from `../primitives/Icon.jsx`); the compiler resolves them. Every folder also has a `@dsCard`-tagged `*.html` that renders its components for the Design System review tab.

## Props

Every component has a sibling `<Name>.d.ts` with a typed `Props` interface — that is the source of truth for the API. Read it before using a component.

## Tokens

Every component reads CSS variables from `colors_and_type.css` (colors, type, radii, shadows, spacing). Never hard-code values — if a token is missing, that's a design-system change.

## Flutter widget map

These mirror `lib/core/ui/components/nyan_*.dart` cosmetically. When fidelity matters, cross-reference the Flutter source at <https://github.com/Hakku99/nyan-read>.
