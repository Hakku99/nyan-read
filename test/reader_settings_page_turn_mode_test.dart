/// The page-turn chips must label each mode with its own name (audit N16):
/// they used to pair `PageTurnMode.values` (swipe, tap, …) with labels in
/// design order (Tap, Swipe, …), so "Tap" selected vertical scrolling.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_pill_button.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/reader/brightness/brightness_orchestrator.dart';
import 'package:nyan_read/modules/reader/brightness/brightness_repository.dart';
import 'package:nyan_read/modules/reader/brightness/system_brightness_adapter.dart';
import 'package:nyan_read/modules/reader/controllers/brightness_controller.dart';
import 'package:nyan_read/modules/reader/widgets/reader_settings/reader_settings_display_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StillBrightness extends SystemBrightnessAdapter {
  @override
  Future<double> currentBrightness() async => 0.5;
  @override
  Stream<double> brightnessChanges() => const Stream.empty();
  @override
  Future<void> setSystemBrightness(double brightness) async {}
  @override
  Future<void> resetSystemBrightness() async {}
}

void main() {
  Future<List<PageTurnMode>> pumpPanel(
      WidgetTester tester, PageTurnMode current) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = ReaderPreferencesService();
    await tester.runAsync(prefs.initialize);
    final brightness = BrightnessController(BrightnessOrchestrator(
      repository: BrightnessRepository(prefs),
      systemAdapter: _StillBrightness(),
    ));
    addTearDown(brightness.dispose);
    final selected = <PageTurnMode>[];
    await tester.pumpWidget(MaterialApp(
      theme: themePresets[ThemePreset.creamLight]!.themeData,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Builder(
            builder: (context) => ReaderSettingsDisplayPanel(
              brightnessController: brightness,
              loc: AppLocalizations.of(context)!,
              onWarmthChanged: (_) {},
              pageTurnMode: current,
              onSetPageTurnMode: selected.add,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return selected;
  }

  bool isSelected(WidgetTester tester, String label) => tester
      .widget<NyanPillButton>(find.ancestor(
          of: find.text(label), matching: find.byType(NyanPillButton)))
      .selected;

  testWidgets('each chip selects the mode it is labelled with',
      (tester) async {
    final selected = await pumpPanel(tester, PageTurnMode.disabled);
    for (final label in ['Tap', 'Swipe', 'Disabled']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
    }
    expect(selected,
        [PageTurnMode.tap, PageTurnMode.swipe, PageTurnMode.disabled]);
  });

  testWidgets('the current mode highlights its own chip', (tester) async {
    await pumpPanel(tester, PageTurnMode.swipe);
    expect(isSelected(tester, 'Swipe'), isTrue);
    expect(isSelected(tester, 'Tap'), isFalse);
  });
}
