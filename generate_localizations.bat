@echo off
echo Running flutter pub get...
cd /d C:\Projects\nyan-read
flutter pub get
echo.
echo Checking if localization files were generated...
if exist .dart_tool\flutter_gen\gen_l10n\app_localizations.dart (
    echo SUCCESS: Localization files generated!
) else (
    echo WARNING: Localization files not found.
    echo Trying explicit generation...
    flutter gen-l10n
)
echo.
echo Done! Press any key to exit.
pause
