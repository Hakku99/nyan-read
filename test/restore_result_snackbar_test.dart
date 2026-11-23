/// `showRestoreResult`: cancelled picker is silent, 0 is a skipped notice,
/// a positive count is the success message.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/settings/settings_page.dart';

Future<void> _show(WidgetTester tester, int count) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: themePresets[ThemePreset.creamLight]!.themeData,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRestoreResult(context, count),
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
  testWidgets('0 shows the nothing-to-restore notice', (tester) async {
    await _show(tester, 0);
    expect(find.textContaining('Nothing to restore'), findsOneWidget);
    expect(find.textContaining('Successfully restored'), findsNothing);
    await _expireToast(tester);
  });

  testWidgets('positive count shows the success message', (tester) async {
    await _show(tester, 3);
    expect(find.text('Successfully restored 3 books!'), findsOneWidget);
    await _expireToast(tester);
  });

  testWidgets('-1 (picker cancelled) shows nothing', (tester) async {
    await _show(tester, -1);
    expect(find.textContaining('restore'), findsNothing);
  });
}
