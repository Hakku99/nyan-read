import 'package:flutter/material.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/core/utils/lifecycle_registry.dart';
import 'package:nyan_read/modules/reader/controllers/reader_settings_manager.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';

class MockReaderSettingsManager implements ReaderSettingsManager {
  MockReaderSettingsManager({
    required this.engine,
    required this.lifecycle,
    ReaderPreferencesService? preferences,
    required this.onSettingsChanged,
  }) : preferences = preferences ?? ReaderPreferencesService();

  @override
  final ReaderEngine engine;

  @override
  final LifecycleRegistry lifecycle;

  @override
  final VoidCallback onSettingsChanged;

  @override
  final ReaderPreferencesService preferences;

  @override
  double get fontSize => 18.0;

  @override
  double get lineHeight => 1.5;

  @override
  Color get backgroundColor => Colors.white;

  @override
  Color get textColor => Colors.black;

  @override
  void handleLayoutChange(
    Size newSize,
    Size? lastSize,
    VoidCallback onUpdate,
  ) {}

  @override
  void setBackground(Color color) {}

  @override
  void setFontSize(double size) {}

  @override
  void setLineHeight(double height) {}

  @override
  void setPageTurnMode(PageTurnMode mode) {}

  @override
  void setUseSerif(bool value) {}

  @override
  Future<void> dispose() async {}
}
