# Comprehensive Architecture Risk Analysis & Refactoring Plan

Senior Flutter Architect / Performance Optimization Review  
Project: Nyan Read (Flutter offline e-book reader)

---

## Scope

This document consolidates the full architecture risk assessment into a single handoff artifact and adds an execution checklist so future sessions can close items one by one.

Primary focus areas:

- Pagination correctness and determinism (TXT/EPUB)
- Brightness UX and gesture conflict safety
- Database backup/recovery correctness and write-path stability

---

## Module A — App Bootstrap, Routing, Global Composition

### Identified Risks / Logical Flaws

- Bootstrap timeout path can enter a partially initialized state if async singletons are still resolving while UI already shows a fatal error shell.
- `BackupRecoveryService.dispose()` is not process-kill safe (mobile OS can terminate without Flutter widget disposal).
- Auto-lock timing relies on wall clock (`DateTime.now`) and is vulnerable to clock jumps.
- Delayed scavenger/startup background tasks are fire-and-forget without lifecycle cancellation.

### Architectural Solutions / Optimization Strategies

- Replace hard timeout failure with staged readiness diagnostics (`registered` plus `ready`).
- Add lifecycle-safe emergency flush/shutdown hooks for persistence-critical services.
- Use monotonic timing (`Stopwatch`) for lock timeout windows.
- Keep startup timers cancellable and owned by lifecycle-aware services.

---

## Module B — Reader Session Orchestration (`ReaderController` and managers)

### Identified Risks / Logical Flaws

- Page-turn queue behavior can accumulate lag under rapid input bursts.
- Microtask-based load can still run after disposal if not guarded early.
- Observer lifecycle can outlive visible reader in provider teardown windows.
- Layout-change font adaptation can diverge from persisted source-of-truth preferences.
- Multiple load-phase notifications cause avoidable full-subtree rebuild churn.

### Architectural Solutions / Optimization Strategies

- Convert queue behavior to bounded dedup/merge semantics under burst input.
- Add disposal guards at method entry before any await or heavy work.
- Ensure observer unregistration is explicit and early on deactivation.
- Route adaptive display changes through explicit, persisted preference policy.
- Replace ad-hoc epochs with explicit load state machine transitions.

---

## Module C — Reader Engine Contract & Factory

### Identified Risks / Logical Flaws

- Unknown format fallback to TXT engine can silently parse binary formats as text.
- Base contract includes default no-op behaviors that can hide missing engine overrides.
- Format-specific position model parsing is centralized in shared model, reducing extensibility.

### Architectural Solutions / Optimization Strategies

- Fail fast on unsupported formats and map to explicit user-facing error state.
- Enforce capability/contract overrides for required engine actions.
- Move per-format position decode logic behind engine-specific serializers/factories.

---

## Module D — TXT Reader Engine & Pagination (High Risk)

### Identified Risks / Logical Flaws

- **TextPainter estimation mismatch**: estimation path does not faithfully mirror real list item layout composition, paragraph spacing, and runtime text scaling, creating page-count drift and perceived skipping/repetition.
- **Determinism gap**: history/anchor-driven backward logic can diverge from pure position-based pagination after seek/reopen.
- **Chapter regex fragility**: complex chapter regex rules are brittle with noisy web-novel formats and can trigger heavy backtracking in pathological lines.
- **Isolate OOM pressure**: full decode + split-all-lines model creates high peak memory and long-lived allocations on large TXT files (50MB+ scenarios).
- **Encoding fallback ambiguity**: decode fallback can “succeed” while producing mojibake without confidence heuristics.

### Architectural Solutions / Optimization Strategies

- Rebuild pagination estimate around actual render constraints, include `TextScaler`, paragraph spacing, and representative sampling strategy.
- Move to deterministic offset/page mapping (position as pure function, not interaction history artifact).
- Add chapter-parse prefilters (length/keyword fast path), simplify regex pipeline, and protect parse steps against pathological inputs.
- Introduce chunked/lazy text processing roadmap to lower peak memory and avoid split-all retention.
- Add encoding detection confidence checks and optional user override path.

---

## Module E — EPUB Engine

### Identified Risks / Logical Flaws

- Double-parse/open path can spike memory for large EPUBs.
- View-ready timeout path can silently fail restore-to-position.
- Dynamic position extraction from third-party objects is runtime fragile.
- Highlight capability mismatch can leak stale metadata workflows.
- Frequent progress polling can become expensive if CFI extraction is repeatedly heavy.

### Architectural Solutions / Optimization Strategies

- Reduce duplicate parse/open overhead through reusable parse artifacts or cache strategy.
- Make view readiness failure explicit and propagate to user-visible error state.
- Wrap third-party dynamic position payloads at the integration boundary.
- Hard-gate highlight flows by engine capability.
- Memoize/throttle expensive position extraction calls.

---

## Module F — PDF Engine

### Identified Risks / Logical Flaws

