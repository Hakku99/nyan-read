import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/modules/reader/brightness/brightness_orchestrator.dart';
import 'package:nyan_read/modules/reader/brightness/brightness_repository.dart';
import 'package:nyan_read/modules/reader/brightness/system_brightness_adapter.dart';
import 'package:nyan_read/modules/reader/controllers/brightness_controller.dart';
import 'package:nyan_read/modules/reader/reader_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSystemBrightnessAdapter extends SystemBrightnessAdapter {
  FakeSystemBrightnessAdapter({this.currentValue = 0.5});

  double currentValue;
  final List<double> setCalls = <double>[];
  int resetCalls = 0;
  final StreamController<double> _changes = StreamController<double>.broadcast();

  @override
  Future<double> currentBrightness() async => currentValue;

  @override
  Stream<double> brightnessChanges() => _changes.stream;

  @override
  Future<void> setSystemBrightness(double brightness) async {
    currentValue = brightness;
    setCalls.add(brightness);
    _changes.add(brightness);
  }

  @override
  Future<void> resetSystemBrightness() async {
    resetCalls += 1;
    currentValue = 0.5;
    _changes.add(currentValue);
  }

  void emitExternalBrightness(double brightness) {
    currentValue = brightness;
    _changes.add(brightness);
  }

  Future<void> close() async {
    await _changes.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    GetIt.instance.allowReassignment = true;
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  test('ReaderController manual adjustment exits Follow System mode', () async {
    final prefs = ReaderPreferencesService();
    await prefs.initialize();
    GetIt.instance.registerSingleton<ReaderPreferencesService>(prefs);

    final adapter = FakeSystemBrightnessAdapter(currentValue: 0.5);
    final brightnessController = BrightnessController(
      BrightnessOrchestrator(
        repository: BrightnessRepository(prefs),
        systemAdapter: adapter,
      ),
    );
    await brightnessController.initialize();

    final controller = ReaderController(
      Book(
        id: 'test_book',
        title: 'Test Title',
        author: 'Unknown',
        filePath: '/test/path',
        format: 'txt',
      ),
    );
    controller.attachBrightnessController(brightnessController);

    expect(controller.followSystem, true);

    await controller.setBrightness(0.8);

    expect(controller.followSystem, false);
    expect(controller.brightness, 0.8);
    expect(adapter.setCalls.last, 0.8);

    await brightnessController.shutdown();
    brightnessController.dispose();
    await adapter.close();
    controller.dispose();
  });

  test('ReaderController warmth delegates through brightness boundary', () async {
    final prefs = ReaderPreferencesService();
    await prefs.initialize();
    GetIt.instance.registerSingleton<ReaderPreferencesService>(prefs);

    final adapter = FakeSystemBrightnessAdapter(currentValue: 0.5);
    final brightnessController = BrightnessController(
      BrightnessOrchestrator(
        repository: BrightnessRepository(prefs),
        systemAdapter: adapter,
      ),
    );
    await brightnessController.initialize();

    final controller = ReaderController(
      Book(
        id: 'test_book',
        title: 'Test Title',
        author: 'Unknown',
        filePath: '/test/path',
        format: 'txt',
      ),
    );
    controller.attachBrightnessController(brightnessController);

    expect(controller.warmth, 0.0);

    await controller.setWarmth(0.4);

    expect(controller.warmth, 0.4);
    expect(prefs.warmth, 0.4);

    await brightnessController.shutdown();
    brightnessController.dispose();
    await adapter.close();
    controller.dispose();
  });

  test('Follow System mode stops writing brightness and tracks external changes', () async {
    final prefs = ReaderPreferencesService();
    await prefs.initialize();
    GetIt.instance.registerSingleton<ReaderPreferencesService>(prefs);

    final adapter = FakeSystemBrightnessAdapter(currentValue: 0.5);
    final orchestrator = BrightnessOrchestrator(
      repository: BrightnessRepository(prefs),
      systemAdapter: adapter,
    );
    final brightnessController = BrightnessController(orchestrator);
    await brightnessController.initialize();

    await brightnessController.setBrightness(0.7);
    final manualWriteCount = adapter.setCalls.length;

    await brightnessController.resetToSystem();
    expect(brightnessController.followSystem, true);
    expect(adapter.setCalls.length, manualWriteCount);
    expect(adapter.resetCalls, 1);

    adapter.emitExternalBrightness(0.35);
    await Future<void>.delayed(Duration.zero);

    expect(brightnessController.uiBrightnessValue.value, 0.35);
    expect(adapter.setCalls.length, manualWriteCount);

    await brightnessController.shutdown();
    brightnessController.dispose();
    await adapter.close();
  });
}
