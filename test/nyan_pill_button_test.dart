import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/nyan_spacing.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_pill_button.dart';

void main() {
  final preset = themePresets[ThemePreset.creamLight]!;

  Future<void> pumpPill(
    WidgetTester tester, {
    bool selected = false,
    String label = 'Medium',
    IconData? icon,
    VoidCallback? onPressed,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: preset.themeData,
        home: Scaffold(
          body: Center(
            child: NyanPillButton(
              label: label,
              selected: selected,
              icon: icon,
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  ShapeBorder pillShape(WidgetTester tester) {
    final material = tester.widget<Material>(find.byType(Material).last);
    return material.shape!;
  }

  // ── Shape ──────────────────────────────────────────────────────────────────
  group('NyanPillButton shape', () {
    testWidgets('uses StadiumBorder', (tester) async {
      await pumpPill(tester);
      expect(pillShape(tester), isA<StadiumBorder>());
    });

    testWidgets('unselected border is 1px divider', (tester) async {
      await pumpPill(tester, selected: false);
      final shape = pillShape(tester) as StadiumBorder;
      expect(shape.side.width, 1.0);
      expect(shape.side.color, preset.divider);
    });

    testWidgets('selected border is 1.5px primaryDeep', (tester) async {
      await pumpPill(tester, selected: true);
      final shape = pillShape(tester) as StadiumBorder;
      expect(shape.side.width, 1.5);
      expect(shape.side.color, preset.primaryDeep);
    });
  });

  // ── Background ─────────────────────────────────────────────────────────────
  group('NyanPillButton background', () {
    testWidgets('always uses nyan.surface (no fill on select)', (tester) async {
      await pumpPill(tester, selected: false);
      final unselectedMaterial =
          tester.widget<Material>(find.byType(Material).last);

      await pumpPill(tester, selected: true);
      final selectedMaterial =
          tester.widget<Material>(find.byType(Material).last);

      expect(unselectedMaterial.color, preset.surface);
      expect(selectedMaterial.color, preset.surface);
    });
  });

  // ── Label ──────────────────────────────────────────────────────────────────
  group('NyanPillButton label', () {
    testWidgets('renders label text', (tester) async {
      await pumpPill(tester, label: 'High');
      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('label color is textPrimary when unselected', (tester) async {
      await pumpPill(tester, label: 'High', selected: false);
      final text = tester.widget<Text>(find.text('High'));
      expect(text.style?.color, preset.textPrimary);
    });

    testWidgets('label color is primaryDeep when selected', (tester) async {
      await pumpPill(tester, label: 'High', selected: true);
      final text = tester.widget<Text>(find.text('High'));
      expect(text.style?.color, preset.primaryDeep);
    });

    testWidgets('label is 14pt, w500, height 1.0', (tester) async {
      await pumpPill(tester, label: 'Medium');
      final text = tester.widget<Text>(find.text('Medium'));
      expect(text.style?.fontSize, 14.0);
      expect(text.style?.fontWeight, FontWeight.w500);
      expect(text.style?.height, 1.0);
    });

    testWidgets('label uses NyanTypography.uiFontFamily', (tester) async {
      await pumpPill(tester, label: 'Medium');
      final text = tester.widget<Text>(find.text('Medium'));
      expect(text.style?.fontFamily, NyanTypography.uiFontFamily);
    });
  });

  // ── Padding ────────────────────────────────────────────────────────────────
  group('NyanPillButton padding', () {
    testWidgets('padding is 8 vertical × 16 horizontal', (tester) async {
      await pumpPill(tester);
      final paddings = tester.widgetList<Padding>(find.byType(Padding));
      final pillPadding = paddings.firstWhere(
        (p) =>
            p.padding ==
            const EdgeInsets.symmetric(
              horizontal: NyanSpacing.space16,
              vertical: NyanSpacing.space8,
            ),
        orElse: () => throw TestFailure('pill padding not found'),
      );
      expect(pillPadding.padding,
          const EdgeInsets.symmetric(
              horizontal: NyanSpacing.space16, vertical: NyanSpacing.space8));
    });
  });

  // ── Icon ───────────────────────────────────────────────────────────────────
  group('NyanPillButton icon', () {
    testWidgets('no icon by default', (tester) async {
      await pumpPill(tester);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('icon is rendered when provided', (tester) async {
      await pumpPill(tester, icon: Icons.book);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('icon colour matches label colour (textPrimary when unselected)',
        (tester) async {
      await pumpPill(tester, icon: Icons.book, selected: false);
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, preset.textPrimary);
    });
  });

  // ── Tap target ─────────────────────────────────────────────────────────────
  testWidgets('respects minimum 44pt tap target', (tester) async {
    await pumpPill(tester);
    final box = tester.getSize(find.byType(NyanPillButton));
    expect(
      box.height,
      greaterThanOrEqualTo(NyanSpacing.minTapTarget),
      reason: 'AGENTS.md §4.3: min 44pt tap target',
    );
  });

  // ── Tap ────────────────────────────────────────────────────────────────────
  testWidgets('onPressed fires when tapped', (tester) async {
    var tapped = 0;
    await pumpPill(tester, onPressed: () => tapped++);
    await tester.tap(find.byType(NyanPillButton));
    expect(tapped, 1);
  });
}
