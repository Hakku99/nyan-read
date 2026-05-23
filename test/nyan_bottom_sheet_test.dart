import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/nyan_spacing.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_bottom_sheet.dart';

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    Color? handleColor,
    String? title,
    String? description,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themePresets[ThemePreset.creamLight]!.themeData,
        home: Scaffold(
          body: NyanBottomSheet(
            handleColor: handleColor,
            title: title,
            description: description,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // Helper: finds the drag-handle Container (40×4).
  Container handleContainer(WidgetTester tester) {
    final containers = tester.widgetList<Container>(
      find.byType(Container),
    );
    return containers.firstWhere(
      (c) =>
          c.constraints?.maxWidth == 40 &&
          c.constraints?.maxHeight == NyanSpacing.space4,
      orElse: () => throw TestFailure('drag handle Container not found'),
    );
  }

  // ── Handle color ─────────────────────────────────────────────────────────
  group('NyanBottomSheet drag handle color (spec: text-muted)', () {
    testWidgets('default color is nyan.textMuted (not dividerColor)',
        (tester) async {
      final nyan = themePresets[ThemePreset.creamLight]!;
      await pumpSheet(tester);

      final handle = handleContainer(tester);
      final decoration = handle.decoration as BoxDecoration;
      expect(decoration.color, nyan.textMuted);
    });

    testWidgets('custom handleColor overrides the default', (tester) async {
      const customColor = Color(0xFFFF0000);
      await pumpSheet(tester, handleColor: customColor);

      final handle = handleContainer(tester);
      final decoration = handle.decoration as BoxDecoration;
      expect(decoration.color, customColor);
    });

    testWidgets('default color is NOT dividerColor (regression)', (tester) async {
      await pumpSheet(tester);
      final theme = tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!;
      final nyan = themePresets[ThemePreset.creamLight]!;

      final handle = handleContainer(tester);
      final decoration = handle.decoration as BoxDecoration;
      // dividerColor and textMuted are different tokens — verify it picked the right one.
      expect(decoration.color, isNot(equals(theme.dividerColor)));
      expect(decoration.color, nyan.textMuted);
    });
  });

  // ── Handle shape ─────────────────────────────────────────────────────────
  group('NyanBottomSheet drag handle shape (spec: pill / border-radius 999px)', () {
    testWidgets('handle uses pill border-radius (height/2 = 2pt)', (tester) async {
      await pumpSheet(tester);

      final handle = handleContainer(tester);
      final decoration = handle.decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(NyanSpacing.space4 / 2),
      );
    });
  });

  // ── Smoke ─────────────────────────────────────────────────────────────────
  testWidgets('renders title, description, and child', (tester) async {
    await pumpSheet(tester, title: 'Settings', description: 'Adjust reading');
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Adjust reading'), findsOneWidget);
  });
}
