# Nyan Read — Application Architecture Map

> This document is the **top-level map of the app as it is actually built** (last verified 2026-07-07).
> It intentionally stays short: rules and constraints live in [`AGENTS.md`](AGENTS.md),
> the reader subsystem is documented in [`READER_ARCHITECTURE.md`](READER_ARCHITECTURE.md),
> and performance gates live in [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md).
> When this file and the code disagree, the code wins — fix this file in the same PR.

## 1. Layering

Five layers with a strict downward-only call direction (full matrix in `AGENTS.md` §3.2):

```
Presentation  →  Controller  →  Engine  →  Service  →  Platform / Infra
```

- **Presentation** — `lib/modules/**` pages & widgets. Never touches `DatabaseService`, `File`, or `SharedPreferences` directly.
- **Controller** — `ReaderController` + managers, `BookshelfViewModel`. Owns orchestration and state.
- **Engine** — `ReaderEngine` contract + TXT / EPUB / PDF implementations (see `READER_ARCHITECTURE.md`).
- **Service** — `lib/core/services/`. All persistence and platform-facing logic.
- **Infra** — `sqflite`, `path_provider`, `pdfx`, `epub_view`, etc.

## 2. Module Map (`lib/modules/`)

| Module | Responsibility |
|---|---|
| `bookshelf` / `home` | Library grid/list, import flow, multi-select delete with undo grace window, search, sort |
| `reader` | Reading session: engines, controllers, One Paper chrome, brightness subsystem |
| `bookmark` / `notes` | Browse & jump-to for bookmarks, highlights and notes |
| `privacy` | PIN / biometric gate for the private shelf |
| `settings` | App & reading preferences UI |
| `admin` | Debug panel, feature-flag toggles |
| `ads` / `tts` | Placeholder / stub modules (feature-flagged, not shipped) |

## 3. Service Layer (`lib/core/services/`)

| Service | Role |
|---|---|
| `DatabaseService` | Single SQLite entry point (`nyan_read.db`, schema v9); self-heal + cold-backup restore path |
| `BackupRecoveryService` | `VACUUM INTO` cold backups on app pause (max 3), cleanup in isolate |
| `SignatureBackfillService` | Backfills `content_signature` for legacy rows after startup |
| `ReaderPreferencesService` | Reader UI prefs via SharedPreferences, 300ms debounced writes |
| `BookshelfPreferencesService` | Shelf sort/view prefs |
| `PinService` / `BiometricService` | Privacy shelf auth — salted PIN hash in `flutter_secure_storage`; **there is no file encryption** — private books are gated by `books.is_private` + auth wall, files stay plain on disk |
| `FeatureManager` | Feature flags (`ChangeNotifier`, get_it-registered — not a static singleton) |
| `LanguageManager` / `MascotManager` / `ReadingReminderService` | Locale, mascot, rest-reminder timers |

**Startup / DI**: `setupServiceLocator()` registers services with `get_it`
(`registerSingletonAsync`), `main.dart` does `await getIt.allReady()` before `runApp`.
UI state assembly is `flutter_riverpod`; services are constructor-injected into
managers/view-models (never located via `GetIt.instance<X>()` outside `service_locator.dart`).

## 4. Database Schema (SQLite, version 9)

Source of truth: `_onCreate` / `_onUpgrade` in
[`lib/core/services/database_service.dart`](lib/core/services/database_service.dart).
Migrations are append-only (`ALTER TABLE`), never drop user tables (`AGENTS.md` §2.4).

| Table | Purpose | Notes |
|---|---|---|
| `books` | Book metadata + last reading position | `last_position_type/payload` (serialized `ReadingPosition`), `content_signature` (SHA-256 import fingerprint), `storage_type`, `title_sort_key`, `is_private`. `cover_path` is **unused** (covers cached on disk by `BookCoverCache`, keyed by book id) |
| `bookmarks` | Per-book bookmarks | `position_type/payload` supersede legacy `page_index`/`cfi`; `ON DELETE CASCADE` |
| `highlights` | Text highlights + notes | Anchor healing columns `pre_context` / `post_context` / `is_healed`; `ON DELETE CASCADE` |
| `reading_stats` | **Unused** | Feature never wired up; table kept per no-drop rule — do not build on it without a plan |

⚠️ Never use `ConflictAlgorithm.replace` on `books` — it cascade-deletes bookmarks/highlights (historical data-loss incident; see comments in `database_service.dart`).

## 5. Storage Split

| Store | Holds |
|---|---|
| SQLite | Books, positions, bookmarks, highlights (all user-created data) |
| SharedPreferences | UI config only (font size, theme, brightness, sort prefs) — debounced for slider input |
| `flutter_secure_storage` | Salted PIN hash + privacy shelf key material only |
| Disk cache | Book covers (LRU, ≤100MB target) |

## 6. Feature Flags (Free vs Pro)

`FeatureManager` gates: privacy shelf, ads, TTS (stub). Toggled from the admin panel;
persisted locally. The app is fully offline — there is no subscription backend; "Pro"
status is a local flag.
