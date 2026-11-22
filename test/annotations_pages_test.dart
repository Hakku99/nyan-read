/// Audit P2-15 follow-up: when the DB read fails, the notes / bookmarks pages
/// must show an error state — and a header that does not claim "0 saved".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/database_service.dart';
import 'package:nyan_read/core/services/riverpod_providers.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/bookmark/bookmark_list_page.dart';
import 'package:nyan_read/modules/notes/notes_list_page.dart';

class _FlakyDb extends DatabaseService {
  bool failing = true;

  @override
  Future<List<Map<String, dynamic>>> getBookmarks(String bookId) async {
    if (failing) throw StateError('db locked');
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> getHighlights(String bookId) async {
    if (failing) throw StateError('db locked');
    return const [];
  }
}

Future<void> _pump(WidgetTester tester, _FlakyDb db, Widget page) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseServiceRpProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: themePresets[ThemePreset.creamLight]!.themeData,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bookmarks: failed read shows error, no "0 saved", Retry works',
      (tester) async {
    final db = _FlakyDb();
    await _pump(
      tester,
      db,
      const BookmarkListPage(bookId: 'b', bookTitle: 'T'),
    );

    expect(find.text("Couldn't load bookmarks"), findsOneWidget);
    expect(find.text('0 saved'), findsNothing);
    expect(find.text('No bookmarks yet'), findsNothing);

    db.failing = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load bookmarks"), findsNothing);
    expect(find.text('0 saved'), findsOneWidget);
    expect(find.text('No bookmarks yet'), findsOneWidget);
  });

  testWidgets('notes: failed read shows error, no "(0)", Retry works',
      (tester) async {
    final db = _FlakyDb();
    await _pump(
      tester,
      db,
      const NotesListPage(bookId: 'b', bookTitle: 'T'),
    );

    expect(find.text("Couldn't load highlights"), findsOneWidget);
    expect(find.text('Highlights & Notes'), findsOneWidget);
    expect(find.text('Notes & Highlights (0)'), findsNothing);
    expect(find.text('No reading notes yet'), findsNothing);

    db.failing = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load highlights"), findsNothing);
    expect(find.text('Notes & Highlights (0)'), findsOneWidget);
    expect(find.text('No reading notes yet'), findsOneWidget);
  });
}
