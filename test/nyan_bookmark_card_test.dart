import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/nyan_radius.dart';
import 'package:nyan_read/core/theme/nyan_spacing.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_bookmark_card.dart';

void main() {
  final preset = themePresets[ThemePreset.creamLight]!;

  Future<void> pumpCard(
    WidgetTester tester, {
    String label = 'Bookmark #3',
    String excerpt = 'The cat sat on the threshold for hours.',
    String? note,
    String? meta,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: preset.themeData,
        home: Scaffold(
          body: NyanBookmarkCard(
            label: label,
            excerpt: excerpt,
            note: note,
            meta: meta,
            onTap: onTap,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  BoxDecoration cardDecoration(WidgetTester tester) {
    final containers = tester.widgetList<Container>(find.byType(Container));
    for (final c in containers) {
      final d = c.decoration;
      if (d is BoxDecoration && d.borderRadius != null && d.border != null) {
        return d;
      }
    }
    throw TestFailure('card Container decoration not found');
  }

  // ── Card container ─────────────────────────────────────────────────────────
  group('NyanBookmarkCard container', () {
    testWidgets('uses NyanRadius.card border-radius', (tester) async {
      await pumpCard(tester);
      final d = cardDecoration(tester);
      expect(d.borderRadius, BorderRadius.circular(NyanRadius.card));
    });

    testWidgets('border width is 0.6', (tester) async {
      await pumpCard(tester);
      final d = cardDecoration(tester);
      final border = d.border as Border;
      expect(border.top.width, 0.6);
    });

    testWidgets('shadow color is nyanTheme.textPrimary (spec: nyan-text)',
        (tester) async {
      await pumpCard(tester);
      final d = cardDecoration(tester);
      expect(d.boxShadow, isNotEmpty);
      final shadow = d.boxShadow!.first;
      final expected = preset.textPrimary.withValues(alpha: 0.025);
      expect(
        shadow.color,
        expected,
        reason: 'spec: color-mix(nyan-text 2.5%) — was theme.shadowColor',
      );
    });

    testWidgets('shadow blur is 10, offset is (0, 3)', (tester) async {
      await pumpCard(tester);
      final d = cardDecoration(tester);
      final shadow = d.boxShadow!.first;
      expect(shadow.blurRadius, 10);
      expect(shadow.offset, const Offset(0, 3));
    });

    testWidgets('padding is NyanSpacing.space12', (tester) async {
      await pumpCard(tester);
      final paddings = tester.widgetList<Padding>(find.byType(Padding));
      final contentPadding = paddings.firstWhere(
        (p) => p.padding == const EdgeInsets.all(NyanSpacing.space12),
        orElse: () =>
            throw TestFailure('Padding(all:12) not found'),
      );
      expect(contentPadding.padding, const EdgeInsets.all(NyanSpacing.space12));
    });
  });

  // ── Meta line label ────────────────────────────────────────────────────────
  group('NyanBookmarkCard meta label', () {
    testWidgets('label text is rendered', (tester) async {
      await pumpCard(tester, label: 'Bookmark #3');
      expect(find.text('Bookmark #3'), findsOneWidget);
    });

    testWidgets('label font size is 11', (tester) async {
      await pumpCard(tester, label: 'Bookmark #3');
      final text = tester.widget<Text>(find.text('Bookmark #3'));
      expect(text.style?.fontSize, 11.0);
    });

    testWidgets('label font weight is w500', (tester) async {
      await pumpCard(tester, label: 'Bookmark #3');
      final text = tester.widget<Text>(find.text('Bookmark #3'));
      expect(text.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('label line height is 1.1 (spec: 11px/1.1)', (tester) async {
      await pumpCard(tester, label: 'Bookmark #3');
      final text = tester.widget<Text>(find.text('Bookmark #3'));
      expect(
        text.style?.height,
        1.1,
        reason: 'spec: font 500 11px/1.1 — was 1.05',
      );
    });
  });

  // ── Excerpt ────────────────────────────────────────────────────────────────
  group('NyanBookmarkCard excerpt', () {
    testWidgets('excerpt text is rendered', (tester) async {
      await pumpCard(tester, excerpt: 'Hello world.');
      expect(find.text('Hello world.'), findsOneWidget);
    });

    testWidgets('excerpt font size is 14', (tester) async {
      await pumpCard(tester, excerpt: 'Hello world.');
      final text = tester.widget<Text>(find.text('Hello world.'));
      expect(text.style?.fontSize, 14.0);
    });

    testWidgets('excerpt line height is 1.12', (tester) async {
      await pumpCard(tester, excerpt: 'Hello world.');
      final text = tester.widget<Text>(find.text('Hello world.'));
      expect(text.style?.height, 1.12);
    });
  });

  // ── Note tag ───────────────────────────────────────────────────────────────
  group('NyanBookmarkCard note tag', () {
    testWidgets('note tag not shown when note is null', (tester) async {
      await pumpCard(tester);
      expect(find.text('Note'), findsNothing);
    });

    testWidgets('note tag shown when note is provided', (tester) async {
      await pumpCard(tester, note: 'interesting passage');
      expect(find.text('Note'), findsOneWidget);
    });
  });

  // ── Meta row ───────────────────────────────────────────────────────────────
  group('NyanBookmarkCard meta row', () {
    testWidgets('meta text not shown when null', (tester) async {
      await pumpCard(tester);
      expect(find.text('Chapter 4 · Page 28'), findsNothing);
    });

    testWidgets('meta text shown when provided', (tester) async {
      await pumpCard(tester, meta: 'Chapter 4 · Page 28');
      expect(find.text('Chapter 4 · Page 28'), findsOneWidget);
    });

    testWidgets('meta font size is 11 and line height is 1.05', (tester) async {
      await pumpCard(tester, meta: 'Chapter 4 · Page 28');
      final text = tester.widget<Text>(find.text('Chapter 4 · Page 28'));
      expect(text.style?.fontSize, 11.0);
      expect(text.style?.height, 1.05);
    });
  });

  // ── Tappable ───────────────────────────────────────────────────────────────
  group('NyanBookmarkCard tappable', () {
    testWidgets('wraps in InkWell when onTap provided', (tester) async {
      await pumpCard(tester, onTap: () {});
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('no InkWell when onTap is null', (tester) async {
      await pumpCard(tester);
      expect(find.byType(InkWell), findsNothing);
    });
  });
}
