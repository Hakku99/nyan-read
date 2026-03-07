import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:nyan_read/modules/reader/reader_page.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'dart:async';

// Mock ReaderPreferencesService
class MockReaderPreferencesService implements ReaderPreferencesService {
  @override
  double? get brightness => 0.5;

  @override
  double get fontSize => 18.0;

  @override
  double get lineHeight => 1.5;

  @override
  Color get backgroundColor => const Color(0xFFFDFCF8);

  @override
  double get minPhysicalBrightness => 0.1;

  @override
  double get followSystemOffset => 0.0;

  @override
  double get warmth => 0.0;

  @override
  PageTurnMode get pageTurnMode => PageTurnMode.swipe;

  @override
  PageAnimation get pageAnimation => PageAnimation.fade;

  @override
  bool get hasListeners => false;

  @override
  double getPerceptualBrightness(double val) => val * val;

  @override
  Future<void> setFontSize(double size) async {}
  @override
  Future<void> setLineHeight(double height) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> setPageTurnMode(PageTurnMode mode) async {}
  @override
  Future<void> setPageAnimation(PageAnimation animation) async {}
  @override
  Future<void> initialize() async {}
  @override
  Future<void> resetToDefaults() async {}
  @override
  Future<void> setBrightness(double? b) async {}
  @override
  Future<void> setWarmth(double w) async {}
  @override
  Future<void> setMinPhysicalBrightness(double m) async {}
  @override
  Future<void> setFollowSystemOffset(double o) async {}
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  void notifyListeners() {}
  @override
  void dispose() {}
}

class MockScreenBrightnessPlatform extends ScreenBrightnessPlatform {
  @override
  Future<double> get current async => 0.5;

  @override
  Future<double> get system async => 0.5;

  @override
  Future<double> get application async => 0.5;

  @override
  Future<void> setScreenBrightness(double brightness) async {}

  @override
  Future<void> resetScreenBrightness() async {}

  @override
  Future<void> setApplicationScreenBrightness(double brightness) async {}

  @override
  Future<void> resetApplicationScreenBrightness() async {}

  @override
  Stream<double> get onSystemScreenBrightnessChanged => const Stream.empty();

  @override
  Stream<double> get onApplicationScreenBrightnessChanged =>
      const Stream.empty();

  @override
  Future<bool> get hasApplicationScreenBrightnessChanged async => false;

  @override
  Future<bool> get isAutoReset async => false;

  @override
  Future<void> setAutoReset(bool isAutoReset) async {}

  @override
  Future<bool> get isAnimate async => true;

  @override
  Future<void> setAnimate(bool isAnimate) async {}

  @override
  Future<bool> get canChangeSystemBrightness async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Setup SharedPreferences for testing
  SharedPreferences.setMockInitialValues({});

  setUp(() {
    ScreenBrightnessPlatform.instance = MockScreenBrightnessPlatform();
    final getIt = GetIt.instance;
    getIt.allowReassignment = true;
    getIt.registerSingleton<ReaderPreferencesService>(
        MockReaderPreferencesService());
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  test('ReaderController setBrightness breaks Follow System mode', () async {
    // Setup
    final book = Book(
      id: 'test_book',
      title: 'Test Title',
      author: 'Unknown',
      filePath: '/test/path',
      format: 'txt',
    );

    final controller = ReaderController(book);

    // 2. Enable Follow System
    await controller.toggleFollowSystem();
    expect(controller.followSystem, true, reason: "Follow System should be ON");

    // 3. Manually set brightness
    await controller.setBrightness(0.8);

    // 4. Verify
    expect(controller.followSystem, false,
        reason: "Follow System should be OFF after manual adjustment");
    expect(controller.brightness, 0.8,
        reason: "Brightness should be updated to 0.8");
  });
}
