# Overview

This document defines **mandatory rules and enforcement protocols** for AI agents.

Agents must behave as:

> **Conservative maintainers, not proactive optimizers**

---

# Core Principles

* Correctness > Speed
* Stability > Optimization
* Determinism > Convenience
* Understanding > Modification

---

# 1. Understand Before Changing

Before any change, agents MUST:

* read surrounding code
* trace execution paths
* identify dependencies
* understand state ownership

---

## Forbidden

* blind fixes
* speculative changes
* patch stacking

---

# 2. Strict Mode (Change Boundaries)

## 🔒 Hard Restrictions

Agents must NOT modify:

* reader pagination algorithm
* reading progress persistence logic
* storage schema
* public APIs
* shared data models

Unless explicitly instructed.

---

## Allowed Scope

Agents may ONLY modify:

* directly related module
* minimal required logic

---

## Escalation Rule

If change requires touching:

* reader engine
* pagination
* storage
* shared interfaces

Agent MUST:

1. STOP
2. EXPLAIN WHY
3. REQUEST CONFIRMATION

---

# 3. Change Scope Classification

### Small

* local fix
* no API impact

### Medium

* multi-module (same feature)

### Large

* architectural or cross-feature

---

## Rule

Default to **Small**.
Medium/Large require explicit approval.

---

# 4. Behavior Preservation

Agents must NOT:

* change user-visible behavior
* break existing flows
* alter reading progress
* modify storage format

---

# 5. API & Contract Stability

Agents must NOT:

* change function signatures
* modify return types
* rename persisted fields
* change serialization

---

# 6. Architecture Rules

UI must NOT access:

* database
* storage
* file IO
* parsing logic

Use services/repositories.

---

# 7. Feature Isolation

No cross-feature coupling.

Reader must remain independent from:

* library
* UI theme
* integrations

---

# 8. Reader Engine Safety (CRITICAL)

---

## Must NOT Break

* pagination correctness
* reading position restoration
* chapter navigation
* layout consistency

---

## Determinism Requirement

Same:

* content
* settings

→ must produce identical pagination

---

## Forbidden

* hidden state
* randomness
* time-based logic

---

# 9. Pagination Validation (MANDATORY)

Any reader-related change MUST pass:

---

## 1. Determinism

* identical input → identical page count

---

## 2. Page Stability

* no off-by-one
* stable boundaries

---

## 3. Reading Position

* exact restoration
* no paragraph shift

---

## 4. Settings Trigger

Changes in:

* font size
* spacing
* margins

must trigger correct pagination

---

## 5. Chapter Navigation

* no page drift
* accurate jumps

---

## 6. Restart Consistency

* restart must not change pagination

---

# 10. Reader Engine Contract (MANDATORY BEFORE CHANGE)

Before modifying ANY reader-related logic, agent MUST produce:

---

## 📄 Impact Analysis

* what is being changed
* why change is needed
* affected modules

---

## ⚠️ Risk Assessment

Must evaluate risk to:

* pagination
* reading progress
* chapter navigation
* storage

---

## 🧪 Validation Plan

Must explain how correctness will be verified:

* which scenarios tested
* what outputs compared

---

## 📊 Expected Outcome

Define:

* what must remain unchanged
* what is expected to change

---

## 🚫 If unable to prove safety

Agent MUST:

→ STOP
→ DO NOT MODIFY

---

# 11. State Management Rules

Single source of truth for:

* reading position
* pagination result
* chapter

---

## Forbidden

* duplicated state
* bidirectional dependencies

---

## UI

UI must consume state only.

---

# 12. Concurrency Rules

Prevent:

* race conditions
* stale overwrites
* concurrent pagination

---

## Use

* cancellation
* version checks
* guards

---

# 13. Performance Rules

---

## Forbidden

Heavy work in:

* build()
* UI handlers
* sync UI thread

---

## Required

Heavy tasks must be:

* async
* cached

---

# 14. Data Integrity

Ensure:

* safe writes
* no corruption
* backward compatibility

---

## If schema changes

Must include migration plan.

---

# 15. Error Handling

All IO must:

* fail gracefully
* not crash
* not corrupt data

---

# 16. Logging

Log:

* pagination recalculation
* state transitions
* failures

---

## Avoid

* spam
* sensitive data

---

# 17. Debugging Rules

Steps:

1. find root cause
2. explain clearly
3. apply minimal fix

---

# 18. Refactoring Rules

Must:

* preserve behavior
* improve clarity

---

## Avoid

* large restructuring
* speculative abstraction

---

# 19. Code Quality

Avoid:

* large classes
* duplicated logic
* unclear naming

---

# 20. Testing Expectations

Must verify:

* pagination consistency
* reading position
* navigation

---

## Forbidden

* modifying tests to hide bugs

---

# 21. Regression Awareness

Before change:

* identify affected flows
* verify dependencies

---

# 22. Documentation

Explain:

* WHY logic exists
* assumptions

---

# 23. When in Doubt

If affecting:

* pagination
* reader
* storage

---

## MUST

→ STOP
→ ANALYZE
→ APPLY MINIMAL SAFE CHANGE

---

# ✅ Final Enforcement Rule

> If correctness cannot be proven,
> the change must NOT be made.

---
