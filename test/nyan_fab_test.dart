import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/nyan_radius.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_fab.dart';

void main() {
  final preset = themePresets[ThemePreset.creamLight]!;

  Future<void> pumpFab(
    WidgetTester tester, {
    VoidCallback? onPressed,
    IconData icon = Icons.add,
    String? tooltip,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: preset.themeData,
        home: Scaffold(
          body: NyanFAB(
            onPressed: onPressed,
            icon: icon,
            tooltip: tooltip,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  FloatingActionButton readFab(WidgetTester tester) =>
      tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));

  // ── Colors ─────────────────────────────────────────────────────────────────
  group('NyanFAB colors', () {
    testWidgets('background is nyan.fabBackground', (tester) async {
      await pumpFab(tester);
      expect(readFab(tester).backgroundColor, preset.fabBackground);
    });

    testWidgets('foreground is nyan.fabForeground', (tester) async {
      await pumpFab(tester);
      expect(readFab(tester).foregroundColor, preset.fabForeground);
    });
  });

  // ── Shape ──────────────────────────────────────────────────────────────────
  group('NyanFAB shape', () {
    testWidgets('uses NyanRadius.input (16pt) corner radius', (tester) async {
      await pumpFab(tester);
      final shape = readFab(tester).shape as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        BorderRadius.circular(NyanRadius.input),
        reason: 'AGENTS.md §4.2.2: FAB uses NyanRadius.input (16pt)',
      );
    });
  });

  // ── Elevation ──────────────────────────────────────────────────────────────
  group('NyanFAB elevation', () {
    testWidgets('Material elevation is fully suppressed (uses NyanShadows)',
        (tester) async {
      await pumpFab(tester);
      final fab = readFab(tester);
      expect(fab.elevation, 0);
      expect(fab.highlightElevation, 0);
      expect(fab.hoverElevation, 0);
      expect(fab.focusElevation, 0);
      expect(fab.disabledElevation, 0);
    });

    testWidgets('outer DecoratedBox carries NyanShadows.subtle', (tester) async {
      await pumpFab(tester);
      final decoratedBoxes =
          tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
      // Find the DecoratedBox with our shadow signature.
      final ours = decoratedBoxes.firstWhere(
        (b) {
          final d = b.decoration;
          return d is BoxDecoration &&
              d.boxShadow != null &&
              d.boxShadow!.isNotEmpty &&
              d.boxShadow!.first.blurRadius == 8;
        },
        orElse: () => throw TestFailure(
            'NyanShadows.subtle (blur 8) DecoratedBox not found'),
      );
      final d = ours.decoration as BoxDecoration;
      final shadow = d.boxShadow!.first;
      // NyanShadows.subtle: blur 8, alpha 0.05, offset (0,2).
      expect(shadow.blurRadius, 8);
      expect(shadow.offset, const Offset(0, 2));
      expect(shadow.color, preset.textPrimary.withValues(alpha: 0.05));
    });
  });

  // ── Icon ───────────────────────────────────────────────────────────────────
  testWidgets('renders the icon passed in', (tester) async {
    await pumpFab(tester, icon: Icons.add);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  // ── Tooltip ────────────────────────────────────────────────────────────────
  testWidgets('tooltip is passed through to FAB', (tester) async {
    await pumpFab(tester, tooltip: 'Import book');
    expect(readFab(tester).tooltip, 'Import book');
  });

  // ── Tap ────────────────────────────────────────────────────────────────────
  testWidgets('onPressed fires when tapped', (tester) async {
    var taps = 0;
    await pumpFab(tester, onPressed: () => taps++);
    await tester.tap(find.byType(FloatingActionButton));
    expect(taps, 1);
  });
}
