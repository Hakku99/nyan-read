import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/bookshelf/home_screen.dart';

void main() {
  testWidgets('300 books: Delete and Cancel stay on screen and tappable',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    var deleted = false;
    var cancelled = false;
    final books = [
      for (var i = 0; i < 300; i++)
        Book(id: '$i', title: 'Book $i', author: 'A', format: 'txt'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: themePresets[ThemePreset.creamLight]!.themeData,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: DeleteBooksSheetContent(
              books: books,
              onDelete: (_) => deleted = true,
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    for (final label in ['Delete', 'Cancel']) {
      final r = tester.getRect(find.text(label));
      expect(r.bottom, lessThanOrEqualTo(screen.height), reason: label);
    }
    await tester.tap(find.text('Cancel'));
    await tester.tap(find.text('Delete'));
    expect(cancelled, isTrue);
    expect(deleted, isTrue);
  });
}
