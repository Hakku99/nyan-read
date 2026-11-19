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

## 10) Fit-scale PDF upward-swipe acceptance on HONOR BKQ-N49 (60 Hz)

All four PDF and turn-mode combinations passed on `83cbd1b`. Each completed case used one upward swipe on the same handset and 13B-4 sample as its `6ec98f9` reference in section 9. At fit scale, one finger moved from (85%, 80%) to (85%, 20%) of the reading area in 12 equal steps scheduled 18 ms apart. After the 60 ms hold, the probe sampled gallery position immediately before dispatching `pointerUp`. Displacement is relative to the position at pointer down, in Flutter logical pixels.

| 13B-4 PDF | Turn mode | `6ec98f9` reference | `6ec98f9` winner / stable page | `83cbd1b` winner | Pre-release displacement on `83cbd1b` | Page changes on `83cbd1b` | Start → stable page |
|---|---|---|---|---|---:|---:|---|
| Scanned | Tap | `pdf_scan-tap-AB-B` | PhotoView / 24 | Gallery | +398.514 | 1 | 24 → 25 |
| Scanned | Swipe | `pdf_scan-mode-AB-B` | PhotoView / 24 | Gallery | +398.514 | 1 | 24 → 25 |
| Mixed | Tap | `pdf_mixed-tap-BA-B` | PhotoView / 3 | Gallery | +398.514 | 1 | 3 → 4 |
| Mixed | Swipe | `pdf_mixed-mode-AB-B` | PhotoView / 3 | Gallery | +398.514 | 1 | 3 → 4 |

In all four baseline recordings, gallery displacement and page-change count were both zero. On `83cbd1b`, the gallery’s `VerticalDragGestureRecognizer` won each swipe and PhotoView’s scale recognizer was rejected. Each swipe produced exactly one page-change event. After scrolling stopped and again 150 ms later, the gallery was on the target page at fit scale.

The first scanned-PDF tap-mode case stopped before launch when the installed APK path lookup timed out after 5 seconds. No swipe was sent. A separately recorded case reused the same installed APK and passed with one swipe from page 24. The other three cases passed on their original runs.

Local evidence is in `.dart_tool/pdfvertical_ab/observations.json` for the baseline, `.dart_tool/pdfvertical_83cbd1b_honor/results.json` for the original four case records (including the stop), and `.dart_tool/pdfvertical_scan_tap_20261119_232224/results.json` for the separate scanned-PDF tap-mode pass.

## 11) Remaining PDF gesture regression on HONOR BKQ-N49 (60 Hz)

In the original round, the isolated profile build of `83cbd1b` passed 71 of the 72 cases that passed on `6ec98f9` in section 9. One case stopped before input. A separate run of that case brought the cumulative result to **72/72 passed**, as shown below. The scanned 13B-4 PDF started on page 24 and the mixed-content PDF on page 3, both at fit scale. Section 10 covers the four fit-scale vertical swipes separately.

| Gesture | Evidence group | Scanned PDF (passed / planned) | Mixed PDF (passed / planned) |
|---|---|---:|---:|
| Center double tap and independent single tap | `center` | 2 / 2 | 2 / 2 |
| Two-finger spread and contract (left, center, right, across both edges) | `pinch` | 4 / 4 | 4 / 4 |
| Drag after zoom (center, left and right) | `pan` | 3 / 3 | 3 / 3 |
| Horizontal swipe in tap mode (both directions, edge partition on and off) | `swipes` | 4 / 4 | 4 / 4 |
| Overlapping edge and center touches, followed by an independent edge tap | `cross` | 16 / 16 | 16 / 16 |
| Tap pairs across the 20% and 80% boundaries | `boundary` | 4 / 4 | 4 / 4 |
| Canceled left or right edge touch, followed by an independent tap | `cancel` | 2 / 2 | 2 / 2 |
| Edge double tap in swipe mode | `mode` | 1 / 1 | 1 / 1 |
| **Cumulative total** | | **36 / 36** | **36 / 36** |

Across the 122 completed steps, the gesture handler, page-change count and stable page matched the corresponding baseline step. The final scale (relative to fit) and image displacement also matched within 0.001× and 0.001 Flutter logical pixels per axis. At 3× fit, all six drags moved the image down 45 logical pixels on the same page. Each horizontal swipe turned exactly one page in the requested direction. Each stable snapshot was checked again 150 ms later.

