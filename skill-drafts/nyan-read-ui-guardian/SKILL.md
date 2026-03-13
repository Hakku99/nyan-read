---
name: nyan-read-ui-guardian
description: Enforce a consistent, calm, reading-first UI for Nyan Read. Use when implementing or reviewing Flutter UI, layout, theming, interaction surfaces, reusable components, design-token usage, or screen composition in this project.
---

# Nyan Read UI Guardian

Implement UI that feels calm, cozy, editorial, warm, minimal, and reading-first. Reuse existing patterns before inventing new ones, and keep styling token-driven.

## Required References

Before editing UI, read these files in `references/`:

- `design_tokens.md`
- `screen_blueprints.md`
- `flutter_rules.md`
- `component_catalog.md`

Load only the files needed for the task if the request is narrow. Read all four when creating a new screen, changing layout structure, or updating theme primitives.

## Workflow

Follow this sequence for every UI task:

1. Classify the screen using `screen_blueprints.md`.
2. Choose the matching layout template before writing widgets.
3. Check `component_catalog.md` and reuse or extend an approved component first.
4. Apply colors, spacing, radius, typography, and motion from `design_tokens.md`.
5. Follow Flutter implementation constraints from `flutter_rules.md`.
6. Verify the UI quality gate before finishing.

Never start from arbitrary layouts or hardcoded visual values.

## Implementation Rules

- Keep the experience reading-first and calm.
- Prefer simple hierarchy, generous spacing, and fast scanning over decoration.
- Use centralized theme tokens and `ThemeExtension` access patterns.
- Avoid hardcoded colors, spacing, radii, durations, and typography sizes.
- Preserve consistency across light and dark themes.
- Keep overlays short-lived and grouped.
- Maintain minimum 44x44 tap targets.
- Use clear widget names such as `BookshelfPage`, `ReaderPage`, or `NyanBookCard`.

## Screen Decisions

Use `screen_blueprints.md` to fit new work into an existing category:

- `Reader Screen` -> `Full Content + Overlay`
- `Library Screen` -> `Header + Mixed Shelf` or `Header + Grid`
- `Content List Screen` -> `Header + List`
- `Detail Screen` -> `Header + Scroll`
- `Utility Screen` -> `Header + List`
- `Overlay Screen` -> `Modal Sheet` or `Dialog`
- `System Screen` -> `Centered Hero`

Do not invent new layout families when an existing blueprint fits.

## Component Reuse

Check `component_catalog.md` before creating a new widget.

- Reuse existing components when they fit.
- Extend an existing component when the new UI is a close variant.
- Add genuinely new reusable components back into the catalog.
- Avoid isolated one-off widgets that duplicate catalog behavior.

## Quality Gate

Before finishing, confirm:

- tokens are used instead of hardcoded values
- the chosen blueprint matches the screen category
- spacing and radius are consistent
- the UI stays comfortable for long reading sessions
- reusable components were preferred over custom one-offs
- light and dark theme behavior still works

## References

Use the bundled references as the source of truth for:

- token values: `references/design_tokens.md`
- screen structure: `references/screen_blueprints.md`
- Flutter implementation rules: `references/flutter_rules.md`
- reusable components: `references/component_catalog.md`