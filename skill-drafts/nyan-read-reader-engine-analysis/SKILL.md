---
name: nyan-read-reader-engine-analysis
description: Analyze the reader subsystem of a Flutter ebook application and explain the full reader engine pipeline, including book loading, parsing, chapter modeling, pagination, rendering, reader state, progress persistence, and extensibility. Use when Codex needs a focused reader-internals report instead of a whole-app architecture audit.
---

# Nyan Read Reader Engine Analysis

## Overview

Analyze the reader subsystem only. Reconstruct how book content moves from source files to on-screen pages, and explain how reader state, pagination, and progress persistence behave internally.

Do not repeat broad repository or application architecture analysis unless a global detail is necessary to explain reader behavior. Keep the focus on the reading engine and its adjacent dependencies.

## Analysis Workflow

Follow this sequence unless the user asks for a narrower reader-only slice.

### 1. Identify reader entry points

Locate the components that start the reading flow.

Inspect:

- reader screens, pages, or routes
- book opening actions from library or bookshelf surfaces
- reader controllers, coordinators, or view models
- services that load book content for the reader
- navigation code that passes a book into the reading flow

Explain:

- how the reader screen is opened
- which objects are created during reader initialization
- how the current book or book identifier enters the reader subsystem

Reference concrete files, classes, constructors, and methods.

### 2. Trace the reader data pipeline

Reconstruct the full data flow from raw book file to rendered UI.

Trace this pipeline:

`Book source -> file loading -> parsing -> chapter or section model -> pagination or layout generation -> page models -> UI widgets -> page navigation -> reading progress persistence`

For each stage explain:

- which class performs the work
- where the main data structure changes
- whether work is synchronous or asynchronous
- how results are passed to the next stage

If any stage is not directly visible in code, mark it as `Inference:` or `Speculation:`.

### 3. Analyze book format handling

Determine how the reader handles different book formats such as EPUB, TXT, PDF, or custom structures.

Explain:

- where format detection occurs
- how format-specific parsing is implemented
- whether format handling is unified behind abstractions or duplicated across branches
- how difficult it would be to add a new format

Call out risks when format-specific logic is scattered across widgets, controllers, or repositories.

### 4. Analyze chapter modeling

Explain how chapters, sections, or content blocks are represented before pagination.

Look for:

- chapter models
- section or block models
- preprocessing and normalization steps
- lazy versus eager loading behavior
- caching of parsed chapter content

Assess:

- whether large chapters create memory pressure
- whether boundaries between chapters affect pagination correctness or performance
- whether chapter loading strategy will scale to large books

### 5. Analyze pagination and layout

Explain how pages are generated and invalidated.

Determine:

- which component owns pagination
- how page boundaries are computed
- what inputs affect pagination, such as font size, viewport size, spacing, theme, margins, or orientation
- whether paginated output is cached or recomputed

Explain what happens when:

- font size changes
- theme changes
- orientation changes
- viewport size changes

Check for:

- repeated pagination work
- unstable page indexing
- invalidation rules that are too broad or too narrow
- pagination results tied too tightly to widget state

### 6. Analyze reader rendering

Explain how paginated content becomes the actual UI.

Identify:

- page container widgets
- text and image rendering strategy
- page transition mechanism
- page navigation logic
- rebuild boundaries within the reader widget tree

Assess whether rendering introduces:

- large rebuild scopes
- expensive layout passes
- fragile widget composition
- hidden coupling between rendering and pagination state

### 7. Analyze reader state flow

Map how reader state is stored and propagated.

Typical state includes:

- current book
- current chapter
- current page index or reading position
- reading progress
- typography and layout preferences
- theme or reader appearance settings

Explain:

- where state originates
- which components own it
- how updates propagate through the system
- which state is persisted versus transient

Highlight duplicated derived state, weak ownership, or reader settings mixed with domain progress.

### 8. Analyze reading progress persistence

Explain how the system saves and restores reading progress.

Check:

- when progress is saved
- what book identifiers or keys are used
- what exact position is stored, such as chapter index, page index, offset, CFI, percentage, or custom locator
- how saved progress is restored after reopening

Identify risks such as:

- page index mismatch after repagination
- restore failures after settings changes
- weak identifiers for imported files
- persistence timing races during rapid navigation

### 9. Evaluate reader extensibility

Assess how the current reader engine would support future features, for example:

- text-to-speech
- cloud sync for reading progress
- highlights and annotations
- note export
- custom page-turn animation
- reading analytics
- AI summary or Q&A

Explain:

- where integration points already exist
- which seams are missing
- what refactoring would likely be required
- what architectural blockers may slow future work

## Output Format

Produce a report with these sections:

1. Reader Engine Overview
2. Reader Entry Points
3. Reader Data Pipeline
4. Book Format Handling
5. Chapter Modeling
6. Pagination and Layout
7. Rendering Flow
8. Reader State Flow
9. Reading Progress Persistence
10. Extensibility Assessment
11. Key Reader Files
12. Risks and Refactor Suggestions

## Reporting Rules

Keep the report focused on reader behavior and evidence from code.

- Reference concrete files, classes, methods, widgets, and services.
- Mark speculation explicitly.
- Prioritize correctness, maintainability, performance, and extensibility.
- Avoid restating broad app architecture unless it directly affects reader behavior.
- Explain why a risk matters for the reading experience or future feature work.

## Refactoring Guidance

When suggesting changes, keep them reader-focused and practical.

- Isolate the narrowest useful seam first.
- Recommend tests that protect pagination, restore behavior, and format parsing.
- Distinguish low-risk cleanup from invasive engine rewrites.
- Call out any change that could invalidate saved progress or reader settings.
