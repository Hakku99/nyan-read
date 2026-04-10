# Reading Settings UI — validation checklist

Manual checks after UI changes (complements `test/reader_menu_test.dart`).

## Capability matrix

| Engine caps | Display | Text | Theme | Chapter prev/next |
|-------------|---------|------|-------|-------------------|
| Full (TXT-like) | Yes | Yes | Yes | Per `chapterNavigation` |
| No typography | Yes | No | No | Per navigation |
| No theme | Yes | Yes/No | No | Per navigation |
| Synthetic chapters | Yes | … | … | Arrows visible |

## Localization

- Switch app language EN ↔ ZH; confirm tab labels (`Display`/`显示`, etc.), hints, reset row, and preview sample text.
- No overflow on small width (320px): typography stacks vertically; segmented tabs ellipsize safely.

## Interactions

- **Header**: Title only; chapter + percent appear only in the progress card (no duplicate “Reading progress” line).
- **Brightness**: With Auto on, slider is dimmed and non-interactive; toggle Auto off and adjust; value persists.
- **Warmth**: Low / Medium / High chips snap to 0 / 0.5 / 1; slider still adjustable.
- **Typography**: Presets apply font + line height; +/- respect min/max clamps.
- **Theme**: Selected card shows border + check indicators; tap switches background.
- **Reset**: Resets font (18), line height (1.5), background (`0xFFFDFCF8`), warmth (0); Snackbar shown; brightness follow-system unchanged.

## A11y

- Chapter arrows and Auto chip meet min tap height (44).
- Theme cards expose `Semantics` label + selected state.

## Regression guard (reader core)

- Reset and theme changes do not alter saved reading position or chapter index by themselves.
- Pagination determinism unchanged (no engine/pagination edits in this feature).
