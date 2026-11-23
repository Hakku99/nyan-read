/// The recent-searches list belongs to the public shelf; the private search
/// page must not render it (it would expose public terms behind the PIN and
/// imply private queries are remembered).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/bookshelf_preferences_service.dart';
import 'package:nyan_read/core/services/feature_manager.dart';
import 'package:nyan_read/core/services/privacy_screen_service.dart';
import 'package:nyan_read/core/services/riverpod_providers.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/bookshelf/book_search_page.dart';
import 'package:nyan_read/modules/bookshelf/bookshelf_view_model.dart';
import 'package:nyan_read/modules/bookshelf/bookshelf_view_model_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeVm extends Fake implements BookshelfViewModel {
  @override
  List<Never> get publicBooks => const [];
  @override
  List<Never> get privateBooks => const [];
}

void main() {
  Future<void> pumpPage(WidgetTester tester, {required bool isPrivate}) async {
    SharedPreferences.setMockInitialValues({
      // Purge flag set so the seeded public term survives initialize().
      'bookshelf_recent_searches_purged_v1': true,
      'bookshelf_recent_searches': ['public term'],
    });
    final prefs = BookshelfPreferencesService();
    await tester.runAsync(prefs.initialize);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        bookshelfPreferencesRpProvider.overrideWithValue(prefs),
        bookshelfViewModelRpProvider.overrideWithValue(_FakeVm()),
        featureManagerRpProvider
            .overrideWithValue(FeatureManager()..unlockPrivateShelf()),
        privacyScreenRpProvider
            .overrideWithValue(PrivacyScreenService(nativeEnabled: false)),
      ],
      child: MaterialApp(
        theme: themePresets[ThemePreset.creamLight]!.themeData,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BookSearchPage(isPrivate: isPrivate),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('public search page lists recent searches', (tester) async {
    await pumpPage(tester, isPrivate: false);
    expect(find.text('public term'), findsOneWidget);
  });

  testWidgets('private search page does not show the shared recents',
      (tester) async {
    await pumpPage(tester, isPrivate: true);
    expect(find.text('public term'), findsNothing);
    expect(find.text('Searches in the private shelf are not saved.'),
        findsOneWidget);
  });
}
