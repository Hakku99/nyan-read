# Nyan Read Performance Playbook

This document turns the architecture/performance constraints from `AGENTS.md` into repeatable engineering checks.

The reader navigation diagnostic baseline and its explicit coverage limits are
recorded in [READER_NAVIGATION_BASELINE.md](READER_NAVIGATION_BASELINE.md).
It is an opt-in failing regression suite until the corresponding defects are
fixed; do not treat its current results as a release certification.
The 01A/02 implementation, remaining failures, and repeated emulator measurements
are recorded in [READER_TURN_FIXES_01A_02.md](READER_TURN_FIXES_01A_02.md).
The EPUB viewport navigation fix and authorized large-book validation are
recorded in [EPUB_TURN_FIX_03.md](EPUB_TURN_FIX_03.md).
The TXT turn-history invalidation fix and mixed-input validation are recorded in
[TXT_TURN_HISTORY_FIX_04.md](TXT_TURN_HISTORY_FIX_04.md).
Mode/reflow anchoring, cold recovery and paired before/after measurements are
recorded in [READER_REFLOW_FIX_05.md](READER_REFLOW_FIX_05.md). Compare both the
engine and the animation container; invalid intermediate runs and truncated
Android logs are excluded from final measurements.
Horizontal turn preparation, cancellation and image readiness are documented in
[READER_TURN_FIX_08.md](READER_TURN_FIX_08.md). Item 13 performance acceptance remains pending.

## 1) Non-negotiable rules

These are merge-blocking rules for reader-related changes.

