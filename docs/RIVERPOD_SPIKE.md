# Riverpod Migration Spike (P2-2)

## Goal

Introduce Riverpod without breaking the existing `provider + get_it` runtime.

## What was changed

- Added `flutter_riverpod` dependency.
- Added `lib/core/services/riverpod_providers.dart` as a bridge layer that exposes
  existing get_it singletons as Riverpod providers.
- Wrapped app bootstrap in `ProviderScope` while keeping the legacy `MultiProvider`
  tree unchanged for compatibility.
- Migrated `main.dart` app shell to Riverpod access:
  - lifecycle lock path reads `FeatureManager` through `ref.read(...)`
  - app theme/locale shell reads managers through `ref.watch(...)`
  - rebuilds remain driven by `ListenableBuilder` on `ThemeManager` and
    `LanguageManager` (no behavioral change)
- Migrated `settings_page.dart` to Riverpod access path:
  - replaced `context.watch<...>()` with bridge providers via `ref.read(...)`
  - page-level rebuilds remain driven by `ListenableBuilder` on the same
    manager listenables to preserve behavior
- Migrated `admin_panel.dart` and `home_screen.dart` FeatureManager access:
  - replaced `context.read/watch<FeatureManager>()` with `ref.read(...)`
  - used `ListenableBuilder` on `FeatureManager` to preserve reactive rebuilds
  - `BookshelfViewModel` was kept on Provider path at this stage (later migrated)
- Migrated `reader_page.dart` host layer to Riverpod bridge providers:
  - `ReaderPage` is now a `ConsumerStatefulWidget`
  - `DatabaseService` and `ReaderPreferencesService` are resolved via Riverpod
    bridge providers in page init and `ReaderController` creation path
  - `ReaderController` provider chain remains unchanged (still Provider-based)
- Added a Riverpod-hosted ReaderController experiment:
  - new `reader_controller_provider.dart` with `Provider.autoDispose.family`
  - `ReaderController` creation/disposal now runs under Riverpod lifecycle
  - UI consumption remains `ChangeNotifierProvider.value + Selector` for
    compatibility with existing reader subtree
- Replaced `context.read<ReaderController>()` call sites in reader host/gesture
  with Riverpod-hosted controller references (`_boundController` / closure
  capture), removing mixed read paths.
- Vertical-slice migration complete for reader overlay/error panels:
  - replaced `Selector<ReaderController>` in error panel and overlay panel
    with `ListenableBuilder` bound to Riverpod-hosted controller
  - kept the main reader body selector path unchanged for controlled risk
- Main reader body selector path migrated:
  - replaced remaining `Selector<ReaderController>` reads in reader body/scaffold
    with Riverpod-hosted controller + `ListenableBuilder`
  - reader page no longer depends on provider selectors for core rendering path
- Reader menu bridge removed:
  - `ReaderMenu` now receives `ReaderController` explicitly via constructor
  - removed `ChangeNotifierProvider<ReaderController>.value` from reader settings sheet
  - reader menu/widget tests updated and passing
- Reader subtree provider cleanup complete:
  - audited `lib/modules/reader/widgets/**` for provider dependencies (none left)
  - removed final `ChangeNotifierProvider<ReaderController>.value` wrapper from
    `reader_page.dart` root build path
  - reader page + menu analysis/tests remain green
- Bookshelf module migrated to Riverpod host pattern:
  - removed `ChangeNotifierProvider`, `Selector`, and `context.read/watch/select`
    usage from `home_screen.dart`
  - added `bookshelf_view_model_provider.dart` with auto-dispose provider for
    `BookshelfViewModel`
  - feature/view-model/preferences/database dependencies now resolve through
    Riverpod bridge providers
- App shell `MultiProvider` removed:
  - `main.dart` no longer wraps `NyanApp` with `MultiProvider`
  - app bootstrap now runs on `ProviderScope` only
  - all runtime reads for app shell/services resolve through Riverpod bridge providers
- Final closure:
  - removed `provider` dependency from `pubspec.yaml`
  - migrated `test/reader_menu_test.dart` away from Provider wrappers
  - runtime codebase no longer imports `package:provider/provider.dart`

## Why this shape

- Zero-risk coexistence: old pages keep using `context.watch/read`.
- New modules can opt into Riverpod immediately.
- Rollback is trivial: remove `ProviderScope` + bridge file.

## Next migration steps

1. Run full regression on route entry points after app-shell de-providerization.
2. Triage remaining analyzer info-level debt (mostly async-context lints in bookshelf).
3. Optionally add Riverpod-focused test utilities to reduce boilerplate in widget tests.
