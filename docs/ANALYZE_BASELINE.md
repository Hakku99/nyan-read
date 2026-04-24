# Analyze Baseline (Post P2-2)

Date: 2026-04-24

## Current status

- `flutter analyze` completes without compile errors.
- Baseline currently reports **57 issues** (info/warning), mostly legacy lint debt.
- No `provider` runtime dependency remains in `lib/**`.

## Top issue buckets

- **Flow style / braces**
  - `curly_braces_in_flow_control_structures`
  - Seen in core services and utility modules.
- **Unused code/imports**
  - `unused_import`, `unused_field`, `unused_local_variable`.
- **Style/modernization**
  - `use_super_parameters`, `annotate_overrides`, `prefer_interpolation_to_compose_strings`.
- **Tooling scripts/tests**
  - `avoid_print` in local repro tools and selected tests.

## Notable files with higher density

- `lib/core/services/database_service.dart`
- `lib/core/services/backup_recovery_service.dart`
- `lib/modules/reader/reader_engine/**`
- `tool/reproduce_scan.dart`

## Recommendation for next cleanup batch

1. Triage by risk: low-risk lint-only files first (`core/ui`, `tool/`, tests).
2. Keep runtime behavior unchanged; do style-only edits in dedicated commits.
3. Raise lint strictness incrementally after each green batch.
