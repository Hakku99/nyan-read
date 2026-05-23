import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/theme/nyan_shelf_ui.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_book_grid_card.dart';

void main() {
  // Minimal Book fixture — only the fields NyanBookGridCard reads.
  Book makeBook({String title = 'Test Book', double progress = 0.5}) {
    return Book(
      id: '1',
      title: title,
      author: 'Author',
      filePath: '/test.txt',
      format: 'txt',
      currentProgress: progress,
    );
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required Book book,
    bool isSelected = false,
    bool isSelectionMode = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themePresets[ThemePreset.creamLight]!.themeData,
        home: Scaffold(
          body: SizedBox(
            width: 113,
            height: 113,
            child: NyanBookGridCard(
              book: book,
              isSelected: isSelected,
              isSelectionMode: isSelectionMode,
              onTap: () {},
              onLongPress: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // ── Padding ──────────────────────────────────────────────────────────────
  // Target the content Padding by finding the one whose direct child is
  // the main Column (the icon-wash also has a Padding(space4) inside it,
  // so `.first` is ambiguous — `ancestor of Column` is unambiguous).
  Padding contentPadding(WidgetTester tester) {
    return tester.widget<Padding>(
      find.ancestor(
        of: find.byType(Column),
        matching: find.byType(Padding),
      ).first,
    );
  }

  group('NyanBookGridCard padding (spec: 12pt all sides)', () {
    testWidgets('unselected uses 12pt uniform padding', (tester) async {
      await pumpCard(tester, book: makeBook(), isSelected: false);
      expect(
        contentPadding(tester).padding,
        equals(EdgeInsets.all(NyanShelfUi.gridCardPadding)),
      );
    });

    testWidgets('selected uses 11pt padding (border-compensation)', (tester) async {
      await pumpCard(tester, book: makeBook(), isSelected: true, isSelectionMode: true);
      expect(
        contentPadding(tester).padding,
        equals(EdgeInsets.all(NyanShelfUi.gridCardSelectedPadding)),
      );
    });

    testWidgets('12pt > 8pt (regression: was space8)', (tester) async {
      await pumpCard(tester, book: makeBook());
      // Must NOT be the old 8pt value.
      expect(contentPadding(tester).padding, isNot(equals(const EdgeInsets.all(8))));
      // Must be the correct 12pt value.
      expect(contentPadding(tester).padding, equals(const EdgeInsets.all(12)));
    });
  });

  // ── Title min-height slot ────────────────────────────────────────────────
  group('NyanBookGridCard title slot (spec: 32pt 2-line reserve)', () {
    testWidgets('title wrapped in ConstrainedBox with 32pt minHeight',
        (tester) async {
      await pumpCard(tester, book: makeBook(title: 'Short'));
      final box = tester.widget<ConstrainedBox>(
        find.ancestor(
          of: find.text('Short'),
          matching: find.byType(ConstrainedBox),
        ).first,
      );
      expect(box.constraints.minHeight, NyanShelfUi.gridCardTitleMinHeight);
      expect(box.constraints.minHeight, 32.0);
    });

    testWidgets('long title still truncates at 2 lines', (tester) async {
      await pumpCard(
        tester,
        book: makeBook(
          title: 'A Very Long Book Title That Should Never Grow the Card',
        ),
      );
      final text = tester.widget<Text>(
        find.textContaining('A Very Long Book Title'),
      );
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });

  // ── Token constants sanity ───────────────────────────────────────────────
  group('NyanShelfUi token values (spec derivation)', () {
    test('gridCardPadding is 12', () => expect(NyanShelfUi.gridCardPadding, 12.0));
    test('gridCardSelectedPadding is 11 (= 12 − 1)', () => expect(NyanShelfUi.gridCardSelectedPadding, 11.0));
    test('gridCardTitleMinHeight is 32', () => expect(NyanShelfUi.gridCardTitleMinHeight, 32.0));
    test('gridCardBlockGap is 8', () => expect(NyanShelfUi.gridCardBlockGap, 8.0));
    test('progressBarHeight is 5', () => expect(NyanShelfUi.progressBarHeight, 5.0));
  });
}
