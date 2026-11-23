import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_switch.dart';

/// NyanSwitch is a custom 44x26 pill + 20pt surface thumb (primitives.jsx),
/// not a Material [Switch]; these tests read its decorated containers.
void main() {
  final preset = themePresets[ThemePreset.creamLight]!;

  Future<void> pumpSwitch(
    WidgetTester tester, {
    required bool value,
    ValueChanged<bool>? onChanged,
    bool disabled = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: preset.themeData,
        home: Scaffold(
          body: Center(
            child: NyanSwitch(
              value: value,
              onChanged: disabled ? null : (onChanged ?? (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  BoxDecoration trackDecoration(WidgetTester tester) => tester
      .widget<AnimatedContainer>(find.byType(AnimatedContainer))
      .decoration! as BoxDecoration;

  BoxDecoration thumbDecoration(WidgetTester tester) {
    final thumb = tester.widget<Container>(
      find.descendant(
        of: find.byType(AnimatedAlign),
        matching: find.byType(Container),
      ),
    );
    return thumb.decoration! as BoxDecoration;
  }

  group('NyanSwitch track', () {
    testWidgets('is a 44x26 pill', (tester) async {
      await pumpSwitch(tester, value: true);
      expect(tester.getSize(find.byType(AnimatedContainer)), const Size(44, 26));
      expect(trackDecoration(tester).borderRadius, BorderRadius.circular(999));
    });

    testWidgets('ON track is nyan.primary', (tester) async {
      await pumpSwitch(tester, value: true);
      expect(trackDecoration(tester).color, preset.primary);
    });

    testWidgets('OFF track is nyan.divider', (tester) async {
      await pumpSwitch(tester, value: false);
      expect(trackDecoration(tester).color, preset.divider);
    });

    testWidgets('disabled track is dimmed to 45% alpha', (tester) async {
      await pumpSwitch(tester, value: true, disabled: true);
      expect(
        trackDecoration(tester).color,
        preset.primary.withValues(alpha: 0.45),
      );
    });
  });

  group('NyanSwitch thumb', () {
    testWidgets('is a 20pt nyan.surface circle', (tester) async {
      await pumpSwitch(tester, value: false);
      final d = thumbDecoration(tester);
      expect(d.shape, BoxShape.circle);
      expect(d.color, preset.surface);
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(AnimatedAlign),
            matching: find.byType(Container),
          ),
        ),
        const Size(20, 20),
      );
    });

    testWidgets('sits on the right when ON, left when OFF', (tester) async {
      await pumpSwitch(tester, value: true);
      expect(
        tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment,
        Alignment.centerRight,
      );
      await pumpSwitch(tester, value: false);
      expect(
        tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment,
        Alignment.centerLeft,
      );
    });
  });

  group('NyanSwitch behaviour', () {
    testWidgets('onChanged fires with the toggled value', (tester) async {
      final captured = <bool>[];
      await pumpSwitch(tester, value: false, onChanged: captured.add);
      await tester.tap(find.byType(NyanSwitch));
      await tester.pumpAndSettle();
      expect(captured, [true]);
    });

    testWidgets('disabled switch ignores taps', (tester) async {
      await pumpSwitch(tester, value: false, disabled: true);
      await tester.tap(find.byType(NyanSwitch));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NyanSwitch>(find.byType(NyanSwitch)).onChanged,
        isNull,
      );
    });
  });
}
