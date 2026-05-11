import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/modules/reader/brightness/brightness_orchestrator.dart';
import 'package:nyan_read/modules/reader/brightness/brightness_repository.dart';
import 'package:nyan_read/modules/reader/brightness/overlay_brightness_policy.dart';
import 'package:nyan_read/modules/reader/brightness/system_brightness_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSystemBrightnessAdapter extends SystemBrightnessAdapter {
  FakeSystemBrightnessAdapter({this.currentValue = 0.4});

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
    currentValue = 0.4;
    _changes.add(currentValue);
  }

  Future<void> close() async {
    await _changes.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('manual brightness uses hardware floor and overlay only below floor',
      () async {
    final prefs = ReaderPreferencesService();
    await prefs.initialize();
    final adapter = FakeSystemBrightnessAdapter(currentValue: 0.4);
    final orchestrator = BrightnessOrchestrator(
      repository: BrightnessRepository(prefs),
      systemAdapter: adapter,
    );

    await orchestrator.initialize();
    orchestrator.previewBrightness(0.02);
    await orchestrator.commitBrightness(0.02);

    expect(orchestrator.state.uiBrightness, 0.02);
    expect(orchestrator.state.targetSystemBrightness, 0.05);
    expect(
      orchestrator.state.overlayOpacity,
      closeTo(0.6 * OverlayBrightnessPolicy.maxOverlayOpacity, 0.001),
    );
    expect(adapter.setCalls.last, 0.05);

    await orchestrator.shutdown();
    await adapter.close();
  });

  test('pause and resume restore then reapply brightness once each', () async {
    final prefs = ReaderPreferencesService();
    await prefs.initialize();
    await prefs.setBrightness(0.7);

    final adapter = FakeSystemBrightnessAdapter(currentValue: 0.4);
    final orchestrator = BrightnessOrchestrator(
      repository: BrightnessRepository(prefs),
      systemAdapter: adapter,
    );

    await orchestrator.initialize();
    expect(adapter.setCalls, <double>[0.7]);

    orchestrator.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);
    expect(adapter.setCalls, <double>[0.7, 0.4]);

    orchestrator.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(adapter.setCalls, <double>[0.7, 0.4, 0.7]);

    await orchestrator.shutdown();
    await adapter.close();
  });

  test('shutdown restores original system brightness after manual mode',
      () async {
    final prefs = ReaderPreferencesService();
    await prefs.initialize();

    final adapter = FakeSystemBrightnessAdapter(currentValue: 0.4);
    final orchestrator = BrightnessOrchestrator(
      repository: BrightnessRepository(prefs),
      systemAdapter: adapter,
    );

    await orchestrator.initialize();
    orchestrator.previewBrightness(0.8);
    await orchestrator.commitBrightness(0.8);

    await orchestrator.shutdown();

    expect(adapter.setCalls.last, 0.4);
    await adapter.close();
  });

  test('software dim overlay never reaches full opacity', () {
    const policy = OverlayBrightnessPolicy();
    expect(
      policy.calculate(uiBrightness: 0.0, hardwareFloor: 0.05),
      closeTo(OverlayBrightnessPolicy.maxOverlayOpacity, 0.001),
    );
  });

  test('follow-system brightness transitions smoothly instead of jumping',
      () async {
    final prefs = ReaderPreferencesService();
    await prefs.initialize();

    final adapter = FakeSystemBrightnessAdapter(currentValue: 0.30);
    final orchestrator = BrightnessOrchestrator(
      repository: BrightnessRepository(prefs),
      systemAdapter: adapter,
    );

    await orchestrator.initialize();
    expect(orchestrator.state.followSystem, isTrue);
    expect(orchestrator.state.uiBrightness, closeTo(0.30, 0.001));

    adapter.currentValue = 0.85;
    adapter._changes.add(0.85);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final earlyValue = orchestrator.state.uiBrightness;
    expect(earlyValue, greaterThan(0.30));
    expect(earlyValue, lessThan(0.50));

    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(orchestrator.state.uiBrightness, closeTo(0.85, 0.02));

    await orchestrator.shutdown();
    await adapter.close();
  });

  test('resume brightness transitions smoothly without abrupt flash',
      () async {
    final prefs = ReaderPreferencesService();
    await prefs.initialize();
    await prefs.setBrightness(0.75);

    final adapter = FakeSystemBrightnessAdapter(currentValue: 0.50);
    final orchestrator = BrightnessOrchestrator(
      repository: BrightnessRepository(prefs),
      systemAdapter: adapter,
    );

    await orchestrator.initialize();
    expect(orchestrator.state.uiBrightness, closeTo(0.75, 0.001));

    // Simulate pause: restores system brightness
    orchestrator.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);
    expect(orchestrator.state.uiBrightness, closeTo(0.50, 0.001));

    // Simulate resume: should transition back smoothly, not flash
    orchestrator.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // Early in transition, should be between restored and target
    final midTransition = orchestrator.state.uiBrightness;
    expect(midTransition, greaterThan(0.50));
    expect(midTransition, lessThan(0.75));

    // Wait for completion
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    expect(orchestrator.state.uiBrightness, closeTo(0.75, 0.02));

    await orchestrator.shutdown();
    await adapter.close();
  });
}
