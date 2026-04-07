# AGENTS.md

## Operating Mode
This project is in active development, not frozen maintenance.

Prefer deliberate, justified changes over speculative ones.

Priority:
- Correctness over speed
- Stability over optimization
- Determinism over convenience
- Understanding over modification

## Default Change Rules
Before any change, read surrounding code, trace execution flow, identify dependencies, and confirm state ownership.

Prefer the smallest change that cleanly solves the task; multi-module changes are allowed when they belong to the same feature or fix.
Do not make speculative changes, blind fixes, or patch stacking.
User-visible behavior may change when required by the task, but unintended behavior changes must be called out explicitly.

## Protected Surfaces
The following high-risk changes require impact, risk, and validation analysis plus explicit confirmation before implementation:
- Pagination algorithm behavior changes
- Reading progress persistence behavior changes
- Storage schema changes
- Public API contract changes
- Shared data model contract changes

The following do not require automatic escalation, but must remain minimal and validated:
- Reader UI changes
- Internal refactors without contract changes
- Multi-module changes within the same feature or fix

Do not change public APIs or shared data models without clearly documenting the contract impact.

## Architecture and State Rules
UI must not access database, storage, file IO, or parsing logic directly.
Use services or repositories.

Keep a single source of truth for:
- Reading position
- Pagination result
- Current chapter

Avoid duplicated state, bidirectional dependencies, and cross-feature coupling.
Refactoring for clearer ownership is allowed if behavior and contracts remain explicit.

## Reader Safety Requirements
These must not break:
- Pagination correctness
- Reading position restoration
- Chapter navigation
- Layout consistency
- Determinism

Same content and same settings must produce identical pagination.

Do not introduce:
- Hidden state
- Randomness
- Time-based logic

## Validation and Merge Rules
Prevent race conditions, stale overwrites, and concurrent pagination by using guards, cancellation, or version checks.

Do not run heavy work in `build()` or synchronous UI handlers.
Heavy work must be asynchronous and cached when appropriate.

All IO must fail gracefully and must not corrupt data.
Any persisted-data change must document compatibility impact; add a migration plan when existing user data may be affected.
Log important state transitions and failures without spamming or leaking sensitive data.

For any reader-related change, verify:
- Determinism
- Stable page boundaries
- Exact reading position restoration
- Correct re-pagination after settings changes
- Accurate chapter navigation
- Restart consistency

Do not weaken tests to hide bugs.
Do not merge high-risk changes unless safety is explained and validated, or explicit approval is given.
