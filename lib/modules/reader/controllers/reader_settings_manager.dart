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
    Brightness appBrightness = Brightness.light,
  }) : _appBrightness = appBrightness {
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
  bool get backgroundFollowsTheme => preferences.backgroundFollowsTheme;

  /// Light/dark of the app UI; decides the canvas while following the theme.
  Brightness _appBrightness;
  bool _lastFollowsTheme = true;

  /// The canvas actually painted: the manual pick, or cream / Sumi when the
  /// reader follows the app theme.
  Color _resolveBackground() {
    if (!preferences.backgroundFollowsTheme) return preferences.backgroundColor;
    return _appBrightness == Brightness.dark
        ? NyanColors.readerBgSumi
        : NyanColors.readerPaperDefault;
  }

  void _loadPreferences() {
    _fontSize = preferences.fontSize;
    _lineHeight = preferences.lineHeight;
    _lastFollowsTheme = preferences.backgroundFollowsTheme;
    _backgroundColor = _resolveBackground();
    _updateEngineConfig();
  }

  /// Called when the app flips between light and dark while the reader is open
  /// (system theme change under "match system").
  void setAppBrightness(Brightness brightness) {
    if (_appBrightness == brightness) return;
    _appBrightness = brightness;
    _backgroundColor = _resolveBackground();
    if (_updateEngineConfig()) onSettingsChanged();
  }

  ReaderConfig? _lastConfig;

  // The preferences service notifies for every field (warmth, brightness...).
  // Only push to the engine / notify the controller when the layout-relevant
  // config actually changed, otherwise dragging the warmth slider re-lays out
  // the body every frame.
  void _handlePreferencesChanged() {
    _fontSize = preferences.fontSize;
    _lineHeight = preferences.lineHeight;
    _backgroundColor = _resolveBackground();
    // The toggle can flip without changing the painted colour (cream manual
    // pick -> follow in a light app); the switch still has to redraw.
    final followsChanged = _lastFollowsTheme != preferences.backgroundFollowsTheme;
    _lastFollowsTheme = preferences.backgroundFollowsTheme;
    if (_updateEngineConfig() || followsChanged) onSettingsChanged();
  }

  bool _updateEngineConfig() {
    final isDark = _backgroundColor.computeLuminance() < 0.5;
    _textColor = isDark ? NyanColors.readerInkDark : NyanColors.readerInkDefault;

    final config = ReaderConfig(
      backgroundColor: _backgroundColor,
      textColor: _textColor,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      pageTurnMode: preferences.pageTurnMode,
      pageAnimation: preferences.pageAnimation,
      useSerif: preferences.useSerif,
    );
    if (config == _lastConfig) return false;
    _lastConfig = config;
    engine.setConfig(config);
    return true;
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

  void setBackgroundFollowsTheme(bool value) {
    unawaited(preferences.setBackgroundFollowsTheme(value));
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
