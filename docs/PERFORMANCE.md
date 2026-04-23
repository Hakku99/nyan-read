# Nyan Read Performance Playbook

This document turns the architecture/performance constraints from `AGENTS.md` into repeatable engineering checks.

## 1) Non-negotiable rules

These are merge-blocking rules for reader-related changes.

- Use fine-grained subscriptions:
  - single field -> `Selector` / `context.select`
  - high-frequency scalar (`progress`, `brightness`, `warmth`, page index) -> `ValueNotifier` + `ValueListenableBuilder`
- Do **not** route high-frequency values through global `ChangeNotifier.notifyListeners()`.
- Keep `build()` pure:
  - no sorting/mapping-heavy transforms in `build`
  - no I/O, no parsing, no regex-heavy work in `build`
- Use isolate boundaries for CPU/I/O heavy paths:
  - EPUB parse, DB self-heal file ops, backup cleanup, large serialization
- Continuous slider-like writes must be debounced (`300ms`) before persistence.
- Overlay/hidden subtrees must short-circuit (`SizedBox.shrink`) instead of rebuilding when collapsed.
- Long lists use builder constructors (`ListView.builder`/`SliverList.builder`), and add `RepaintBoundary` where repaint churn is high.

## 2) Performance budgets

Use these practical budgets during review:

- Reader interaction:
  - no full-page rebuilds on 1s reading heartbeat
  - no dropped-frame bursts during normal page turns/tap gestures
- Persistence:
  - drag-heavy settings (font size/line height/brightness/warmth) should not produce per-tick disk writes
- Open-book path:
  - no UI-thread stalls from EPUB/PDF open/parse flow
  - heavy parsing runs off main isolate
- Background/exit:
  - pending debounced settings writes are flushed on pause/detach/exit

## 3) Mandatory verification matrix

When touching `reader_engine/**`, `modules/reader/**`, `core/services/database_service.dart`, or preference persistence:

1. Static check:
   - `flutter analyze`
2. Targeted tests:
   - `flutter test test/reader_controller_brightness_test.dart --reporter=expanded`
   - `flutter test test/reader_menu_test.dart --reporter=expanded`
   - `flutter test test/reading_progress_manager_test.dart --reporter=expanded`
   - `flutter test test/txt_reader_chapter_detection_test.dart --reporter=expanded`
   - `flutter test test/txt_reader_pagination_invalidation_test.dart --reporter=expanded`
3. Manual smoke:
   - open TXT/EPUB/PDF and verify no loading hang
   - show/hide reader overlay repeatedly (collapsed state should stay cheap)
   - drag brightness/warmth/font sliders continuously, background app, resume, reopen book

## 4) Regression checklist for PRs

Include this checklist in PR descriptions for performance-sensitive changes:

- [ ] State ownership unchanged (single source of truth preserved)
- [ ] Subscription granularity minimized (no broad `watch` where `select`/`ValueListenable` is enough)
- [ ] No new high-frequency `notifyListeners()` fan-out
- [ ] No build-time heavy compute/I/O introduced
- [ ] Debounced persistence behavior preserved
- [ ] Related targeted tests updated/passing

## 5) CI recipe (copy/paste)

Add a performance gate job that runs at least:

```bash
flutter analyze
flutter test test/reader_controller_brightness_test.dart --reporter=expanded
flutter test test/reader_menu_test.dart --reporter=expanded
flutter test test/reading_progress_manager_test.dart --reporter=expanded
flutter test test/txt_reader_chapter_detection_test.dart --reporter=expanded
flutter test test/txt_reader_pagination_invalidation_test.dart --reporter=expanded
```

On Windows runners, the in-flight pagination dedup case is intentionally skipped in the test file to avoid false-negative timeout noise.

## 6) Anti-pattern quick list

Reject changes that introduce:

- Global rebuild on heartbeat/progress tick
- Per-keystroke/per-drag `SharedPreferences` writes
- Reintroducing private `epub_view/src/*` imports
- Moving heavy file operations back onto main isolate
- Broad widget tree listening where leaf listenable binding exists
