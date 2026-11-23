import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/nyan_sheet.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/bookshelf/home_screen.dart';

void main() {
  // Opens the sheet the same way home_screen does (non-dismissible).
  Future<void> openSheet(
    WidgetTester tester, {
    required Size logicalSize,
    required int count,
    required List<String> log,
  }) async {
    tester.view.physicalSize = logicalSize * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final books = [
      for (var i = 0; i < count; i++)
        Book(id: '$i', title: 'Book $i', author: 'A', format: 'txt'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: themePresets[ThemePreset.creamLight]!.themeData,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showNyanSheet<void>(
                context: context,
                isDismissible: false,
                builder: (_) => DeleteBooksSheetContent(
                  books: books,
                  onDelete: (_) => log.add('delete'),
                  onCancel: () => log.add('cancel'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(360, 800), Size(800, 360)]) {
    testWidgets('300 books at $size: Delete and Cancel on screen and tappable',
        (tester) async {
      final log = <String>[];
      await openSheet(tester, logicalSize: size, count: 300, log: log);

      expect(tester.takeException(), isNull);
      for (final label in ['Delete', 'Cancel']) {
        final r = tester.getRect(find.text(label));
        expect(r.top, greaterThanOrEqualTo(0), reason: label);
        expect(r.bottom, lessThanOrEqualTo(size.height), reason: label);
      }
      await tester.tap(find.text('Cancel'));
      await tester.tap(find.text('Delete'));
      expect(log, ['cancel', 'delete']);
    });
  }
}
