import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/nyan_radius.dart';
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
    await tester.pumpAndSettle();
  }

  BoxDecoration pillDecoration(WidgetTester tester) {
    final container =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
    return container.decoration as BoxDecoration;
  }

  // ── Shape ──────────────────────────────────────────────────────────────────
  group('NyanPillButton shape', () {
    testWidgets('uses squared r-chip 12pt corners (not a stadium)', (tester) async {
      await pumpPill(tester);
      final dec = pillDecoration(tester);
      expect(
        dec.borderRadius,
        const BorderRadius.all(Radius.circular(NyanRadius.chip)),
        reason: 'design-system: chip=12 squared, not StadiumBorder',
      );
    });

    testWidgets('unselected border is transparent 1.5px', (tester) async {
      await pumpPill(tester, selected: false);
      final dec = pillDecoration(tester);
      final border = dec.border! as Border;
      expect(border.top.width, 1.5);
      expect(border.top.color, Colors.transparent);
    });

    testWidgets('selected border is 1.5px primaryDeep', (tester) async {
      await pumpPill(tester, selected: true);
      final dec = pillDecoration(tester);
      final border = dec.border! as Border;
      expect(border.top.width, 1.5);
      expect(border.top.color, preset.primaryDeep);
    });
  });

  // ── Background ─────────────────────────────────────────────────────────────
  group('NyanPillButton background', () {
    testWidgets('unselected fill is surfaceMuted', (tester) async {
      await pumpPill(tester, selected: false);
      expect(pillDecoration(tester).color, preset.surfaceMuted);
    });

    testWidgets('selected fill is transparent (outline-only)', (tester) async {
      await pumpPill(tester, selected: true);
      expect(pillDecoration(tester).color, Colors.transparent);
    });
  });

  // ── Label ──────────────────────────────────────────────────────────────────
  group('NyanPillButton label', () {
    testWidgets('renders label text', (tester) async {
      await pumpPill(tester, label: 'High');
      expect(find.text('High'), findsOneWidget);
    });

    testWidgets('label color is textSecondary when unselected', (tester) async {
      await pumpPill(tester, label: 'High', selected: false);
      final text = tester.widget<Text>(find.text('High'));
      expect(text.style?.color, preset.textSecondary);
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
      expect(
        pillPadding.padding,
        const EdgeInsets.symmetric(
          horizontal: NyanSpacing.space16,
          vertical: NyanSpacing.space8,
        ),
      );
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

    testWidgets('icon colour matches label colour (textSecondary when unselected)',
        (tester) async {
      await pumpPill(tester, icon: Icons.book, selected: false);
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, preset.textSecondary);
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
