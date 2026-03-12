---
name: nyan-read-architecture-audit
description: Analyze a Flutter reader or ebook repository and produce a deep architecture audit covering system structure, reader pipeline, state management, data boundaries, technical debt, performance risks, and refactoring guidance. Use when Codex needs to understand a reading app codebase, prepare an architecture report, map modules, review pagination/parsing/rendering flows, or plan future reader features.
---

# Nyan Read Architecture Audit

## Overview

Perform a deep architecture audit of a Flutter codebase with special attention to reader applications. Build a concrete mental model from code before writing conclusions, and produce a report that helps developers understand the current system, identify risks, and choose refactoring priorities.

Match the user's language when writing the final report. Cite concrete files, classes, functions, and flows. Mark any inference or speculation explicitly.

## Audit Workflow

Follow this sequence unless the user requests a narrower scope.

### 1. Scan the repository

Inspect the whole repository before judging architecture.

- Map top-level directories and notable subtrees.
- Identify app entrypoints such as `main.dart`, alternate mains, bootstrap files, generated files, and platform-specific launch surfaces.
- Read `pubspec.yaml`, analysis config, test directories, and any architecture notes.
- Determine the dominant architectural style: layered, feature-based, MVVM, MVC, Clean Architecture, hybrid, or legacy mix.
- Note coupling hotspots, legacy islands, cross-feature utility dumping, and inconsistent naming or placement.

Prefer fast file discovery first, then focused reads:

- Use `rg --files` or equivalent to map files.
- Use targeted searches for entrypoints, routers, repositories, controllers, services, parsers, paginators, and persistence classes.
- Read enough implementation to understand behavior, not just declarations.

### 2. Map major modules

Identify the important modules that exist in the repository, including when applicable:

- bookshelf or library
- reader screen
- chapter parsing
- pagination
- ebook format support such as epub, txt, pdf
- import flows and local file handling
- reading progress persistence
- bookmarks, highlights, annotations
- search
- themes, typography, and settings
- data persistence and repositories
- network or sync

For each module, explain:

- purpose
- important files
- key classes and functions
- upstream and downstream dependencies
- architectural risks
- extension difficulty for future features

Do not force modules that are absent. State clearly when a capability does not exist yet.

### 3. Deep dive the reader pipeline

Treat this as the most important section. Reconstruct the full path from raw book file to rendered reader UI.

Explain, with code references, the concrete pipeline:

`Book source -> file loading -> parsing -> chapter/domain model -> pagination/layout -> page rendering -> widget tree -> page navigation -> progress persistence`

Analyze:

- how files are discovered and opened
- where parsing happens and whether it is synchronous or async
- how chapters, sections, or blocks are represented
- which component owns pagination and how invalidation works
- how rendered pages are cached, rebuilt, or discarded
- how page state is stored during navigation, theme changes, font changes, and orientation changes
- how reading progress is saved and restored

Call out:

- heavy synchronous work on the UI isolate
- unnecessary rebuild chains
- expensive parsing or layout loops
- over-retained content in memory
- controller, listener, stream, or notifier lifecycle leaks
- race conditions between pagination, user interaction, and persistence

### 4. Review state management

Identify the actual state management approach instead of assuming a pattern.

- Distinguish local widget state from app-wide state.
- Trace state flow between widgets, controllers, services, repositories, and storage.
- Note fragmented ownership, duplicated derived state, or bidirectional dependencies.
- Highlight places where UI state and domain state are mixed together.

### 5. Review the data layer

Analyze repositories, services, adapters, local storage, preferences, databases, caches, and format-specific data sources.

Check for:

- model mixing between UI, domain, and persistence concerns
- weak repository boundaries
- implicit serialization rules
- migration or compatibility risks
- duplicated persistence logic
- error handling gaps around IO and corrupted content

### 6. Evaluate engineering quality

Assess the codebase beyond feature behavior.

- routing and navigation structure
- dependency injection or manual wiring
- error reporting and recovery paths
- logging and diagnostics
- test coverage and what is untested
- maintainability of large classes and widgets
- extensibility for future reader features

Distinguish observed facts from likely-but-unconfirmed implications.

### 7. Detect technical debt

Create a prioritized debt list and categorize each item as:

- `P0`: critical correctness, stability, or severe architecture risk
- `P1`: important maintainability, performance, or feature-delivery blocker
- `P2`: improvement or cleanup that should follow higher-priority work

Look for:

- overly large classes or widgets
- duplicated logic
- hidden coupling
- unsafe async or lifecycle patterns
- weak error handling
- inconsistent architecture rules
- dead abstractions and unused layers

## Output Format

Use this structure unless the user requests a different one:

1. Project Overview
2. Architecture Overview
3. Module Analysis
4. Reader Pipeline Deep Dive
5. State Management
6. Data Layer
7. Engineering Quality
8. Technical Debt List
9. Optimization Roadmap
10. Feature Expansion Advice

## Reporting Rules

Keep the report actionable and evidence-based.

- Reference specific files every time you make an important claim.
- Mention concrete classes, methods, widgets, controllers, repositories, and services.
- Explain why a design is risky, not just that it is risky.
- Mark speculation with labels such as `Inference:` or `Speculation:`.
- Separate observations from recommendations.
- Prefer behavior-level explanations over folder-name summaries.
- If the repository is large, summarize repeated patterns instead of listing every file.

## Refactoring Guidance

When proposing changes, give realistic next steps instead of abstract advice.

- Suggest seams for extraction.
- Identify modules that can be isolated first.
- Recommend test coverage that would make refactors safer.
- Sequence work from lowest-risk, highest-leverage changes to larger migrations.
- Call out any refactor that is likely to affect persisted data, reading progress, or pagination correctness.