- Use fine-grained subscriptions:
  - single field -> `ref.watch(provider.select((x) => x.field))`
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
   - `dart run tool/check_design_tokens.dart`
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
dart run tool/check_design_tokens.dart
flutter test test/reader_controller_brightness_test.dart --reporter=expanded
flutter test test/reader_menu_test.dart --reporter=expanded
flutter test test/reading_progress_manager_test.dart --reporter=expanded
flutter test test/txt_reader_chapter_detection_test.dart --reporter=expanded
flutter test test/txt_reader_pagination_invalidation_test.dart --reporter=expanded
```

On Windows runners, the in-flight pagination dedup case is intentionally skipped in the test file to avoid false-negative timeout noise.

## 6) Design token gate (lib/ hex colors)

This mirrors `AGENTS.md`: widget/feature code under `lib/` must not embed `Color(0x...)`
literals. Palette constants belong in `lib/core/theme/nyan_colors.dart`; preset wiring may
use literals in `lib/core/theme/theme_presets.dart` only.

Static gate (run locally or in CI after `flutter pub get`):

```bash
dart run tool/check_design_tokens.dart
```

Notes:

- `test/**` is intentionally not scanned (fixtures may use raw colors).
- `Colors.*` cleanup remains incremental and is reviewed manually until a stricter gate is agreed.

## 7) Anti-pattern quick list

Reject changes that introduce:

- Global rebuild on heartbeat/progress tick
- Per-keystroke/per-drag `SharedPreferences` writes
- Reintroducing private `epub_view/src/*` imports
- Moving heavy file operations back onto main isolate
- Broad widget tree listening where leaf listenable binding exists

G1 text-drag routing and its independent validation are documented in
[READER_GESTURE_FIX_G1.md](READER_GESTURE_FIX_G1.md).

G2 input arbitration and joint device evidence are documented in
[READER_GESTURE_FIX_G1_G2.md](READER_GESTURE_FIX_G1_G2.md). Those historical device
checks included the item 13 candidate and are not isolated performance evidence.

Item 13A independently compares the pinned G2 commit with the frozen rendering
candidate. Probes are injected only into a disposable profile project with a
separate application ID; production has no new timing listener. See
[READER_PERFORMANCE_13A_RESULTS.md](READER_PERFORMANCE_13A_RESULTS.md) and the
[reproduction guide](../tool/reader_baseline/README_13A.md).
Keep full-app, engine/container, overhead controls and heavy traces separate.
Foreground-window conditions materially affect emulator raster timings.
The candidate improves aggregate text-page results but still fails worst-round
acceptance; image-layout cancellation also exposes a shared position defect.
Do not mark item 13 accepted or infer synchronous image-disposal cost from a
slow reveal frame. The original scope is recorded in
[READER_PERFORMANCE_13A_PLAN.md](READER_PERFORMANCE_13A_PLAN.md).

## 8) PDF edge-tap latency on HONOR BKQ-N49 (60 Hz)

On 2026-11-19, two isolated profile builds ran on the same USB handset in PDF tap-to-turn mode.

| Build | Git commit | Tested APK SHA-256 |
|---|---|---|
| A | `3fee977bbe88134accc9df95165c75fbea2ba68b` | `62bc14fe1bbcae5fae67d1094008c888cedd0a89783a73403b3bf12cd1ce04fd` |
| B | `6ec98f9e4fcecb2a1cffc7320fc50a4999ce19ac` | `0f989277ba63d630a3fec2a2367299b59f431a26b04dacc05c9d31b483464f14` |

Both builds used the 13B-4 scanned and mixed-content PDFs. The AB run opened the scanned PDF first, and the BA run opened the mixed PDF first. Each tap used a 15 ms press halfway down the reading area, at 85% of its width for forward turns and 15% for backward turns.

Timing used the same monotonic clock for both markers within each build. `pointerUp` was recorded immediately before dispatching the synthetic Flutter pointer-up event. `accepted` was recorded when the reader passed its mounted, enabled and idle checks for the turn. Touchscreen sampling and Android input delivery precede this interval. Animation completion and display presentation follow it.

| Group | Matched pairs | A p50 (ms) | B p50 (ms) | Paired A−B p50 (ms) |
|---|---:|---:|---:|---:|
| All | 24 | 301.076 | 0.176 | 300.909 |
| AB | 12 | 301.070 | 0.176 | 300.895 |
| BA | 12 | 301.076 | 0.176 | 300.926 |
| Scanned PDF | 12 | 301.076 | 0.176 | 300.918 |
| Mixed PDF | 12 | 301.070 | 0.175 | 300.895 |

The p50 values use the 13B-4 nearest-rank convention. B accepted the turn sooner in all 24 pairs. The paired reductions ranged from 300.095 to 301.102 ms.

The table gives all 48 measured latencies in ms. Each pair matches the same PDF, phase, tap and page transition across builds. Each difference is A minus B, including in BA order.

| PDF | Phase | Page turn | AB · A | AB · B | AB · A−B | BA · A | BA · B | BA · A−B |
|---|---|---|---:|---:|---:|---:|---:|---:|
| Scanned | First | 24→25 | 301.109 | 0.191 | 300.918 | 300.953 | 0.190 | 300.763 |
| Scanned | First | 25→24 | 301.221 | 0.150 | 301.071 | 301.162 | 0.176 | 300.986 |
| Scanned | After warm-up | 24→25 | 301.068 | 0.205 | 300.863 | 300.285 | 0.190 | 300.095 |
| Scanned | After warm-up | 25→26 | 301.133 | 0.167 | 300.966 | 301.125 | 0.167 | 300.958 |
| Scanned | After warm-up | 26→25 | 300.934 | 0.188 | 300.746 | 301.076 | 0.150 | 300.926 |
| Scanned | After warm-up | 25→24 | 301.278 | 0.176 | 301.102 | 300.902 | 0.178 | 300.724 |
| Mixed | First | 3→4 | 301.098 | 0.189 | 300.909 | 300.778 | 0.188 | 300.590 |
| Mixed | First | 4→3 | 300.956 | 0.148 | 300.808 | 301.144 | 0.166 | 300.978 |
| Mixed | After warm-up | 3→4 | 301.139 | 0.179 | 300.960 | 300.955 | 0.175 | 300.780 |
| Mixed | After warm-up | 4→5 | 300.983 | 0.158 | 300.825 | 301.206 | 0.190 | 301.016 |
| Mixed | After warm-up | 5→4 | 301.070 | 0.175 | 300.895 | 301.215 | 0.136 | 301.079 |
| Mixed | After warm-up | 4→3 | 300.883 | 0.180 | 300.703 | 301.251 | 0.179 | 301.072 |

All 48 measured taps and the 16 warm-up taps each produced one acceptance, one engine call in the requested direction and one animation completion. On the next frame and again 150 ms later, the page number had advanced or retreated by exactly one. The four measured rounds completed with continuous monitoring, zero timeouts and zero replacement taps. The 16 warm-up taps are excluded from the latency figures.

Local evidence is under `.dart_tool/pdfedge_phone/`. The paired values are in `paired.csv`, and per-tap events, page checks and foreground/refresh-rate logs are in `rounds/`. The initial launch stopped before any input because the app could not read its configuration. That startup record is in `results/`.

## 9) PDF gesture regression on HONOR BKQ-N49 (60 Hz)

### Gesture checks on `6ec98f9`

Of 76 cases, **72 passed and 4 failed**. Each 13B-4 PDF had 36 passes and 2 failures. The isolated profile build received touch events through Flutter on the handset. Each check compared the page number, scale and image position after settling and again 150 ms later.

| Gesture | Passed / tested (both PDFs) | Observed result |
|---|---:|---|
| Center double tap and independent single tap | 4 / 4 | The double tap zoomed once on the same page. The single tap opened the controls once. |
| Two-finger zoom | 8 / 8 | Pinching at the left edge, center, right edge or across both edges enlarged and reduced the image on the same page. |
| Drag after zoom | 6 / 6 | At 3× fit scale, drags from the center and either edge moved the image 45 logical pixels. Scale and page stayed fixed. |
| Horizontal swipe in tap mode | 8 / 8 | With the edge partition enabled or disabled, the reader accepted each swipe once and turned one page in the requested direction. |
| Overlapping edge and center touches | 32 / 32 | Stationary fingers produced no action. Spreading them zoomed. Lifting either finger caused no turn. The next independent edge tap turned one page. |
| Taps across the 20% and 80% boundaries | 8 / 8 | In either tap order, only the edge tap turned a page. Neither zoom nor controls opened. |
| Canceled edge touch | 4 / 4 | Cancellation left the page fixed. The next independent tap turned one page. |
| Edge double tap in swipe mode | 2 / 2 | PhotoView zoomed on the same page. |
| Upward swipe at fit scale in tap and swipe modes | 0 / 4 | The scanned PDF stayed on page 24 (expected 25), and the mixed PDF stayed on page 3 (expected 4). Each case stopped on the failed forward swipe. |

Four groups in this gesture run had a host counter mismatch during finalization. Their case exports, unique completion markers and subsequent 60 Hz foreground samples were present and used to verify the results. Local evidence is in `.dart_tool/pdfgesture_honor/summary.json` and `.dart_tool/pdfgesture_honor/rounds/`.

### Upward-swipe A/B comparison

A was `3fee977` and B was `6ec98f9`. Each pair used the same PDF, mode, starting page and fit scale. One finger moved from (85%, 80%) to (85%, 20%) of the reading area in 12 equal steps scheduled 18 ms apart, then held for 60 ms before release. A passing swipe would advance the gallery by exactly one page.

**Six of eight pairs reproduced the pre-existing behavior on A and B. Two pairs were indeterminate after monitor heartbeat timeouts.** Of 16 scheduled swipes, 15 were sent and 14 had complete monitoring. Across those 14, `PhotoViewGestureRecognizer` won and the gallery's vertical drag recognizer was rejected. PhotoView recorded one start, 12 updates and one end for each swipe. There was no gallery scroll notification or page-change event.

The table lists A then B in each result cell, including for BA execution order. Gallery displacement is relative to the position at pointer down, in Flutter logical pixels. Every observed maximum was zero, including the displacement at release and after settling.

| PDF | Turn mode | Run order | Maximum gallery displacement (A / B) | Stable page (A / B) | Pair result |
|---|---|---|---:|---|---|
| Scanned | Tap | AB | 0 / 0 | 24 / 24 | Pre-existing |
| Scanned | Tap | BA | 0 / 0 | 24 / 24 | Pre-existing |
| Scanned | Swipe | AB | 0 / 0 | 24 / 24 | Pre-existing |
| Scanned | Swipe | BA | 0 / 0 | 24 / 24 | Pre-existing |
| Mixed | Tap | AB | 0 / 0 | 3 / 3 | Indeterminate. B recorded PhotoView ownership, release and the stable page before the final heartbeat timed out. |
| Mixed | Tap | BA | 0 / 0 | 3 / 3 | Pre-existing |
| Mixed | Swipe | AB | 0 / 0 | 3 / 3 | Pre-existing |
| Mixed | Swipe | BA | — / 0 | — / 3 | Indeterminate. A timed out before app launch and received no input. |

Neither interrupted case was retried. Per-swipe recognizer decisions, offsets and page snapshots are in `.dart_tool/pdfvertical_ab/observations.json`. The original device and heartbeat logs are in `.dart_tool/pdfvertical_ab/rounds/`.