- Chapter list readiness can race with async document open, temporarily yielding empty TOC.
- Temp file lifecycle can conflict with async open/dispose timing.
- Synthetic chapter generation is currently simple but should be guarded for very large docs.

### Architectural Solutions / Optimization Strategies

- Tie TOC availability to explicit document-ready completion.
- Track temp-file ownership with open-completion-aware cleanup.
- Cap and/or defer synthetic chapter generation where needed.

---

## Module G — Reader UI, Gestures, Brightness UX (High Risk)

### Identified Risks / Logical Flaws

- Tap/gesture arena collisions can cause highlight interactions to compete with page-turn taps.
- Page-turn lock flag can stall future turns if an async turn path hangs.
- Edge brightness gesture zone can conflict with OS/system gestures.
- Swipe thresholds/velocity heuristics can still trigger accidental turns in slow drags.
- Brightness state churn can produce redundant rebuild pressure during follow-system animations.
- Resume/restore brightness can feel abrupt (“flash”) in some ambient transitions.

### Architectural Solutions / Optimization Strategies

- Add explicit interaction arbitration priority (text selection/highlight wins over page-turn).
- Add timeout and recovery path for in-flight page-turn guard flags.
- Separate/adjust edge zones by platform conventions and safe areas.
- Tighten swipe intent classification (distance + velocity + direction confidence).
- Add state equality and notifier dedup discipline for brightness flows.
- Apply smooth transition curves on resume/mode-switch paths.

---

## Module H — Bookshelf & Import Pipeline

### Identified Risks / Logical Flaws

- Signature/fingerprint computation can block UX when executed serially on UI-critical flow.
- Legacy library migration path (backfilling signatures) can produce long first-import stalls.
- Batch source delete workflow is fully sequential and can feel frozen for large batches.
- Hashing pipeline does avoidable intermediate allocations.

### Architectural Solutions / Optimization Strategies

- Move expensive signature/index tasks off main isolate with bounded parallelism.
- Run signature backfill incrementally in background windows.
- Parallelize deletion with robust best-effort reporting and cancellation tolerance.
- Use streaming/chunked hash updates to cut transient allocations.

---

## Module I — Database, Backup/Recovery, Data Portability (High Risk)

### Identified Risks / Logical Flaws

- **Cold backup safety**: raw copying DB/WAL/SHM while DB is active is cross-platform fragile and can produce recoverable-but-stale snapshots.
- Integrity-heal path opens additional DB handles in sensitive windows and may face lock/busy edge cases.
- Restore rename/copy flow has platform-specific file protection edge cases.
- Debounced prefs/database flush behavior is robust but still needs strict disposal race hardening.
- Some direct service resolution patterns bypass intended DI boundaries.

### Architectural Solutions / Optimization Strategies

- Prefer SQLite-consistent backup primitives (`VACUUM INTO` or equivalent safe snapshot strategy) over raw triad file copy.
- Minimize parallel DB handle strategies during integrity checks; centralize sequencing.
- Add restore fallback branches with retry and copy-delete strategy.
- Harden dispose-time flush guards and guarantee idempotent finalization.
- Enforce constructor/provider injection for service access in feature layers.

---

## Module J — Privacy / PIN / Access Control

### Identified Risks / Logical Flaws

- PIN salt generation quality needs stronger entropy model.
- Lifecycle auto-lock decisions can be bypassed by restart/resume edge cases.
- Overlay pop/back-stack constraints need strict non-bypass handling.
- Legacy privacy paths coexist with newer PIN-centric approach and should be rationalized.

### Architectural Solutions / Optimization Strategies

- Move to secure random salt and stronger KDF policy.
- Enforce session token lock invariants across resume/restart paths.
- Add hard pop guards in verification overlays.
- Remove or deprecate legacy privacy code paths with migration note.

---

## Module K — Settings, Theme, Localization, Feature Flags

### Identified Risks / Logical Flaws

- Theme mode behavior may diverge from modern system-follow expectations.
- Feature gating stored in plain prefs is easy to tamper on rooted devices.
- Settings layer still contains direct locator calls outside preferred injection pattern.
- Unknown preset fallback behavior is silent.

### Architectural Solutions / Optimization Strategies

- Formalize theme policy (`light`/`dark`/`system`) and keep system chrome aligned.
- Restrict admin toggles in production builds.
- Complete DI cleanup via providers/constructor injection.
- Add explicit logging and migration hints for invalid preset payloads.

---

## Module L — Shared Utilities & UI Primitives

### Identified Risks / Logical Flaws

- `anchor_healer.dart` can degrade with many short/common highlight matches (high candidate count).
- Source availability is detected late (open-time), with weak pre-open shelf signaling.
- Timer/subscription disposal patterns do not cancel in-flight async work.
- Recognizer pooling in heavy-highlight scenes needs practical guardrails and stress tests.

### Architectural Solutions / Optimization Strategies

- Offload anchor healing to isolate and skip low-confidence tiny-token healing cases.
- Add background source health checks and shelf-level warning indicators.
- Use snapshot-and-fire persistence design for dispose paths; avoid manager-bound async drift.
- Bound recognizer pool and add stress coverage.

