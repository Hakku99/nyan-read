import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/modules/reader/widgets/reader_settings/reader_settings_common.dart';

void main() {
  final preset = themePresets[ThemePreset.creamLight]!;

  Future<void> pumpSlider(
    WidgetTester tester, {
    double value = 0.5,
    Color? activeColor,
    Color? inactiveColor,
    ValueChanged<double>? onChanged,
    ValueChanged<double>? onChangeEnd,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: preset.themeData,
        home: Scaffold(
          body: ReaderSettingsSlider(
            value: value,
            onChanged: onChanged ?? (_) {},
            onChangeEnd: onChangeEnd,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // The slider follows the reader.jsx `NyanSlider` handoff spec (6pt track,
  // 20pt ring thumb), which supersedes the older AGENTS.md 4.3 slider row.
  group('ReaderSettingsSlider track', () {
    testWidgets('track height is 6pt (handoff NyanSlider spec)',
        (tester) async {
      await pumpSlider(tester);
      final sliderTheme = tester.widget<SliderTheme>(find.byType(SliderTheme));
      expect(sliderTheme.data.trackHeight, 6.0);
    });
  });

  // ── Thumb ──────────────────────────────────────────────────────────────────
  group('ReaderSettingsSlider thumb', () {
    testWidgets('thumb is a 20pt-diameter ring (handoff NyanSlider spec)',
        (tester) async {
      await pumpSlider(tester);
      final sliderTheme = tester.widget<SliderTheme>(find.byType(SliderTheme));
      final size = sliderTheme.data.thumbShape!.getPreferredSize(true, false);
      expect(size, const Size(20, 20));
    });
  });

  // ── No glow ────────────────────────────────────────────────────────────────
  group('ReaderSettingsSlider overlay', () {
    testWidgets('default overlayRadius is 0 (spec: no glow)', (tester) async {
      await pumpSlider(tester);
      final sliderTheme = tester.widget<SliderTheme>(find.byType(SliderTheme));
      final overlay =
          sliderTheme.data.overlayShape as RoundSliderOverlayShape;
      expect(
        overlay.overlayRadius,
        0.0,
        reason: 'AGENTS.md §4.3: no glow — was overlayRadius 16',
      );
    });
  });

  // ── Haptics ────────────────────────────────────────────────────────────────
  group('ReaderSettingsSlider haptics', () {
    testWidgets('fires lightImpact on change end (spec: lightImpact only)',
        (tester) async {
      final log = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          log.add(call);
          return null;
        },
      );

      await pumpSlider(tester, onChangeEnd: (_) {});
      final slider = find.byType(Slider);
      await tester.drag(slider, const Offset(20, 0));
      await tester.pumpAndSettle();

      final hapticCalls = log.where(
        (c) =>
            c.method == 'HapticFeedback.vibrate' &&
            c.arguments == 'HapticFeedbackType.lightImpact',
      );
      expect(
        hapticCalls,
        isNotEmpty,
        reason: 'spec: lightImpact on drag end — was selectionClick',
      );
    });
  });

  // ── Smoke ──────────────────────────────────────────────────────────────────
  testWidgets('renders Slider widget', (tester) async {
    await pumpSlider(tester, value: 0.3);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('value is clamped to 0–1', (tester) async {
    await pumpSlider(tester, value: 0.7);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, closeTo(0.7, 0.001));
  });
}
