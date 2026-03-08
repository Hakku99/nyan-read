import '../../../core/services/reader_preferences_service.dart';

class BrightnessRepository {
  BrightnessRepository(this._preferences);

  final ReaderPreferencesService _preferences;

  Future<double?> loadManualBrightness() async {
    return _preferences.brightness;
  }

  Future<void> saveManualBrightness(double brightness) async {
    await _preferences.setBrightness(brightness.clamp(0.0, 1.0).toDouble());
  }

  Future<void> clearManualBrightness() async {
    await _preferences.setBrightness(null);
  }

  bool get isFollowingSystem => _preferences.brightness == null;
}
