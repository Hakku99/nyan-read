import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_continue_reading_card.dart';
import 'package:nyan_read/core/ui/components/nyan_primary_button.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';

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

/// These assertions track the bundle3.jsx ContinueCard rewrite:
/// always-on header (eyebrow + caret), expanded body (cover + title/author +
/// inline progress + full-width CTA), collapsed header (title + pct%).
void main() {
  final preset = themePresets[ThemePreset.creamLight]!;

  Future<void> pumpCard(
    WidgetTester tester,
    Book book, {
    bool collapsed = false,
    VoidCallback? onToggleCollapse,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: preset.themeData,
        home: Scaffold(
          body: NyanContinueReadingCard(
            book: book,
            collapsed: collapsed,
            // Distinct from the "Continue Reading" eyebrow so find.text stays
            // unambiguous between the eyebrow and the CTA label.
            buttonLabel: 'Open Now',
            onToggleCollapse: onToggleCollapse,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // ── Header eyebrow ─────────────────────────────────────────────────────────
  group('NyanContinueReadingCard header', () {
    testWidgets('renders the "Continue Reading" eyebrow', (tester) async {
      await pumpCard(tester, _makeBook());
      expect(find.text('Continue Reading'), findsOneWidget);
    });

    testWidgets('eyebrow is 11px / w500 / textMuted', (tester) async {
      await pumpCard(tester, _makeBook());
      final text = tester.widget<Text>(find.text('Continue Reading'));
      expect(text.style?.fontSize, 11.0);
      expect(text.style?.fontWeight, FontWeight.w500);
      expect(text.style?.color, preset.textMuted);
    });

    testWidgets('caret icon is always present', (tester) async {
      await pumpCard(tester, _makeBook(), onToggleCollapse: () {});
      expect(find.byIcon(NyanIcons.chevronDown), findsOneWidget);
    });
  });

  // ── Title (expanded) ───────────────────────────────────────────────────────
  group('NyanContinueReadingCard expanded title', () {
    testWidgets('renders book title', (tester) async {
      await pumpCard(tester, _makeBook());
      expect(find.text('The Tale of Genji'), findsOneWidget);
    });

    testWidgets('title is 14px / w600 / height 1.3 / letterSpacing -0.1',
        (tester) async {
      await pumpCard(tester, _makeBook());
      final text = tester.widget<Text>(find.text('The Tale of Genji'));
      expect(text.style?.fontSize, 14.0);
      expect(text.style?.fontWeight, FontWeight.w600);
      expect(text.style?.height, 1.3);
      expect(text.style?.letterSpacing, -0.1);
      expect(text.style?.color, preset.textPrimary);
    });
  });

  // ── Author ─────────────────────────────────────────────────────────────────
  group('NyanContinueReadingCard author', () {
    testWidgets('renders author', (tester) async {
      await pumpCard(tester, _makeBook());
      expect(find.text('Murasaki Shikibu'), findsOneWidget);
    });

    testWidgets('author is 12px / height 1.3 / textMuted', (tester) async {
      await pumpCard(tester, _makeBook());
      final text = tester.widget<Text>(find.text('Murasaki Shikibu'));
      expect(text.style?.fontSize, 12.0);
      expect(text.style?.height, 1.3);
      expect(text.style?.color, preset.textMuted);
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

  // ── Progress (expanded) ────────────────────────────────────────────────────
  group('NyanContinueReadingCard progress', () {
    testWidgets('renders progress percentage', (tester) async {
      await pumpCard(tester, _makeBook(progress: 0.42));
      expect(find.text('42%'), findsOneWidget);
    });

    testWidgets('percentage is 11px / w600 / primaryDeep', (tester) async {
      await pumpCard(tester, _makeBook(progress: 0.42));
      final text = tester.widget<Text>(find.text('42%'));
      expect(text.style?.fontSize, 11.0);
      expect(text.style?.fontWeight, FontWeight.w600);
      expect(text.style?.color, preset.primaryDeep);
    });

    testWidgets('progress bar is 3pt tall', (tester) async {
      await pumpCard(tester, _makeBook(progress: 0.42));
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.minHeight, 3.0);
    });

    testWidgets('progress bar value matches book progress', (tester) async {
      await pumpCard(tester, _makeBook(progress: 0.42));
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.42, 0.001));
    });

    testWidgets('progress bar fill is nyanTheme.primary', (tester) async {
      await pumpCard(tester, _makeBook());
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      final fillColor =
          (bar.valueColor as AlwaysStoppedAnimation<Color>).value;
      expect(fillColor, preset.primary);
    });

    testWidgets('progress track is primary @ 16% over surfaceMuted',
        (tester) async {
      await pumpCard(tester, _makeBook());
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      final expected = Color.alphaBlend(
        preset.primary.withValues(alpha: 0.16),
        preset.surfaceMuted,
      );
      expect(bar.backgroundColor, expected);
    });
  });

  // ── CTA ────────────────────────────────────────────────────────────────────
  group('NyanContinueReadingCard CTA', () {
    testWidgets('full-width CTA present when expanded', (tester) async {
      await pumpCard(tester, _makeBook());
      expect(find.byType(NyanPrimaryButton), findsOneWidget);
      expect(find.text('Open Now'), findsOneWidget);
    });

    testWidgets('no CTA when collapsed', (tester) async {
      await pumpCard(tester, _makeBook(), collapsed: true);
      expect(find.byType(NyanPrimaryButton), findsNothing);
    });
  });

  // ── Collapsed layout ───────────────────────────────────────────────────────
  group('NyanContinueReadingCard collapsed layout', () {
    testWidgets('renders title and percentage in collapsed header',
        (tester) async {
      await pumpCard(tester, _makeBook(progress: 0.42), collapsed: true);
      expect(find.text('The Tale of Genji'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
    });

    testWidgets('collapsed title is 13px / w600 / textPrimary', (tester) async {
      await pumpCard(tester, _makeBook(), collapsed: true);
      final text = tester.widget<Text>(find.text('The Tale of Genji'));
      expect(text.style?.fontSize, 13.0);
      expect(text.style?.fontWeight, FontWeight.w600);
      expect(text.style?.color, preset.textPrimary);
    });

    testWidgets('collapsed percentage color is primaryDeep', (tester) async {
      await pumpCard(tester, _makeBook(progress: 0.42), collapsed: true);
      final text = tester.widget<Text>(find.text('42%'));
      expect(text.style?.color, preset.primaryDeep);
    });

    testWidgets('no progress bar in collapsed mode', (tester) async {
      await pumpCard(tester, _makeBook(), collapsed: true);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
