import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/nyan_spacing.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_page_header.dart';

void main() {
  final preset = themePresets[ThemePreset.creamLight]!;

  Future<void> pumpHeader(
    WidgetTester tester, {
    String title = 'My Library',
    String? subtitle,
    Widget? leading,
    List<Widget>? actions,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: preset.themeData,
        home: Scaffold(
          body: NyanPageHeader(
            title: title,
            subtitle: subtitle,
            leading: leading,
            actions: actions,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // ── Title ──────────────────────────────────────────────────────────────────
  group('NyanPageHeader title', () {
    testWidgets('renders title text', (tester) async {
      await pumpHeader(tester);
      expect(find.text('My Library'), findsOneWidget);
    });

    testWidgets('title font size is NyanTypography.title (24)', (tester) async {
      await pumpHeader(tester);
      final text = tester.widget<Text>(find.text('My Library'));
      expect(text.style?.fontSize, NyanTypography.title);
    });

    testWidgets('title font weight is w600', (tester) async {
      await pumpHeader(tester);
      final text = tester.widget<Text>(find.text('My Library'));
      expect(text.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('title letter spacing is -0.15', (tester) async {
      await pumpHeader(tester);
      final text = tester.widget<Text>(find.text('My Library'));
      expect(text.style?.letterSpacing, -0.15);
    });

    testWidgets('title color is nyanTheme.textPrimary (explicit token)',
        (tester) async {
      await pumpHeader(tester);
      final text = tester.widget<Text>(find.text('My Library'));
      expect(
        text.style?.color,
        preset.textPrimary,
        reason: 'title color must be nyanTheme.textPrimary per AGENTS.md §2.2.3',
      );
    });
  });

  // ── Subtitle ───────────────────────────────────────────────────────────────
  group('NyanPageHeader subtitle', () {
    testWidgets('subtitle not rendered when null', (tester) async {
      await pumpHeader(tester);
      expect(find.text('42 books'), findsNothing);
    });

    testWidgets('subtitle renders when provided', (tester) async {
      await pumpHeader(tester, subtitle: '42 books');
      expect(find.text('42 books'), findsOneWidget);
    });

    testWidgets('subtitle font size is NyanTypography.meta (13)', (tester) async {
      await pumpHeader(tester, subtitle: '42 books');
      final text = tester.widget<Text>(find.text('42 books'));
      expect(text.style?.fontSize, NyanTypography.meta);
    });

    testWidgets('subtitle color is nyanTheme.textMuted', (tester) async {
      await pumpHeader(tester, subtitle: '42 books');
      final text = tester.widget<Text>(find.text('42 books'));
      expect(text.style?.color, preset.textMuted);
    });

    testWidgets('subtitle line height is 1.35', (tester) async {
      await pumpHeader(tester, subtitle: '42 books');
      final text = tester.widget<Text>(find.text('42 books'));
      expect(text.style?.height, 1.35);
    });
  });

  // ── Layout ─────────────────────────────────────────────────────────────────
  group('NyanPageHeader layout', () {
    testWidgets('leading widget is rendered when provided', (tester) async {
      await pumpHeader(
        tester,
        leading: const Icon(Icons.book, key: Key('leading')),
      );
      expect(find.byKey(const Key('leading')), findsOneWidget);
    });

    testWidgets('actions are rendered when provided', (tester) async {
      await pumpHeader(
        tester,
        actions: [const Icon(Icons.search, key: Key('action'))],
      );
      expect(find.byKey(const Key('action')), findsOneWidget);
    });

    testWidgets('default padding is l16 t16 r16 b12', (tester) async {
      await pumpHeader(tester);
      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(
        padding.padding,
        const EdgeInsets.fromLTRB(
          NyanSpacing.space16,
          NyanSpacing.space16,
          NyanSpacing.space16,
          NyanSpacing.space12,
        ),
      );
    });
  });
}
