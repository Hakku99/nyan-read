import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/database_service.dart';
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
  final StreamController<double> _changes =
      StreamController<double>.broadcast();

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

class _NoopDatabaseService extends DatabaseService {}

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
    final db = _NoopDatabaseService();
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
      readerPreferencesService: prefs,
      databaseService: db,
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

  test('ReaderController warmth delegates through brightness boundary',
      () async {
    final prefs = ReaderPreferencesService();
    final db = _NoopDatabaseService();
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
      readerPreferencesService: prefs,
      databaseService: db,
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

  // -------------------------------------------------------------------------
  // _isDisposed guard tests (Phase-1 fix)
  // -------------------------------------------------------------------------

  test('dispose() then setBrightness() does not throw FlutterError', () async {
    final prefs = ReaderPreferencesService();
    final db = _NoopDatabaseService();
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
        id: 'disposed-book',
        title: 'Disposed Test',
        author: 'Unknown',
        filePath: '/test/path',
        format: 'txt',
      ),
      readerPreferencesService: prefs,
      databaseService: db,
    );
    controller.attachBrightnessController(brightnessController);

    // Dispose first, then call a setter that previously triggered
    // notifyListeners → FlutterError "notifyListeners called after dispose".
    controller.dispose();

    // Must complete without throwing.
    await expectLater(controller.setBrightness(0.7), completes);
    await expectLater(controller.setWarmth(0.3), completes);

    await brightnessController.shutdown();
    brightnessController.dispose();
    await adapter.close();
  });

  test('late async manager callback after dispose() is silently dropped',
      () async {
    // Verifies _safeNotifyListeners acts as a dead-drop for callbacks that
    // fire after the controller is disposed (e.g. a DB read completing after
    // the reader page has been popped).
    final prefs = ReaderPreferencesService();
    final db = _NoopDatabaseService();
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
        id: 'safe-notify-book',
        title: 'SafeNotify Test',
        author: 'Unknown',
        filePath: '/test/path',
        format: 'txt',
      ),
      readerPreferencesService: prefs,
      databaseService: db,
    );
    controller.attachBrightnessController(brightnessController);

    var listenerFireCount = 0;
    controller.addListener(() => listenerFireCount++);

    // Dispose before any simulated late callback.
    controller.dispose();

    // Simulate a late async callback reaching _safeNotifyListeners directly.
    // After dispose the guard must suppress notifyListeners without throwing.
    // We can't call _safeNotifyListeners directly (private), so we rely on
    // the fact that calling setBrightness after dispose must not increment
    // listenerFireCount (no live listeners on a disposed ChangeNotifier).
    await controller.setBrightness(0.9);

    // listenerFireCount stays at 0 because no notification went through.
    expect(listenerFireCount, 0);

    await brightnessController.shutdown();
    brightnessController.dispose();
    await adapter.close();
  });

  test(
      'Follow System mode stops writing brightness and tracks external changes',
      () async {
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
    // Follow-system mode smooths toward the reported system brightness on a
    // 16ms timer; a single microtask is not enough for the UI value to settle.
    for (var i = 0; i < 80; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if ((brightnessController.uiBrightnessValue.value - 0.35).abs() < 0.005) {
        break;
      }
    }

    expect(brightnessController.uiBrightnessValue.value, closeTo(0.35, 0.01));
    expect(adapter.setCalls.length, manualWriteCount);

    await brightnessController.shutdown();
    brightnessController.dispose();
    await adapter.close();
  });
}
