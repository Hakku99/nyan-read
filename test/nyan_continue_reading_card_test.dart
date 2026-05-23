import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/theme/nyan_shelf_ui.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_continue_reading_card.dart';

Book _makeBook({
  String title = 'The Tale of Genji',
  String author = 'Murasaki Shikibu',
  double progress = 0.42,
}) =>
    Book(
      id: '1',
      title: title,
      author: author,
      format: 'epub',
      currentProgress: progress,
    );

void main() {
  final preset = themePresets[ThemePreset.creamLight]!;

  Future<void> pumpCard(
    WidgetTester tester,
    Book book, {
    bool compact = false,
    bool collapsed = false,
    VoidCallback? onToggleCollapse,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: preset.themeData,
        home: Scaffold(
          body: NyanContinueReadingCard(
            book: book,
            compact: compact,
            collapsed: collapsed,
            onToggleCollapse: onToggleCollapse,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // ── Title ──────────────────────────────────────────────────────────────────
  group('NyanContinueReadingCard title', () {
    testWidgets('renders book title', (tester) async {
      await pumpCard(tester, _makeBook());
      expect(find.text('The Tale of Genji'), findsOneWidget);
    });

    testWidgets('title font size is 16 (standard)', (tester) async {
      await pumpCard(tester, _makeBook());
      final text = tester.widget<Text>(find.text('The Tale of Genji'));
      expect(text.style?.fontSize, 16.0);
    });

    testWidgets('title font weight is w600', (tester) async {
      await pumpCard(tester, _makeBook());
      final text = tester.widget<Text>(find.text('The Tale of Genji'));
      expect(text.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('title line height is 1.25', (tester) async {
      await pumpCard(tester, _makeBook());
      final text = tester.widget<Text>(find.text('The Tale of Genji'));
      expect(text.style?.height, 1.25);
    });

    testWidgets('title letter spacing is -0.2', (tester) async {
      await pumpCard(tester, _makeBook());
      final text = tester.widget<Text>(find.text('The Tale of Genji'));
      expect(text.style?.letterSpacing, -0.2);
    });
  });

  // ── Author ─────────────────────────────────────────────────────────────────
  group('NyanContinueReadingCard author', () {
    testWidgets('renders author', (tester) async {
      await pumpCard(tester, _makeBook());
      expect(find.text('Murasaki Shikibu'), findsOneWidget);
    });

    testWidgets('author color is nyanTheme.textPrimary @ 62% (spec: nyan-text 62%)',
        (tester) async {
      await pumpCard(tester, _makeBook());
      final text = tester.widget<Text>(find.text('Murasaki Shikibu'));
      final expected = preset.textPrimary.withValues(alpha: 0.62);
      expect(
        text.style?.color,
        expected,
        reason: 'was theme.colorScheme.onSurface — should be nyanTheme.textPrimary',
      );
    });

    testWidgets('author line height is 1.2', (tester) async {
      await pumpCard(tester, _makeBook());
      final text = tester.widget<Text>(find.text('Murasaki Shikibu'));
      expect(text.style?.height, 1.2);
    });

    testWidgets('author hidden when author is empty', (tester) async {
      await pumpCard(tester, _makeBook(author: ''));
      expect(find.text(''), findsNothing);
    });

    testWidgets('author hidden when author is "unknown"', (tester) async {
      await pumpCard(tester, _makeBook(author: 'unknown'));
      expect(find.text('unknown'), findsNothing);
    });
  });

  // ── Progress label ─────────────────────────────────────────────────────────
  group('NyanContinueReadingCard progress label', () {
    testWidgets('renders default progress label as percentage', (tester) async {
      await pumpCard(tester, _makeBook(progress: 0.42));
      expect(find.text('42%'), findsOneWidget);
    });

    testWidgets('progress label font size is 12', (tester) async {
      await pumpCard(tester, _makeBook(progress: 0.42));
      final text = tester.widget<Text>(find.text('42%'));
      expect(text.style?.fontSize, 12.0);
    });

    testWidgets('progress label color is nyanTheme.textPrimary @ 62%',
        (tester) async {
      await pumpCard(tester, _makeBook(progress: 0.42));
      final text = tester.widget<Text>(find.text('42%'));
      final expected = preset.textPrimary.withValues(alpha: 0.62);
      expect(
        text.style?.color,
        expected,
        reason: 'was theme.colorScheme.onSurface — should be nyanTheme.textPrimary',
      );
    });

    testWidgets('progress label letter spacing is 0.1', (tester) async {
      await pumpCard(tester, _makeBook(progress: 0.42));
      final text = tester.widget<Text>(find.text('42%'));
      expect(text.style?.letterSpacing, 0.1);
    });
  });

  // ── Progress bar ───────────────────────────────────────────────────────────
  group('NyanContinueReadingCard progress bar', () {
    testWidgets('progress bar height is NyanShelfUi.progressBarHeight (5)',
        (tester) async {
      await pumpCard(tester, _makeBook(progress: 0.42));
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.minHeight, NyanShelfUi.progressBarHeight);
    });

    testWidgets('progress bar value matches book progress', (tester) async {
      await pumpCard(tester, _makeBook(progress: 0.42));
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.42, 0.001));
    });

    testWidgets('progress bar fill color is nyanTheme.primary (spec: nyan-primary)',
        (tester) async {
      await pumpCard(tester, _makeBook());
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      final fillColor =
          (bar.valueColor as AlwaysStoppedAnimation<Color>).value;
      expect(
        fillColor,
        preset.primary,
        reason: 'was theme.colorScheme.primary — should be nyanTheme.primary',
      );
    });

    testWidgets('progress bar background is nyanTheme.primary @ 20%',
        (tester) async {
      await pumpCard(tester, _makeBook());
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      final expected = preset.primary.withValues(alpha: 0.2);
      expect(
        bar.backgroundColor,
        expected,
        reason: 'was theme.colorScheme.primary — should be nyanTheme.primary',
      );
    });
  });

  // ── Collapse button ────────────────────────────────────────────────────────
  group('NyanContinueReadingCard collapse button', () {
    testWidgets('collapse button not shown without onToggleCollapse',
        (tester) async {
      await pumpCard(tester, _makeBook());
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('collapse button shown when onToggleCollapse provided',
        (tester) async {
      await pumpCard(tester, _makeBook(), onToggleCollapse: () {});
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('collapse button foreground is nyanTheme.textPrimary @ 55%',
        (tester) async {
      await pumpCard(tester, _makeBook(), onToggleCollapse: () {});
      final btn = tester.widget<IconButton>(find.byType(IconButton));
      final style = btn.style!;
      final fg = style.foregroundColor?.resolve({});
      final expected = preset.textPrimary.withValues(alpha: 0.55);
      expect(
        fg,
        expected,
        reason: 'was theme.colorScheme.onSurface — should be nyanTheme.textPrimary',
      );
    });
  });

  // ── Collapsed layout ───────────────────────────────────────────────────────
  group('NyanContinueReadingCard collapsed layout', () {
    testWidgets('renders title and progress label in collapsed mode',
        (tester) async {
      await pumpCard(tester, _makeBook(progress: 0.42), collapsed: true);
      expect(find.text('The Tale of Genji'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
    });

    testWidgets('collapsed progress label color is nyanTheme.textPrimary @ 62%',
        (tester) async {
      await pumpCard(tester, _makeBook(progress: 0.42), collapsed: true);
      final text = tester.widget<Text>(find.text('42%'));
      final expected = preset.textPrimary.withValues(alpha: 0.62);
      expect(text.style?.color, expected);
    });

    testWidgets('no LinearProgressIndicator in collapsed mode', (tester) async {
      await pumpCard(tester, _makeBook(), collapsed: true);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
