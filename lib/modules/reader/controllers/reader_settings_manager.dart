import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/reader_preferences_service.dart';
import '../../../core/theme/nyan_colors.dart';
import '../../../core/utils/lifecycle_registry.dart';
import '../reader_engine/reader_engine.dart';

class ReaderSettingsManager {
  ReaderSettingsManager({
    required this.engine,
    required this.lifecycle,
    required this.onSettingsChanged,
    required this.preferences,
  }) {
    preferences.addListener(_handlePreferencesChanged);
    _loadPreferences();
  }

  final ReaderEngine engine;
  final LifecycleRegistry lifecycle;
  final VoidCallback onSettingsChanged;
  final ReaderPreferencesService preferences;

  double _fontSize = 18.0;
  double _lineHeight = 1.5;
  Color _backgroundColor = NyanColors.readerPaperDefault;
  Color _textColor = NyanColors.readerInkDefault;

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  Color get backgroundColor => _backgroundColor;
  Color get textColor => _textColor;

  void _loadPreferences() {
    _fontSize = preferences.fontSize;
    _lineHeight = preferences.lineHeight;
    _backgroundColor = preferences.backgroundColor;
    _updateEngineConfig();
  }

  void _handlePreferencesChanged() {
    _fontSize = preferences.fontSize;
    _lineHeight = preferences.lineHeight;
    _backgroundColor = preferences.backgroundColor;
    _updateEngineConfig();
    onSettingsChanged();
  }

  void _updateEngineConfig() {
    final isDark = _backgroundColor.computeLuminance() < 0.5;
    _textColor = isDark ? NyanColors.readerInkDark : NyanColors.readerInkDefault;

    engine.setConfig(ReaderConfig(
      backgroundColor: _backgroundColor,
      textColor: _textColor,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      pageTurnMode: preferences.pageTurnMode,
      pageAnimation: preferences.pageAnimation,
      useSerif: preferences.useSerif,
    ));
  }

  // The three setters below only persist: preferences.notifyListeners fires
  // _handlePreferencesChanged synchronously, which updates the engine config
  // and calls onSettingsChanged. Doing it here too re-laid out the book twice
  // per drag frame.
  void setFontSize(double size) {
    unawaited(preferences.setFontSize(size));
  }

  void setLineHeight(double height) {
    unawaited(preferences.setLineHeight(height));
  }

  void setBackground(Color color) {
    unawaited(preferences.setBackgroundColor(color));
  }

  void setPageTurnMode(PageTurnMode mode) {
    // Persisting fires _handlePreferencesChanged, which re-calls
    // _updateEngineConfig + onSettingsChanged — no need to duplicate here.
    unawaited(preferences.setPageTurnMode(mode));
  }

  void setUseSerif(bool value) {
    unawaited(preferences.setUseSerif(value));
  }

  Future<void> dispose() async {
    preferences.removeListener(_handlePreferencesChanged);
  }
}
