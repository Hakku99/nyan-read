import 'package:flutter/material.dart';
import '../../lib/modules/reader/reader_engine/reader_engine.dart';
import '../../lib/core/utils/lifecycle_registry.dart';
import '../../lib/modules/reader/controllers/reader_settings_manager.dart';

class MockReaderSettingsManager implements ReaderSettingsManager {
  @override
  final ReaderEngine engine;
  @override
  final LifecycleRegistry lifecycle;
  @override
  final VoidCallback onSettingsChanged;

  MockReaderSettingsManager({
    required this.engine,
    required this.lifecycle,
    required this.onSettingsChanged,
  });

  @override
  double get fontSize => 18.0;

  @override
  double get lineHeight => 1.5;

  @override
  double get brightness => 0.8;

  @override
  Color get backgroundColor => Colors.white;

  @override
  Color get textColor => Colors.black;

  @override
  bool get followSystem => false;

  @override
  void attachBrightnessController(dynamic bc) {}

  @override
  void handleLayoutChange(
      Size newSize, Size? lastSize, VoidCallback onUpdate) {}

  @override
  void setBackground(Color color) {}

  @override
  Future<void> setBrightness(double b) async {}

  @override
  void setFontSize(double size) {}

  @override
  void setLineHeight(double height) {}

  @override
  Future<void> toggleFollowSystem() async {}

  @override
  void detachBrightnessController() {}

  @override
  Future<void> dispose() async {}
}
