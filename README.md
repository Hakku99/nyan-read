# 喵阅 Nyan Read

> A completely offline e-book reader for TXT, EPUB, and PDF — built with a paper-reading soul.  
> 完全离线的本地电子书阅读器，支持 TXT / EPUB / PDF，UI 气质取自纸本阅读。

---

## Features

- **Three formats** — TXT, EPUB, and PDF with unified reading experience
- **Offline & private** — no account, no cloud, no telemetry; all data lives in local SQLite + SharedPreferences
- **One Paper reader chrome** — a single floating dock that grows in-place into a Chapters or Settings sheet; brightness via top-bar popover + left-edge drag
- **Design system** — "Muji × paper reading × matcha" aesthetic; Cream Light and Sumi Dark themes with a full token layer (`NyanColors`, `NyanTypography`, `NyanSpacing`, `NyanRadius`, `NyanShadows`)
- **Privacy shelf** — PIN-protected hidden bookshelf (Pro)
- **Bookmarks, highlights & notes** — per-paragraph annotations persisted locally
- **Reading stats** — session tracking and progress history

---

## Platform Support

| Platform | Status |
|---|---|
| Android | ✅ Primary (tested on device) |
| iOS | ⚠️ Primary target, untested — no real-device verification yet |
| Windows / macOS / Linux | 🔲 TBC |

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) `>=3.19`
- Android Studio or VS Code with the Flutter extension
- An Android or iOS device / emulator

### Install dependencies

```bash
flutter pub get
```

### Font assets

The app uses **Noto Sans SC** and **Source Han Serif SC**, which are not committed to the repo due to file size. Follow the instructions in [`assets/fonts/README.md`](assets/fonts/README.md) to download and place the font files before running.

> The app compiles and runs without the fonts — Flutter falls back to the platform font and prints a warning. The serif reading mode only activates once the font files are in place.

### Run

```bash
flutter run
```

### Build APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## Architecture

The project follows a strict five-layer architecture:

```
Presentation  →  Controller  →  Engine  →  Service  →  Platform / Infra
```

- **Engine** (`ReaderEngine`) is the format-agnostic reading contract; TXT, EPUB, and PDF each have their own implementation.
- **Services** (`DatabaseService`, `ReaderPreferencesService`) own all persistence; widgets never touch SQLite or SharedPreferences directly.
- **State** is managed with `flutter_riverpod` + `get_it`; high-frequency values (progress, brightness) use `ValueNotifier` to avoid full-tree rebuilds.

Full guidelines, protected surfaces, and the architecture roadmap are documented in [`AGENTS.md`](AGENTS.md).

---

## Design System

UI token definitions live in `lib/core/theme/`:

| File | Covers |
|---|---|
| `nyan_colors.dart` | Atomic colour constants + semantic error/success palette |
| `nyan_typography.dart` | Font families, size ladder, weight rules |
| `nyan_spacing.dart` | 8pt grid constants + 44pt min tap target |
| `nyan_radius.dart` | One Paper concentric corner-radius family |
| `nyan_shadows.dart` | Themed shadow/glow-ring tokens |

Theme-sensitive colours must be accessed through `Theme.of(context).extension<NyanTheme>()` — never reference `NyanColors.creamXxx` / `inkNightXxx` directly in widgets. See [`AGENTS.md §4`](AGENTS.md) for the full design philosophy and token truth table.

---

## Development

```bash
# Static analysis
flutter analyze

# Tests
flutter test
```

Commits follow [Conventional Commits](https://www.conventionalcommits.org/): `feat:` / `fix:` / `refactor:` / `perf:` / `docs:` / `test:` / `chore:`, subject ≤ 50 characters.
