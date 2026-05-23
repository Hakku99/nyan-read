import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/nyan_spacing.dart';
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
    testWidgets('font size is NyanTypography.meta (13)', (tester) async {
      await pumpHeader(tester);
      final text = tester.widget<Text>(find.text('OVERVIEW'));
      expect(text.style?.fontSize, NyanTypography.meta);
    });

    testWidgets('font weight is w600', (tester) async {
      await pumpHeader(tester);
      final text = tester.widget<Text>(find.text('OVERVIEW'));
      expect(text.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('letter spacing is 0.22', (tester) async {
      await pumpHeader(tester);
      final text = tester.widget<Text>(find.text('OVERVIEW'));
      expect(text.style?.letterSpacing, 0.22);
    });

    testWidgets('line height is 1.3 (spec: line-height 1.3)', (tester) async {
      await pumpHeader(tester);
      final text = tester.widget<Text>(find.text('OVERVIEW'));
      expect(
        text.style?.height,
        1.3,
        reason: 'spec sets line-height: 1.3 on .nyan-section-header',
      );
    });

    testWidgets('color is primary @ 90%', (tester) async {
      await pumpHeader(tester);
      final text = tester.widget<Text>(find.text('OVERVIEW'));
      final expected = preset.primary.withValues(alpha: 0.9);
      expect(text.style?.color, expected);
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

    testWidgets('dot is 4×4 circle', (tester) async {
      await pumpHeader(tester, withLeadingDot: true);
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dot = containers.firstWhere(
        (c) => c.constraints?.maxWidth == 4 && c.constraints?.maxHeight == 4,
        orElse: () => throw TestFailure('4×4 dot Container not found'),
      );
      final d = dot.decoration as BoxDecoration;
      expect(d.shape, BoxShape.circle);
    });

    testWidgets('dot color is primary @ 63% (spec: primary 63% transparent)',
        (tester) async {
      await pumpHeader(tester, withLeadingDot: true);
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dot = containers.firstWhere(
        (c) => c.constraints?.maxWidth == 4 && c.constraints?.maxHeight == 4,
        orElse: () => throw TestFailure('4×4 dot Container not found'),
      );
      final d = dot.decoration as BoxDecoration;
      final expected = preset.primary.withValues(alpha: 0.63);
      expect(
        d.color,
        expected,
        reason: 'spec: color-mix(primary 63%, transparent) — was 0.7, fixed to 0.63',
      );
    });

    testWidgets('gap between dot and title is NyanSpacing.space8', (tester) async {
      await pumpHeader(tester, withLeadingDot: true);
      final sizedBox = tester.widget<SizedBox>(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == NyanSpacing.space8,
        ),
      );
      expect(sizedBox.width, NyanSpacing.space8);
    });
  });

  // ── Default padding ────────────────────────────────────────────────────────
  group('NyanSectionHeader default padding', () {
    testWidgets('default padding matches spec (l16 t0 r16 b12)', (tester) async {
      await pumpHeader(tester);
      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(
        padding.padding,
        const EdgeInsets.fromLTRB(
          NyanSpacing.space16,
          0,
          NyanSpacing.space16,
          NyanSpacing.space12,
        ),
      );
    });

    testWidgets('custom padding overrides default', (tester) async {
      const custom = EdgeInsets.all(NyanSpacing.space8);
      await pumpHeader(tester, padding: custom);
      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(padding.padding, custom);
    });
  });
}
