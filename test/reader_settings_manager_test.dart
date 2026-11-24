/// Changing a reading setting must lay the book out once, not twice: the manager
/// only persists and lets the preferences listener drive the engine.
library;

import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/core/theme/nyan_colors.dart';
import 'package:nyan_read/core/utils/lifecycle_registry.dart';
import 'package:nyan_read/modules/reader/controllers/reader_settings_manager.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingEngine implements ReaderEngine {
  final List<ReaderConfig> configs = [];

  @override
  void setConfig(ReaderConfig config) => configs.add(config);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final setters = <String,
      ({
    void Function(ReaderSettingsManager) apply,
    bool Function(ReaderConfig) changed,
  })>{
    'setFontSize': (
      apply: (m) => m.setFontSize(22),
      changed: (c) => c.fontSize == 22,
    ),
    'setLineHeight': (
      apply: (m) => m.setLineHeight(1.8),
      changed: (c) => c.lineHeight == 1.8,
    ),
    'setBackground': (
      apply: (m) => m.setBackground(const Color(0xFF1E1E1E)),
      changed: (c) => c.backgroundColor == const Color(0xFF1E1E1E),
    ),
  };

  for (final entry in setters.entries) {
    test('${entry.key} reconfigures the engine once and notifies once',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = ReaderPreferencesService();
      await prefs.initialize();
      final engine = _CountingEngine();
      var notified = 0;
      final manager = ReaderSettingsManager(
        engine: engine,
        lifecycle: LifecycleRegistry(),
        onSettingsChanged: () => notified++,
        preferences: prefs,
      );
      engine.configs.clear(); // drop the constructor's initial config

      entry.value.apply(manager);

      expect(engine.configs, hasLength(1));
      expect(entry.value.changed(engine.configs.single), isTrue);
      expect(notified, 1);
      await manager.dispose();
    });
  }

  Future<(ReaderPreferencesService, _CountingEngine, ReaderSettingsManager)>
      build(Map<String, Object> stored, {Brightness app = Brightness.light}) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = ReaderPreferencesService();
    await prefs.initialize();
    final engine = _CountingEngine();
    final manager = ReaderSettingsManager(
      engine: engine,
      lifecycle: LifecycleRegistry(),
      onSettingsChanged: () {},
      preferences: prefs,
      appBrightness: app,
    );
    return (prefs, engine, manager);
  }

  group('background follows app theme', () {
    test('fresh install resolves cream in light and Sumi in dark', () async {
      final (_, _, light) = await build({});
      expect(light.backgroundColor, NyanColors.readerPaperDefault);
      final (_, _, dark) = await build({}, app: Brightness.dark);
      expect(dark.backgroundColor, NyanColors.readerBgSumi);
    });

    test('setAppBrightness re-resolves and reconfigures the engine', () async {
      final (_, engine, manager) = await build({});
      engine.configs.clear();
      manager.setAppBrightness(Brightness.dark);
      expect(manager.backgroundColor, NyanColors.readerBgSumi);
      expect(engine.configs.single.backgroundColor, NyanColors.readerBgSumi);
      expect(engine.configs.single.textColor, NyanColors.readerInkDark);
    });

    test('a manual pick stops following and survives a theme flip', () async {
      final (prefs, _, manager) = await build({}, app: Brightness.dark);
      manager.setBackground(NyanColors.readerBgSepia);
      manager.setAppBrightness(Brightness.light);
      manager.setAppBrightness(Brightness.dark);
      expect(prefs.backgroundFollowsTheme, isFalse);
      expect(manager.backgroundColor, NyanColors.readerBgSepia);
    });

    test('re-enabling follow keeps the manual colour stored', () async {
      final (prefs, _, manager) = await build({}, app: Brightness.dark);
      manager.setBackground(NyanColors.readerBgSepia);
      manager.setBackgroundFollowsTheme(true);
      expect(manager.backgroundColor, NyanColors.readerBgSumi);
      expect(prefs.backgroundColor, NyanColors.readerBgSepia);
    });

    test('toggling follow without a colour change still notifies', () async {
      SharedPreferences.setMockInitialValues({
        'reader_background_color': NyanColors.readerPaperDefault.toARGB32(),
        'reader_background_follows_theme': false,
      });
      final prefs = ReaderPreferencesService();
      await prefs.initialize();
      var notified = 0;
      final manager = ReaderSettingsManager(
        engine: _CountingEngine(),
        lifecycle: LifecycleRegistry(),
        onSettingsChanged: () => notified++,
        preferences: prefs,
      );
      manager.setBackgroundFollowsTheme(true);
      expect(manager.backgroundColor, NyanColors.readerPaperDefault);
      expect(notified, 1);
    });

    test('upgrade: cream/absent colour follows, explicit picks do not',
        () async {
      for (final (color, follows) in [
        (null, true),
        (NyanColors.readerPaperDefault, true),
        (NyanColors.readerBgCream, true),
        (NyanColors.readerBgSepia, false),
        (NyanColors.readerBgSumi, false),
        (NyanColors.readerBgCharcoal, false),
      ]) {
        SharedPreferences.setMockInitialValues({
          if (color != null) 'reader_background_color': color.toARGB32(),
        });
        final prefs = ReaderPreferencesService();
        await prefs.initialize();
        expect(prefs.backgroundFollowsTheme, follows, reason: '$color');
      }
    });

    test('resetToDefaults restores following', () async {
      final (prefs, _, _) = await build({
        'reader_background_color': NyanColors.readerBgSepia.toARGB32(),
      });
      expect(prefs.backgroundFollowsTheme, isFalse);
      await prefs.resetToDefaults();
      expect(prefs.backgroundFollowsTheme, isTrue);
    });
  });

  test('setWarmth does not reconfigure the engine or notify', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = ReaderPreferencesService();
    await prefs.initialize();
    final engine = _CountingEngine();
    var notified = 0;
    final manager = ReaderSettingsManager(
      engine: engine,
      lifecycle: LifecycleRegistry(),
      onSettingsChanged: () => notified++,
      preferences: prefs,
    );
    engine.configs.clear();

    await prefs.setWarmth(0.6);

    expect(engine.configs, isEmpty);
    expect(notified, 0);
    await manager.dispose();
  });
}
