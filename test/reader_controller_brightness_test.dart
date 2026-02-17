import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nyan_read/modules/reader/reader_page.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

// Mock ReaderPreferencesService
class MockReaderPreferencesService extends Mock
    implements ReaderPreferencesService {
  @override
  double? get brightness => 0.5;

  @override
  double get fontSize => 18.0;

  @override
  double get lineHeight => 1.5;

  @override
  Color get backgroundColor => const Color(0xFFFDFCF8);

  // Stubs for setters if needed
  @override
  Future<void> setFontSize(double size) async {}
  @override
  Future<void> setLineHeight(double height) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
}

void main() {
  // Setup SharedPreferences for testing
  SharedPreferences.setMockInitialValues({});

  test('ReaderController setBrightness breaks Follow System mode', () async {
    // 1. Setup
    final book = const Book(
      id: 'test_book',
      title: 'Test Title',
      path: '/test/path',
      format: 'txt',
      size: 1000,
      lastReadPosition: '',
      addedAt: 0,
    );

    // Mock singleton before controller init
    // Note: ReaderController implementation accesses ReaderPreferencesService.instance directly.
    // Since we can't easily mock the static instance without refactoring (or using a service locator fully),
    // we rely on SharedPreferences.setMockInitialValues which the real service uses.
    // However, ReaderPreferencesService is a singleton.
    // For this unit test context, we can just rely on the controller's internal state logic
    // since we are testing logic: setBrightness -> updates _followSystem.

    // We need to initialize the controller.
    // It does some async work in constructor/init, but for this specific test
    // we just want to test setBrightness and toggleFollowSystem behavior.

    final controller = ReaderController(book);

    // 2. Enable Follow System
    // Toggle ON
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
