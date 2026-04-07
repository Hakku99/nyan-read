# AGENTS.md

## Operating Principle
Act as a conservative maintainer, not a proactive optimizer.

Priority:
- Correctness over speed
- Stability over optimization
- Determinism over convenience
- Understanding over modification

## Default Change Rules
Before any change, read surrounding code, trace execution flow, identify dependencies, and confirm state ownership.

Default to small, local fixes only.
Do not make speculative changes, blind fixes, or patch stacking.
Do not change user-visible behavior unless explicitly requested.

## Protected Surfaces
Do not modify the following without explicit approval:
- Reader pagination algorithm
- Reading progress persistence
- Storage schema
- Public APIs
- Shared data models

If a task touches reader engine, pagination, storage, or shared interfaces:
1. Stop
2. Explain why the change is needed
3. Provide impact, risk, and validation plan
4. Request confirmation

## Architecture and State Rules
UI must not access database, storage, file IO, or parsing logic directly.
Use services or repositories.

Keep a single source of truth for:
- Reading position
- Pagination result
- Current chapter

Avoid duplicated state, bidirectional dependencies, and cross-feature coupling.

## Reader Safety Requirements
These must not break:
- Pagination correctness
- Reading position restoration
- Chapter navigation
- Layout consistency

Determinism is mandatory:
- Same content and same settings must produce identical pagination
- No hidden state, randomness, or time-based logic

## Runtime and Validation Rules
Prevent race conditions, stale overwrites, and concurrent pagination by using guards, cancellation, or version checks.

Do not run heavy work in `build()` or synchronous UI handlers.
Heavy work must be asynchronous and cached when appropriate.

All IO must fail gracefully and must not corrupt data.
Schema changes require a migration plan.
Log important state transitions and failures without spamming or leaking sensitive data.

For any reader-related change, verify:
- Determinism
- Stable page boundaries
- Exact reading position restoration
- Correct re-pagination after settings changes
- Accurate chapter navigation
- Restart consistency

Do not weaken tests to hide bugs.

## Final Rule
If safety cannot be explained and validated, do not modify the code.
