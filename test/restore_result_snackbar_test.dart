/// `showRestoreResult`: cancelled picker (null) is silent; no local match asks
/// for the book files first; matched-but-unwritten is a neutral notice;
/// written is the success message, with optional unmatched / private notes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/database_service.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/settings/settings_page.dart';

Future<void> _show(WidgetTester tester, RestoreResult? result) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: themePresets[ThemePreset.creamLight]!.themeData,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRestoreResult(context, result),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump(const Duration(milliseconds: 400));
}

// SnackBarUtils keeps a static active toast; let it expire so the next test
// does not try to swap content into a torn-down overlay.
Future<void> _expireToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 7));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('matched but nothing written shows the neutral notice',
      (tester) async {
    await _show(tester,
        const RestoreResult(matched: 2, written: 0, unmatched: 1));
    expect(find.textContaining('Nothing to restore'), findsOneWidget);
    expect(find.textContaining('Successfully restored'), findsNothing);
    await _expireToast(tester);
  });

  testWidgets('no local match asks to import the book files first',
      (tester) async {
    await _show(tester,
        const RestoreResult(matched: 0, written: 0, unmatched: 5));
    expect(find.textContaining('None of the 5 books'), findsOneWidget);
    expect(find.textContaining('Import the book files first'), findsOneWidget);
    expect(find.textContaining('Successfully restored'), findsNothing);
    await _expireToast(tester);
  });

  testWidgets('written shows success without extra notes when all matched',
      (tester) async {
    await _show(tester,
        const RestoreResult(matched: 3, written: 3, unmatched: 0));
    expect(find.text('Successfully restored 3 books!'), findsOneWidget);
    expect(find.textContaining('on this device'), findsNothing);
    expect(find.textContaining('private shelf'), findsNothing);
    await _expireToast(tester);
  });

  testWidgets('written with unmatched and private moves adds both notes',
      (tester) async {
    await _show(
        tester,
        const RestoreResult(
            matched: 3, written: 2, unmatched: 4, movedToPrivate: 1));
    expect(find.text('Successfully restored 2 books!'), findsOneWidget);
    expect(find.textContaining('4 more books'),
        findsOneWidget);
    expect(find.textContaining('private shelf'), findsOneWidget);
    await _expireToast(tester);
  });

  testWidgets('null (picker cancelled) shows nothing', (tester) async {
    await _show(tester, null);
    expect(find.textContaining('restore'), findsNothing);
    expect(find.textContaining('device'), findsNothing);
  });
}
