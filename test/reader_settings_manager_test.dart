/// Setting a font size must lay the book out once, not twice: the manager
/// only persists and lets the preferences listener drive the engine.
library;

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

  test('setFontSize reconfigures the engine once and notifies once', () async {
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

    manager.setFontSize(22);

    expect(engine.configs, hasLength(1));
    expect(engine.configs.single.fontSize, 22);
    expect(notified, 1);
    expect(manager.fontSize, 22);
    await manager.dispose();
  });
}