---

## Cross-Cutting Priority Matrix

### Critical

- Cold backup consistency under WAL (`backup_recovery_service.dart`, `database_service.dart`)
- Gesture arbitration issues that can trigger unintended page turns (`reader_page_gesture_handler.dart`)
- Page-turn lock recovery guard for hung async transitions

### High

- TXT pagination accuracy and deterministic mapping (`txt_reader.dart`, `pagination_helper.dart`)
- Large-file memory pressure in TXT parse pipeline
- Regex robustness against pathological chapter lines
- Brightness notifier churn and resume transition smoothness (`brightness_orchestrator.dart`, `brightness_controller.dart`)

### Medium

- EPUB duplicate parse/open overhead
- PDF readiness race for TOC
- Anchor healer scaling with highlight-heavy chapters

### Low (but still should be cleaned)

- Theme/system-follow alignment polish
- Invalid preset observability
- Legacy privacy path cleanup

---

## Final Refactoring Roadmap (Execution Order)

1. **P0 — Backup/Persistence correctness**
   - Replace raw DB/WAL/SHM copy strategy with SQLite-consistent snapshot approach.
   - Harden restore/integrity sequence and lifecycle interruption handling.
   - Add concurrency backup tests under active write load.

2. **P0 — Pagination determinism + accuracy**
   - Rework TXT page estimation with real render constraints and text scaling.
   - Normalize deterministic position/page mapping (seek/reopen invariants).
   - Add stress tests: CJK+EN mixed content, large fonts, line-height extremes, orientation change.

3. **P1 — Parsing robustness + memory safety**
   - Refactor chapter parse pipeline with prefilters and safer regex strategy.
   - Add pathological-line guards in isolate parse.
   - Introduce chunked/lazy memory plan for massive TXT inputs.

4. **P1 — Brightness UX stabilization**
   - Smooth mode-switch and resume transitions.
   - Improve state dedup to reduce rebuild churn.
   - Validate lifecycle ownership release/reacquire behavior.

5. **P1 — Gesture arbitration cleanup**
   - Prioritize highlight/selection interactions over page-turn triggers.
   - Tune threshold/velocity policy and add collision tests.

6. **P2 — Write-path performance hardening**
   - Re-audit progress save cadence and lock contention under fast reading.
   - Strengthen fallback snapshot guarantees.
   - Add debug counters for save latency/dropped operations.

---

## Working Checklist (Track 1-by-1)

Legend: `[ ]` todo, `[~]` in progress, `[x]` done.

### Phase P0 — Must-Fix Foundation

- [x] Replace cold backup implementation with SQLite-consistent snapshot strategy.
- [x] Add integration test: backup during active progress writes.
- [x] Harden restore fallback path (rename/copy-delete/retry) with platform-safe branches.
- [x] Refactor TXT pagination estimator to include text scale and actual paragraph spacing model.
- [x] Add deterministic page-position invariant tests (seek -> prev/next -> reopen consistency).

### Phase P1 — Stability and UX

- [x] Add chapter parsing fast prefilter and simplify risky regex paths.
- [x] Add parse guards for pathological lines (length/timeout strategy in isolate).
- [x] Implement large-TXT memory mitigation plan (chunked/lazy read baseline).
- [x] Add `BrightnessState` equality/dedup and trim redundant notifier churn.
- [x] Smooth manual/follow-system transition animation and resume restore behavior.
- [x] Add page-turn in-flight timeout recovery to prevent stuck lock state.
- [x] Resolve gesture conflict order between highlight, tap-turn, pan-turn, and edge gestures.

### Phase P2 — Performance Hardening / Tech Debt

- [ ] Move heavy bookshelf signature/index work off UI-critical path.
- [ ] Add incremental background signature backfill for legacy books.
- [ ] Parallelize large-batch delete path with robust status reporting.
- [ ] Offload anchor healing to isolate for highlight-heavy chapters.
- [ ] Add source availability precheck badges in shelf UI.
- [ ] Complete DI cleanup in settings/features (remove direct locator calls outside allowed scope).

### Test and Verification Gates

- [ ] Unit tests updated for `reader_engine/**`, `controllers/**`, `database_service.dart` touches.
- [ ] Add regression tests for pagination drift with mixed CJK/EN + text scale.
- [ ] Add brightness lifecycle test: pause/resume without abrupt flash.
- [ ] Add backup integrity test matrix (normal, concurrent writes, interrupted flow).
- [ ] Run full targeted reader test suite and document residual known failures.

---

## Suggested Next Session Start Prompt

Use this in a fresh AI chat:

> Open `docs/COMPREHENSIVE_ARCHITECTURE_RISK_REFACTOR_PLAN.md`.  
> Start with Phase P0 item 1 (SQLite-consistent backup refactor) and implement end-to-end with tests.  
> Keep changes minimal, deterministic, and aligned with AGENTS.md constraints.

