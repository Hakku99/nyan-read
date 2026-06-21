import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppMode {
  free,
  pro,
}

class FeatureManager extends ChangeNotifier {
  FeatureManager();

  AppMode _currentMode = AppMode.free;
  bool _adsEnabled = true;
  bool _privacyShelfEnabled = false;
  bool _ttsEnabled = false;
  bool _isPrivateShelfUnlocked = false;
  bool _forceProNudge = false;

  AppMode get currentMode => _currentMode;
  bool get adsEnabled => _adsEnabled;
  bool get privacyShelfEnabled => _privacyShelfEnabled;
  bool get ttsEnabled => _ttsEnabled;
  bool get isPro => _currentMode == AppMode.pro;
  bool get isPrivateShelfUnlocked => _isPrivateShelfUnlocked;
  bool get forceProNudge => _forceProNudge;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isPro = prefs.getBool('is_pro_mode') ?? false;
    _setMode(isPro ? AppMode.pro : AppMode.free);
  }

  void unlockPrivateShelf() {
    _isPrivateShelfUnlocked = true;
    notifyListeners();
  }

  void lockPrivateShelf() {
    _isPrivateShelfUnlocked = false;
    notifyListeners();
  }

  void toggleMode(AppMode mode) {
    _setMode(mode);
    _persistMode(mode == AppMode.pro);
    notifyListeners();
  }

  void _setMode(AppMode mode) {
    _currentMode = mode;
    if (mode == AppMode.pro) {
      _adsEnabled = false;
      _privacyShelfEnabled = true;
      _ttsEnabled = true; // Enabled in Pro, though might be stubbed
    } else {
      _adsEnabled = true;
      _privacyShelfEnabled = false;
      _ttsEnabled = false;
    }
  }

  Future<void> _persistMode(bool isPro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_pro_mode', isPro);
  }

  // Admin Overrides (for testing)
  void forceEnablePrivacyShelf(bool enable) {
    _privacyShelfEnabled = enable;
    notifyListeners();
  }

  void setForceProNudge(bool value) {
    _forceProNudge = value;
    notifyListeners();
  }
}
