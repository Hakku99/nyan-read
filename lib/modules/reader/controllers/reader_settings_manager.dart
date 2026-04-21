import 'package:flutter/material.dart';

import '../../../core/services/reader_preferences_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/theme/nyan_colors.dart';
import '../../../core/utils/lifecycle_registry.dart';
import '../reader_engine/reader_engine.dart';

class ReaderSettingsManager {
  ReaderSettingsManager({
    required this.engine,
    required this.lifecycle,
    required this.onSettingsChanged,
  }) {
    _loadPreferences();
  }

  final ReaderEngine engine;
  final LifecycleRegistry lifecycle;
  final VoidCallback onSettingsChanged;

  double _fontSize = 18.0;
  double _lineHeight = 1.5;
  Color _backgroundColor = NyanColors.readerPaperDefault;
  Color _textColor = NyanColors.readerInkDefault;

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  Color get backgroundColor => _backgroundColor;
  Color get textColor => _textColor;

  void _loadPreferences() {
    final prefs = getIt<ReaderPreferencesService>();
    _fontSize = prefs.fontSize;
    _lineHeight = prefs.lineHeight;
    _backgroundColor = prefs.backgroundColor;
    _updateEngineConfig();
  }

  void _updateEngineConfig() {
    final isDark = _backgroundColor.computeLuminance() < 0.5;
    _textColor = isDark ? NyanColors.readerInkDark : NyanColors.readerInkDefault;

    final prefs = getIt<ReaderPreferencesService>();
    engine.setConfig(ReaderConfig(
      backgroundColor: _backgroundColor,
      textColor: _textColor,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      pageTurnMode: prefs.pageTurnMode,
      pageAnimation: prefs.pageAnimation,
    ));
  }

  void setFontSize(double size) {
    _fontSize = size;
    _updateEngineConfig();
    getIt<ReaderPreferencesService>().setFontSize(size);
    onSettingsChanged();
  }

  void setLineHeight(double height) {
    _lineHeight = height;
    _updateEngineConfig();
    getIt<ReaderPreferencesService>().setLineHeight(height);
    onSettingsChanged();
  }

  void setBackground(Color color) {
    _backgroundColor = color;
    _updateEngineConfig();
    getIt<ReaderPreferencesService>().setBackgroundColor(color);
    onSettingsChanged();
  }

  void handleLayoutChange(Size newSize, Size? lastSize, VoidCallback onUpdate) {
    if (lastSize != null &&
        (newSize.width - lastSize.width).abs() < 10 &&
        (newSize.height - lastSize.height).abs() < 10) {
      return;
    }

    const baseFontSize = 18.0;
    final scaleFactor = (newSize.width / 800).clamp(0.7, 1.5);
    final adjustedFontSize = (baseFontSize * scaleFactor).clamp(12.0, 32.0);

    if ((adjustedFontSize - _fontSize).abs() > 1.0) {
      _fontSize = adjustedFontSize;
      _updateEngineConfig();
      onUpdate();
    }
  }

  Future<void> dispose() async {}
}
