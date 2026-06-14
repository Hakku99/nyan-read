import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/theme/nyan_shelf_ui.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_book_grid_card.dart';

/// Tracks the bundle3.jsx BookCard rewrite: portrait cover (120:156) with a
/// format badge overlay, a 3pt progress bar, then title + author below — no
/// outer padded card box.
void main() {
  Book makeBook({
    String title = 'Test Book',
    String author = 'Author',
    String format = 'txt',
    double progress = 0.5,
  }) {
    return Book(
      id: '1',
      title: title,
      author: author,
      filePath: '/test.txt',
      format: format,
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
          body: Center(
            child: SizedBox(
              width: 113,
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
      ),
    );
    await tester.pump();
  }

  // ── Cover ──────────────────────────────────────────────────────────────────
  group('NyanBookGridCard cover', () {
    testWidgets('cover uses the 120:156 portrait ratio', (tester) async {
      await pumpCard(tester, book: makeBook());
      final aspect = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspect.aspectRatio, NyanShelfUi.gridCoverAspectRatio);
    });
  });

  // ── Format badge ───────────────────────────────────────────────────────────
  group('NyanBookGridCard format badge', () {
    testWidgets('renders the uppercased format', (tester) async {
      await pumpCard(tester, book: makeBook(format: 'epub'));
      expect(find.text('EPUB'), findsOneWidget);
    });

    testWidgets('badge hidden in selection mode', (tester) async {
      await pumpCard(
        tester,
        book: makeBook(format: 'epub'),
        isSelectionMode: true,
      );
      expect(find.text('EPUB'), findsNothing);
    });
  });

  // ── Title + author ─────────────────────────────────────────────────────────
  group('NyanBookGridCard text', () {
    testWidgets('renders title and author', (tester) async {
      await pumpCard(tester, book: makeBook(title: 'Genji', author: 'Murasaki'));
      expect(find.text('Genji'), findsOneWidget);
      expect(find.text('Murasaki'), findsOneWidget);
    });

    testWidgets('author hidden when unknown', (tester) async {
      await pumpCard(tester, book: makeBook(author: 'unknown'));
      expect(find.text('unknown'), findsNothing);
    });

    testWidgets('title reserves 32pt 2-line slot', (tester) async {
      await pumpCard(tester, book: makeBook(title: 'Short'));
      final box = tester.widget<ConstrainedBox>(
        find
            .ancestor(
              of: find.text('Short'),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(box.constraints.minHeight, NyanShelfUi.gridCardTitleMinHeight);
      expect(box.constraints.minHeight, 32.0);
    });

    testWidgets('long title truncates at 2 lines', (tester) async {
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

  // ── Progress bar ───────────────────────────────────────────────────────────
  group('NyanBookGridCard progress bar', () {
    testWidgets('always shown, 3pt tall, value matches progress',
        (tester) async {
      await pumpCard(tester, book: makeBook(progress: 0.5));
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.minHeight, NyanShelfUi.progressBarHeight);
      expect(bar.minHeight, 3.0);
      expect(bar.value, closeTo(0.5, 0.001));
    });

    testWidgets('shown even at 0% (empty track)', (tester) async {
      await pumpCard(tester, book: makeBook(progress: 0.0));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  // ── Token constants ────────────────────────────────────────────────────────
  group('NyanShelfUi token values', () {
    test('progressBarHeight is 3', () {
      expect(NyanShelfUi.progressBarHeight, 3.0);
    });
    test('gridCoverAspectRatio is 120/156', () {
      expect(NyanShelfUi.gridCoverAspectRatio, 120.0 / 156.0);
    });
    test('gridCardTitleMinHeight is 32', () {
      expect(NyanShelfUi.gridCardTitleMinHeight, 32.0);
    });
    test('grid gutters are 12 / 16', () {
      expect(NyanShelfUi.gridCrossAxisSpacing, 12.0);
      expect(NyanShelfUi.gridMainAxisSpacing, 16.0);
    });
  });
}
