# Nyan Read (喵阅) - Project Setup

## Prerequisites
1. Install [Flutter SDK](https://flutter.dev/docs/get-started/install).
2. Android Studio or VS Code with Flutter extensions.

## Setup Instructions

1. **Restore Dependencies:**
   Open a terminal in this directory (`c:\Projects\nyan-read`) and run:
   ```bash
   flutter pub get
   ```

2. **Run the App:**
   Connect an Android device or start an Emulator, then run:
   ```bash
   flutter run
   ```

3. **Build APK:**
   To generate the installation file:
   ```bash
   flutter build apk --debug
   ```
   The APK will be located at: `build/app/outputs/flutter-apk/app-debug.apk`

## Features Implemented (Phase 1)

- **Architecture:** Modular Clean Architecture.
- **Database:** SQLite with tables for Books, Bookmarks, Stats.
- **Feature Flags:** Admin Panel to toggle Free/Pro modes instantly.
- **Privacy Shelf:** Pro-only hidden shelf logic (AES-256 stub).
- **Reader UI:** Basic layout with font size, background color, and reminder logic.
- **Nyan UI:** Cute pink/pastel theme application.

## Testing the Manager Mode
1. Launch the App.
2. Tap the **Admin Icon** (top right) on the Home Screen.
3. Toggle "Pro Mode Enabled".
4. Go back: You will see the "Privacy Shelf" tab appear and the "Ads" banner disappear.