**Original stop.** For the mixed PDF's left-edge pinch, the host monitor ended after startup validation and before it authorized input. The app timed out waiting for authorization. Neither the spread nor the contraction was sent in that round. The remaining three pinch locations ran once each. The stop record and app error are in `.dart_tool/pdfgesture_83cbd1b_honor/rounds/pdf_mixed-pinch-01/`.

**Separate left-edge pinch case.** The same installed APK ran one spread and one contraction on page 3 of the mixed PDF. PhotoView handled both steps. The spread increased the scale from 1× fit to 3×, and the contraction returned it to 1×, matching `6ec98f9`. Each step produced (0, 0) logical pixels of image displacement and zero page-change events. Both steps settled on page 3 and remained there at the 150 ms check. The per-step record is in `.dart_tool/pdfgesture_mixed_left_20261119_234327/pdfgesture_mixed_left_20261119_234327-case.json`.

**Local evidence.** Under `.dart_tool/pdfgesture_83cbd1b_honor/`, `report.md` lists every case by PDF with both builds' step results. In `comparison.json`, each case's `evidence` field identifies its directory under `rounds/`, which holds the raw case export or stop record and the foreground and heartbeat log. The matching `6ec98f9` case is under `.dart_tool/pdfgesture_honor/rounds/<pdf>-<group>/`, keyed by the same case name.

## 12) PDF gesture fix closeout on HONOR BKQ-N49 (60 Hz)

Functional acceptance is complete for `83cbd1b` on the two 13B-4 PDFs. **76/76 cases passed cumulatively** on the isolated profile build. In all four fit-scale upward swipes (section 10), the gallery moved +398.514 Flutter logical pixels before release and advanced exactly one page in both turn modes. The scanned PDF settled on page 25 from page 24, and the mixed PDF on page 4 from page 3. All 72 remaining gesture cases matched the `6ec98f9` baseline (section 11).

The edge-tap latency measurements in section 8 cover `3fee977` and `6ec98f9` only. Across 24 matched pairs (48 taps), median `pointerUp → accepted` latency fell from 301.076 ms to 0.176 ms, with a median paired reduction of 300.909 ms. This interval starts immediately before Flutter dispatches the synthetic pointer-up event and ends when the reader accepts the page turn.

### Unverified scope

- Edge-tap latency on `83cbd1b` and end-to-end time from physical touch to visible page change. Touchscreen sampling, Android input delivery, animation completion and display presentation fall outside the section 8 interval.
- Other devices, platforms (including iOS), refresh rates and PDF layouts. Fit-scale swipe acceptance on this handset covers the original 12-step upward trajectory. A downward swipe to the previous page remains unverified.
- Sustained frame pacing, heat and battery use during extended reading sessions.

## 13) PDF edge-tap latency after the gesture fix on HONOR BKQ-N49 (60 Hz)

This follow-up measures the `83cbd1b` edge-tap latency left open in section 12. The isolated profile build used the same handset, two 13B-4 PDFs and tap-to-turn mode as section 8. Each synthetic tap held for 15 ms at 50% of the reading area's height and at 85% of its width to advance or 15% to go back. Round 1 opened the scanned PDF first and pairs with the historical `6ec98f9` AB round. Round 2 opened the mixed PDF first and pairs with the historical BA round.

Both markers use the same monotonic clock within each build. `pointerUp → accepted` starts immediately before Flutter dispatches the synthetic pointer-up event and ends when the reader accepts the turn after its mounted, enabled and idle checks. Touchscreen sampling and Android input delivery precede this interval. Animation completion and display presentation follow it.

Across 24 matched pairs, nearest-rank p50 was **0.176 ms on `6ec98f9`** and **0.167 ms on `83cbd1b`**. The p50 of the 24 individual differences (`83cbd1b` minus `6ec98f9`) was **−0.007 ms**, with a range of −0.047 to +0.061 ms. The largest delay on `83cbd1b` was 0.205 ms. These historical pairs show no recurrence of the roughly 300 ms wait in this sample.

Each row gives one matched tap per round. All table values for latency and difference (Δ) are in microseconds.

