import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_presets.dart';

class ThemeManager extends ChangeNotifier {
  ThemePreset _currentPreset = ThemePreset.creamLight;

  ThemePreset get currentPreset => _currentPreset;

  /// Returns the active NyanTheme for the current preset.
  /// For [ThemePreset.matchSystem] this returns creamLight as a fallback —
  /// the actual runtime theme is determined by [themeMode] + [lightTheme]/[darkTheme].
  NyanTheme get currentNyanTheme => _currentPreset == ThemePreset.matchSystem
      ? themePresets[ThemePreset.creamLight]!
      : themePresets[_currentPreset]!;

  ThemeData get currentThemeData => currentNyanTheme.themeData;

  ThemeData get lightTheme => _currentPreset == ThemePreset.matchSystem
      ? themePresets[ThemePreset.creamLight]!.themeData
      : currentThemeData;

  ThemeData get darkTheme => _currentPreset == ThemePreset.matchSystem
      ? themePresets[ThemePreset.sumiDark]!.themeData
      : currentThemeData;

  /// [ThemeMode.system] when [ThemePreset.matchSystem] is active so Flutter's
  /// MaterialApp automatically selects [lightTheme] or [darkTheme] based on
  /// the device brightness setting. All other presets force [ThemeMode.light]
  /// because we embed the full NyanTheme inside a light ThemeData regardless
  /// of whether it visually looks dark.
  ThemeMode get themeMode => _currentPreset == ThemePreset.matchSystem
      ? ThemeMode.system
      : ThemeMode.light;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final presetName = prefs.getString('theme_preset');
    if (presetName != null) {
      if (presetName.contains('sakuraLight')) {
        _currentPreset = ThemePreset.creamLight;
        setPreset(_currentPreset); // migrate legacy key
      } else if (presetName.contains('midnightBlue')) {
        _currentPreset = ThemePreset.sumiDark;
        setPreset(_currentPreset); // migrate legacy key
      } else {
        try {
          _currentPreset =
              ThemePreset.values.firstWhere((e) => e.toString() == presetName);
        } catch (e) {
          _currentPreset = ThemePreset.creamLight;
        }
      }
    }
    notifyListeners();
  }

  Future<void> setPreset(ThemePreset preset) async {
    _currentPreset = preset;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_preset', preset.toString());
  }
}
