---
name: nyan-read-performance-audit
description: Audit a Flutter codebase for UI rendering, rebuild behavior, async workloads, caching, and memory risks, with emphasis on reader application performance. Use when Codex needs a performance-focused review of runtime costs, hot paths, jank risks, pagination overhead, or reader responsiveness instead of a general architecture audit.
---

# Nyan Read Performance Audit

## Overview

Audit a Flutter application for performance bottlenecks and runtime inefficiencies, with special attention to reader-heavy flows. Ground every conclusion in concrete code paths and explain the likely user-visible impact such as jank, slow opening, dropped frames, memory growth, or sluggish page transitions.

Do not repeat broad architecture analysis unless a structural detail is required to explain a performance issue.

## Audit Workflow

Follow this sequence unless the user asks for a narrower scope.

### 1. Identify performance hot paths

Locate the flows where responsiveness matters most.

Typical hot paths include:

- application startup
- bookshelf or library lists
- opening a book
- chapter loading
- pagination
- page rendering
- scrolling or page turning
- search
- settings changes that trigger relayout or repagination

Summarize which flows are most likely to affect frame time, latency, or perceived responsiveness.

### 2. Audit widget rebuild behavior

Inspect widget trees and state propagation with a performance lens.

Look for:

- large widgets rebuilding too frequently
- rebuilds triggered by broad state updates
- repeated work inside `build`
- unnecessary object allocation during builds
- missing `const` where it would materially reduce rebuild churn
- unstable or incorrect widget keys

Explain where rebuild scopes could be reduced and which state boundaries appear too broad.

### 3. Audit reader rendering performance

Reader applications often spend time in text layout and page composition.

Inspect:

- page rendering widgets
- text layout generation
- image rendering inside pages
- chapter transition behavior
- page caching strategies
- repagination behavior under settings or viewport changes

Identify risks such as:

- large chapters blocking the UI
- expensive layout recalculations
- viewport changes triggering full repagination too often
- animation work competing with layout or parsing work

### 4. Audit main thread work

Find expensive operations happening on the UI isolate.

Examples include:

- large file parsing
- chapter splitting
- pagination calculations
- JSON decoding
- database reads during interaction
- heavy string processing
- synchronous file IO

Explain where work should be deferred, cached, chunked, or moved off the main isolate.

### 5. Audit memory behavior

Check for patterns that can cause memory pressure during long sessions.

Look for:

- large in-memory chapter or page objects
- repeated parsing that duplicates content
- retained caches without eviction rules
- image cache misuse
- controllers, listeners, streams, or notifiers not disposed
- duplicated models for the same content at different layers

Explain the likely impact on long reading sessions, repeated book switches, or large-book handling.

### 6. Audit state management for performance

Evaluate how state updates propagate through the app.

Look for:

- global state changes triggering large rebuilds
- broad `ChangeNotifier` updates
- inefficient stream or listener fan-out
- duplicated derived state
- UI and domain state mixed in a way that increases update cost

Explain where update granularity could be improved.

### 7. Audit data access and caching

Check data access patterns for unnecessary repeated work.

Look for:

- repeated file reads
- repeated parsing
- missing chapter caches
- missing pagination caches
- inefficient persistence calls
- blocking storage access
- overly chatty reading-progress writes

For reader apps, pay particular attention to:

- chapter caching
- pagination caching
- metadata caching
- reading progress writes and restores

### 8. Categorize findings

Group findings into:

- `P0`: severe UI jank, freezes, or memory risk
- `P1`: important issues affecting responsiveness
- `P2`: optimization opportunities or cleanup

Each finding should include:

- issue summary
- affected files and classes
- why it hurts performance
- likely user-visible symptoms
- suggested mitigation

## Output Format

Produce a report with these sections:

1. Performance Overview
2. Hot Path Summary
3. Widget Rebuild Analysis
4. Reader Rendering Performance
5. Main Thread Work
6. Memory Behavior
7. State Update Efficiency
8. Data Access and Caching
9. Performance Findings by Severity
10. Quick Wins
11. Medium-Term Improvements
12. High-Impact Refactor Opportunities

## Reporting Rules

Keep the report evidence-based and focused on runtime impact.

- Reference specific files, classes, widgets, controllers, and services.
- Avoid generic Flutter advice unless tied to real code.
- Separate confirmed findings from `Inference:` or `Speculation:`.
- Focus on user-visible performance costs.
- Prefer practical improvements before large rewrites.
- Explain why a cost is likely to matter for frame time, latency, or memory.

## Refactoring Guidance

When suggesting improvements, prioritize changes by leverage and risk.

- Start with changes that reduce cost without changing reader behavior.
- Recommend instrumentation or tests when they would validate a suspected hotspot.
- Distinguish quick wins from larger architectural performance work.
- Call out any optimization that may affect pagination correctness, progress persistence, or user-visible rendering behavior.
