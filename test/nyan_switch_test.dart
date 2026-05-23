import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_switch.dart';

void main() {
  final preset = themePresets[ThemePreset.creamLight]!;

  Future<void> pumpSwitch(
    WidgetTester tester, {
    required bool value,
    ValueChanged<bool>? onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: preset.themeData,
        home: Scaffold(
          body: Center(
            child: NyanSwitch(value: value, onChanged: onChanged ?? (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Switch readSwitch(WidgetTester tester) =>
      tester.widget<Switch>(find.byType(Switch));

  // ── ON state ───────────────────────────────────────────────────────────────
  group('NyanSwitch ON state', () {
    testWidgets('active track is nyan.primary', (tester) async {
      await pumpSwitch(tester, value: true);
      expect(readSwitch(tester).activeTrackColor, preset.primary);
    });

    testWidgets('active thumb is white', (tester) async {
      await pumpSwitch(tester, value: true);
      expect(readSwitch(tester).activeThumbColor, Colors.white);
    });
  });

  // ── OFF state ──────────────────────────────────────────────────────────────
  group('NyanSwitch OFF state', () {
    testWidgets('inactive track is nyan.surfaceMuted', (tester) async {
      await pumpSwitch(tester, value: false);
      expect(readSwitch(tester).inactiveTrackColor, preset.surfaceMuted);
    });

    testWidgets('inactive thumb is white', (tester) async {
      await pumpSwitch(tester, value: false);
      expect(readSwitch(tester).inactiveThumbColor, Colors.white);
    });
  });

  // ── No Material splash ─────────────────────────────────────────────────────
  group('NyanSwitch no splash', () {
    testWidgets('overlayColor resolves to transparent', (tester) async {
      await pumpSwitch(tester, value: true);
      final overlay = readSwitch(tester).overlayColor!;
      expect(overlay.resolve({WidgetState.pressed}), Colors.transparent);
      expect(overlay.resolve({WidgetState.hovered}), Colors.transparent);
      expect(overlay.resolve({}), Colors.transparent);
    });

    testWidgets('splashRadius is 0', (tester) async {
      await pumpSwitch(tester, value: true);
      expect(readSwitch(tester).splashRadius, 0);
    });
  });

  // ── Toggle behaviour ───────────────────────────────────────────────────────
  testWidgets('onChanged fires with new value', (tester) async {
    final captured = <bool>[];
    await pumpSwitch(tester, value: false, onChanged: captured.add);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(captured, [true]);
  });

  // ── Track outline ──────────────────────────────────────────────────────────
  group('NyanSwitch track outline', () {
    testWidgets('outline is primary when selected', (tester) async {
      await pumpSwitch(tester, value: true);
      final outline = readSwitch(tester).trackOutlineColor!;
      expect(outline.resolve({WidgetState.selected}), preset.primary);
    });

    testWidgets('outline is divider when off', (tester) async {
      await pumpSwitch(tester, value: false);
      final outline = readSwitch(tester).trackOutlineColor!;
      final expected = preset.divider.withValues(alpha: 0.6);
      expect(outline.resolve({}), expected);
    });
  });
}
