import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_presets.dart';

class ThemeManager extends ChangeNotifier {
  ThemePreset _currentPreset = ThemePreset.sakuraLight;

  ThemePreset get currentPreset => _currentPreset;

  ThemeData get currentThemeData => themePresets[_currentPreset]!.themeData;

  // For compatibility with MaterialApp
  ThemeData get lightTheme => currentThemeData;
  ThemeData get darkTheme => currentThemeData;
  ThemeMode get themeMode => ThemeMode.light; // We force the specific preset

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final presetName = prefs.getString('theme_preset');
    if (presetName != null) {
      try {
        _currentPreset = ThemePreset.values.firstWhere((e) => e.toString() == presetName);
      } catch (e) {
        _currentPreset = ThemePreset.sakuraLight;
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