| PDF | Phase | Page turn | R1 · `6ec98f9` | R1 · `83cbd1b` | R1 · Δ | R2 · `6ec98f9` | R2 · `83cbd1b` | R2 · Δ |
|---|---|---|---:|---:|---:|---:|---:|---:|
| Scanned | First | 24→25 | 191 | 186 | −5 | 190 | 167 | −23 |
| Scanned | First | 25→24 | 150 | 182 | +32 | 176 | 178 | +2 |
| Scanned | After warm-up | 24→25 | 205 | 205 | 0 | 190 | 203 | +13 |
| Scanned | After warm-up | 25→26 | 167 | 151 | −16 | 167 | 167 | 0 |
| Scanned | After warm-up | 26→25 | 188 | 148 | −40 | 150 | 140 | −10 |
| Scanned | After warm-up | 25→24 | 176 | 159 | −17 | 178 | 181 | +3 |
| Mixed | First | 3→4 | 189 | 142 | −47 | 188 | 181 | −7 |
| Mixed | First | 4→3 | 148 | 167 | +19 | 166 | 146 | −20 |
| Mixed | After warm-up | 3→4 | 179 | 181 | +2 | 175 | 183 | +8 |
| Mixed | After warm-up | 4→5 | 158 | 137 | −21 | 190 | 178 | −12 |
| Mixed | After warm-up | 5→4 | 175 | 182 | +7 | 136 | 197 | +61 |
| Mixed | After warm-up | 4→3 | 180 | 149 | −31 | 179 | 141 | −38 |

**Single-page checks.** All 24 measured taps and all 8 warm-up taps on `83cbd1b` produced one acceptance, one engine call in the requested direction and one animation completion each. The next frame and the check 150 ms later both showed the expected adjacent page. Both rounds completed with continuous monitoring, zero timeouts and zero replacement taps. Only the 24 measured taps contribute to the latency statistics.

**Local evidence.** Under `.dart_tool/pdfedge_83cbd1b_honor/`, `paired.csv` records both latencies, their difference and the page checks for each measured tap. `warmup.csv` records the eight warm-up checks. The raw events and monitor logs are in `rounds/edge-83-1/` and `rounds/edge-83-2/`. The historical values come from the `B_ms` column of `.dart_tool/pdfedge_phone/paired.csv`, matched by round order, PDF, phase, tap and page transition.

## 14) Fit-scale PDF downward swipe to the previous page on HONOR BKQ-N49 (60 Hz)

All four cases passed on the isolated `83cbd1b` profile build. Each case started on the page reached by its upward swipe in section 10. One finger followed the reverse path from (85%, 20%) to (85%, 80%) of the reading area in 12 equal steps scheduled 18 ms apart. After a 60 ms hold, the probe measured the gallery's displacement from its position at pointer down, immediately before dispatching `pointerUp`.

| 13B-4 PDF | Turn mode | Gesture winner | Pre-release displacement (Flutter logical px) | Page changes | Start → settled page | Page 150 ms later | Case export under `.dart_tool/pdfdown_83cbd1b_honor/rounds/` |
|---|---|---|---:|---:|---|---:|---|
| Scanned | Tap | Gallery | −398.514 | 1 | 25 → 24 | 24 | `pdf_scan-tap-C/pdf_scan-tap-C-case.json` |
| Scanned | Swipe | Gallery | −398.514 | 1 | 25 → 24 | 24 | `pdf_scan-mode-C/pdf_scan-mode-C-case.json` |
| Mixed | Tap | Gallery | −398.514 | 1 | 4 → 3 | 3 | `pdf_mixed-tap-C/pdf_mixed-tap-C-case.json` |
| Mixed | Swipe | Gallery | −398.514 | 1 | 4 → 3 | 3 | `pdf_mixed-mode-C/pdf_mixed-mode-C-case.json` |

The gallery's `VerticalDragGestureRecognizer` won each swipe and PhotoView's scale recognizer was rejected. Each swipe produced exactly one page-change event. Once scrolling stopped and again 150 ms later, the previous page was centered at fit scale. All four cases completed with continuous monitoring and no replacement swipes.

The per-case checks are in `.dart_tool/pdfdown_83cbd1b_honor/results.json`. Each case export in the table has a `monitor.jsonl` alongside it with the foreground, refresh-rate and heartbeat records.
