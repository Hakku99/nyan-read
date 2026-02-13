import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageManager extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString('language_code');
    if (savedCode != null) {
      _locale = Locale(savedCode);
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale newLocale) async {
    if (_locale == newLocale) return;
    _locale = newLocale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', newLocale.languageCode);
  }
}
