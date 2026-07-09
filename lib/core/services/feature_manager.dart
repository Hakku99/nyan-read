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
  bool _isPrivateShelfUnlocked = false;
  bool _forceProNudge = false;

  AppMode get currentMode => _currentMode;
  bool get adsEnabled => _adsEnabled;
  bool get privacyShelfEnabled => _privacyShelfEnabled;
  bool get isPro => _currentMode == AppMode.pro;
  bool get isPrivateShelfUnlocked => _isPrivateShelfUnlocked;
  bool get forceProNudge => _forceProNudge;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // ponytail: debug builds always start as Pro so the admin panel is reachable.
    final isPro = kDebugMode || (prefs.getBool('is_pro_mode') ?? false);
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
    // TTS was removed from the Pro feature set (2026-07): only an
    // unreachable stub UI ever existed, so listing it was an empty promise.
    // Re-add via a ReaderEngine Capability when actually built (Phase 5).
    if (mode == AppMode.pro) {
      _adsEnabled = false;
      _privacyShelfEnabled = true;
    } else {
      _adsEnabled = true;
      _privacyShelfEnabled = false;
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
