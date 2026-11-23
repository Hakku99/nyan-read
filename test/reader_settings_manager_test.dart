/// Changing a reading setting must lay the book out once, not twice: the manager
/// only persists and lets the preferences listener drive the engine.
library;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
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
