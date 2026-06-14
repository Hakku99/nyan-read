import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_section_header.dart';

void main() {
  final preset = themePresets[ThemePreset.creamLight]!;

  Future<void> pumpHeader(
    WidgetTester tester, {
    bool withLeadingDot = false,
    EdgeInsetsGeometry? padding,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: preset.themeData,
        home: Scaffold(
          body: NyanSectionHeader(
            title: 'OVERVIEW',
            withLeadingDot: withLeadingDot,
            padding: padding,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // ── Text style ─────────────────────────────────────────────────────────────
  group('NyanSectionHeader text style', () {
    testWidgets('font size is NyanTypography.caption (11)', (tester) async {
      await pumpHeader(tester);
      final text = tester.widget<Text>(find.text('OVERVIEW'));
      expect(text.style?.fontSize, NyanTypography.caption);
    });

    testWidgets('font weight is w500', (tester) async {
      await pumpHeader(tester);
      final text = tester.widget<Text>(find.text('OVERVIEW'));
      expect(text.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('letter spacing is 0.22', (tester) async {
      await pumpHeader(tester);
      final text = tester.widget<Text>(find.text('OVERVIEW'));
      expect(text.style?.letterSpacing, 0.22);
    });

    testWidgets('line height is 1.0 (spec: line-height 1.0 eyebrow caption)',
        (tester) async {
      await pumpHeader(tester);
      final text = tester.widget<Text>(find.text('OVERVIEW'));
      expect(
        text.style?.height,
        1.0,
        reason: 'eyebrowStyle sets line-height: 1.0 per AGENTS.md §4.2.5',
      );
    });

    testWidgets('color is primaryDeep', (tester) async {
      await pumpHeader(tester);
      final text = tester.widget<Text>(find.text('OVERVIEW'));
      expect(text.style?.color, preset.primaryDeep);
    });
  });

  // ── Leading dot ────────────────────────────────────────────────────────────
  group('NyanSectionHeader leading dot', () {
    testWidgets('no dot by default', (tester) async {
      await pumpHeader(tester);
      expect(find.byType(Row), findsNothing);
    });

    testWidgets('dot appears when withLeadingDot is true', (tester) async {
      await pumpHeader(tester, withLeadingDot: true);
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('dot is 5×5 circle', (tester) async {
      await pumpHeader(tester, withLeadingDot: true);
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dot = containers.firstWhere(
        (c) => c.constraints?.maxWidth == 5 && c.constraints?.maxHeight == 5,
        orElse: () => throw TestFailure('5×5 dot Container not found'),
      );
      final d = dot.decoration as BoxDecoration;
      expect(d.shape, BoxShape.circle);
    });

    testWidgets('dot color is primary (full opacity)', (tester) async {
      await pumpHeader(tester, withLeadingDot: true);
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dot = containers.firstWhere(
        (c) => c.constraints?.maxWidth == 5 && c.constraints?.maxHeight == 5,
        orElse: () => throw TestFailure('5×5 dot Container not found'),
      );
      final d = dot.decoration as BoxDecoration;
      expect(d.color, preset.primary);
    });

    testWidgets('gap between dot and title is 6pt', (tester) async {
      await pumpHeader(tester, withLeadingDot: true);
      final sizedBox = tester.widget<SizedBox>(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 6),
      );
      expect(sizedBox.width, 6);
    });
  });

  // ── Default padding ────────────────────────────────────────────────────────
  group('NyanSectionHeader default padding', () {
    testWidgets('default padding matches spec (t16 l0 r0 b8)', (tester) async {
      await pumpHeader(tester);
      final padding = tester.widget<Padding>(find.byType(Padding).first);
      // Spec: `padding: "16px 0 8px"` = top:16, sides:0, bottom:8.
      // Horizontal padding is the parent ListView/Column's responsibility.
      expect(padding.padding, const EdgeInsets.fromLTRB(0, 16, 0, 8));
    });

    testWidgets('custom padding overrides default', (tester) async {
      const custom = EdgeInsets.all(8);
      await pumpHeader(tester, padding: custom);
      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(padding.padding, custom);
    });
  });
}
