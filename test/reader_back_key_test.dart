/// System back inside the reader peels one layer at a time: a grown One Paper
/// sheet (or the brightness popover) closes first; only a resting dock exits.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/database_service.dart';
import 'package:nyan_read/core/services/feature_manager.dart';
import 'package:nyan_read/core/services/privacy_screen_service.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/core/services/reading_reminder_service.dart';
import 'package:nyan_read/core/services/riverpod_providers.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/reader/controllers/reader_controller_provider.dart';
import 'package:nyan_read/modules/reader/reader_page.dart';
import 'package:nyan_read/modules/reader/widgets/one_paper_dock.dart';
import 'package:nyan_read/modules/reader/widgets/reader_brightness_popover.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reader_menu_test.dart' show MockReaderController, MockThemeManager;

class _OneBookDb extends DatabaseService {
  @override
  Future<Map<String, dynamic>?> getBookById(String bookId) async => {
        'id': bookId,
        'title': 'Test Book',
        'file_path': '/test/path',
        'format': 'txt',
        'is_private': 0,
      };
}

void main() {
  Future<void> openReader(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = ReaderPreferencesService();
    await prefs.initialize();
    final themeManager = MockThemeManager();
    final navKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseServiceRpProvider.overrideWithValue(_OneBookDb()),
        readerPreferencesRpProvider.overrideWithValue(prefs),
        readingReminderRpProvider.overrideWithValue(ReadingReminderService()),
        themeManagerRpProvider.overrideWithValue(themeManager),
        featureManagerRpProvider.overrideWithValue(FeatureManager()),
        privacyScreenRpProvider
            .overrideWithValue(PrivacyScreenService(nativeEnabled: false)),
        readerControllerRpProvider
            .overrideWith((ref, args) => MockReaderController()),
      ],
      child: MaterialApp(
        navigatorKey: navKey,
        theme: themeManager.currentThemeData,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Text('shelf'),
      ),
    ));
    navKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const ReaderPage(bookId: 'b1'),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderPage), findsOneWidget);
  }

  bool sheetOpen(WidgetTester tester) =>
      tester.widget<OnePaperDock>(find.byType(OnePaperDock)).sheetOpen;

  testWidgets('back collapses a grown sheet before leaving the reader',
      (tester) async {
    await openReader(tester);
    tester
        .widget<DockFooter>(find.byType(DockFooter))
        .onAction(DockAction.settings);
    await tester.pumpAndSettle();
    expect(sheetOpen(tester), isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ReaderPage), findsOneWidget);
    expect(sheetOpen(tester), isFalse);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ReaderPage), findsNothing);
    expect(find.text('shelf'), findsOneWidget);
  });

  testWidgets('back closes the brightness popover before leaving the reader',
      (tester) async {
    await openReader(tester);
    // Centre tap raises the chrome so the top-bar sun button is hittable.
    await tester.tapAt(tester.getCenter(find.byType(ReaderPage)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(NyanIcons.sun));
    await tester.pumpAndSettle();
    bool popoverVisible() => tester
        .widget<ReaderBrightnessPopover>(find.byType(ReaderBrightnessPopover))
        .visible;
    expect(popoverVisible(), isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ReaderPage), findsOneWidget);
    expect(popoverVisible(), isFalse);
  });
}
