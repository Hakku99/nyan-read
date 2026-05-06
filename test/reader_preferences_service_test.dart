import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to up-down page turn mode', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ReaderPreferencesService();

    await service.initialize();

    expect(service.pageTurnMode, PageTurnMode.upDown);
  });

  test('persists page turn mode selection', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ReaderPreferencesService();
    await service.initialize();

    await service.setPageTurnMode(PageTurnMode.leftRight);
    await service.flushPendingWrites();

    final reloaded = ReaderPreferencesService();
    await reloaded.initialize();

    expect(reloaded.pageTurnMode, PageTurnMode.leftRight);
  });
}
