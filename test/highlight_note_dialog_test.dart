/// The dialog must send '' (not null) for an empty field: null means "leave
/// the stored note unchanged" in updateHighlight, so null would make a note
/// impossible to clear.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/highlight.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/reader/widgets/highlight_note_dialog.dart';

Future<void> _pump(
  WidgetTester tester,
  void Function(String? note, String? colorCode) onSave,
) async {
  final highlight = Highlight(
    id: 'h1',
    bookId: 'b',
    paragraphIndex: 0,
    startOffset: 0,
    endOffset: 5,
    selectedText: 'Hello',
    colorCode: '#F2E58A',
    note: 'old note',
    createdAt: DateTime(2026),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: themePresets[ThemePreset.creamLight]!.themeData,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: HighlightNoteDialog(highlight: highlight, onSave: onSave),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('clearing the field saves an empty string, not null',
      (tester) async {
    final saved = <String?>[];
    await _pump(tester, (note, _) => saved.add(note));

    expect(find.text('old note'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, ['']);
  });

  testWidgets('whitespace-only text is trimmed to an empty string',
      (tester) async {
    final saved = <String?>[];
    await _pump(tester, (note, _) => saved.add(note));

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, ['']);
  });

  testWidgets('non-empty text is saved trimmed', (tester) async {
    final saved = <String?>[];
    await _pump(tester, (note, _) => saved.add(note));

    await tester.enterText(find.byType(TextField), '  new note ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, ['new note']);
  });
}
