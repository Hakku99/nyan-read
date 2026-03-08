import 'package:screen_brightness/screen_brightness.dart';

class SystemBrightnessAdapter {
  SystemBrightnessAdapter({ScreenBrightness? plugin})
      : _plugin = plugin ?? ScreenBrightness();

  final ScreenBrightness _plugin;

  Future<double> currentBrightness() async {
    final value = await _plugin.current;
    return _normalize(value);
  }

  Stream<double> brightnessChanges() {
    return _plugin.onCurrentBrightnessChanged.map(_normalize);
  }

  Future<void> setSystemBrightness(double brightness) async {
    await _plugin.setScreenBrightness(_normalize(brightness));
  }

  Future<void> resetSystemBrightness() async {
    await _plugin.resetScreenBrightness();
  }

  double _normalize(double value) => value.clamp(0.0, 1.0).toDouble();
}
