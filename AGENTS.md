# AGENTS.md

This document defines the working principles and engineering rules that AI coding agents must follow when interacting with this repository.

These rules apply when performing tasks such as:

- implementing new features
- modifying existing code
- debugging
- refactoring
- reviewing code
- analyzing architecture

The goal is to maintain **code quality, architectural consistency, system stability, and long-term maintainability**.

Agents should prioritize **correctness and system understanding over speed**.

---

# Core Principles

## Understand Before Changing

Before modifying code:

- read the surrounding implementation
- understand how the module works
- identify dependencies and side effects

Never make blind modifications.

If the system behavior is unclear, analyze the relevant code paths first.

---

## Prefer Minimal, Safe Changes

When fixing bugs or implementing improvements:

- prefer the smallest safe change
- avoid unnecessary refactors
- avoid touching unrelated modules

Large refactors must be explicitly requested.

---

## Preserve Existing Behavior

Unless explicitly instructed otherwise:

- do not change existing public behavior
- do not break existing flows
- do not change storage formats
- do not alter reading progress logic

Refactoring must preserve behavior.

---

# Architecture Rules

Follow the existing architecture of the project.

Do not introduce new architectural patterns without explicit instruction.

Respect module boundaries.

UI layers must not directly access:

- databases
- storage
- file IO
- parsing logic

Use services or repositories for these operations.

Avoid introducing cross-feature dependencies.

---

# Reader Engine Safety Rules

The reader engine is a critical subsystem.

Changes affecting the reader must be handled with extra care.

Avoid breaking:

- pagination correctness
- reading progress restoration
- chapter navigation logic

Pagination must remain deterministic.

Reader settings such as:

- font size
- line spacing
- theme
- margins

must correctly trigger pagination updates.

Never silently change pagination behavior.

---

# Performance Rules

Avoid introducing performance regressions.

Do not perform heavy work inside:

- widget build methods
- UI event handlers
- synchronous UI isolate code paths

Large operations such as:

- parsing book files
- chapter processing
- pagination computation

should be asynchronous or cached when possible.

Avoid unnecessary widget rebuilds.

---

# State Management Rules

State must have clear ownership.

Avoid:

- duplicated derived state
- multiple sources of truth
- bidirectional dependencies

Reader state should be centralized and predictable.

UI components should consume state rather than own domain logic.

---

# Error Handling Rules

All IO operations must handle errors.

This includes:

- file access
- parsing
- storage
- network operations

Failures should:

- fail gracefully
- not crash the application
- not corrupt reading progress

Errors should be logged when appropriate.

---

# Debugging Rules

When debugging issues:

1. Identify the root cause.
2. Explain the cause clearly.
3. Propose the minimal fix.

Avoid speculative fixes.

Avoid stacking patches without understanding the underlying issue.

---

# Refactoring Rules

Refactoring must improve clarity without altering behavior.

Avoid:

- large-scale structural changes
- unnecessary abstraction
- speculative generalization

Prefer simple, clear implementations.

---

# Code Quality Rules

Maintain readability and maintainability.

Avoid:

- overly large classes
- overly large widgets
- duplicated logic
- unclear naming

Extract reusable logic into helpers, services, or controllers when appropriate.

Keep UI code focused on presentation.

---

# Testing Awareness

When modifying critical logic such as:

- pagination
- chapter parsing
- reading progress

ensure the change would remain testable.

Do not modify tests to hide bugs.

---

# Documentation Rules

Complex logic should include brief comments explaining:

- why the logic exists
- what assumptions it relies on

Avoid redundant comments that simply repeat code.

---

# Use Analysis Tools When Needed

Before large modifications, agents should consider running analysis tools such as:

- architecture-audit
- reader-engine-analysis
- flutter-performance-audit

These tools help understand the system before making changes.

---

# When in Doubt

If a change might affect:

- reader correctness
- reading progress
- pagination logic
- storage format

stop and analyze the code paths before making modifications.

Prefer safety and correctness over speed.