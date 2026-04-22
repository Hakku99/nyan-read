import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service for managing reading reminder preferences
class ReadingReminderService extends ChangeNotifier {
  ReadingReminderService();

  SharedPreferences? _prefs;
  bool _isEnabled = false;
  int _intervalMinutes = 60;

  // Keys
  static const String _keyEnabled = 'reading_reminder_enabled';
  static const String _keyInterval = 'reading_reminder_interval';

  bool get isEnabled => _isEnabled;
  int get intervalMinutes => _intervalMinutes;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isEnabled = _prefs?.getBool(_keyEnabled) ?? false;
    _intervalMinutes = _prefs?.getInt(_keyInterval) ?? 60;
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _prefs?.setBool(_keyEnabled, enabled);
    notifyListeners();
  }

  Future<void> setIntervalMinutes(int minutes) async {
    _intervalMinutes = minutes;
    await _prefs?.setInt(_keyInterval, minutes);
    notifyListeners();
  }
}
