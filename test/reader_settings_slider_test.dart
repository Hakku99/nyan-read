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

  // ── Track height ───────────────────────────────────────────────────────────
  group('ReaderSettingsSlider track', () {
    testWidgets('track height is 4pt (spec: 3–4pt)', (tester) async {
      await pumpSlider(tester);
      final sliderTheme = tester.widget<SliderTheme>(find.byType(SliderTheme));
      expect(
        sliderTheme.data.trackHeight,
        4.0,
        reason: 'AGENTS.md §4.3: track height 3–4pt — was 5',
      );
    });
  });

  // ── Thumb ──────────────────────────────────────────────────────────────────
  group('ReaderSettingsSlider thumb', () {
    testWidgets('thumb radius is 6 (diameter 12pt, spec: 10–12pt)', (tester) async {
      await pumpSlider(tester);
      final sliderTheme = tester.widget<SliderTheme>(find.byType(SliderTheme));
      final thumb =
          sliderTheme.data.thumbShape as RoundSliderThumbShape;
      expect(
        thumb.enabledThumbRadius,
        6.0,
        reason: 'AGENTS.md §4.3: thumb 10–12pt — was radius 8 (16pt diameter)',
      );
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
