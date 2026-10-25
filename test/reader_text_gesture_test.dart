import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/reader/widgets/reader_text_gestures.dart';
import 'package:nyan_read/modules/reader/widgets/highlightable_text.dart';

class Harness {
  int turns = 0;
  Offset? start;
  Offset? end;
  final scroll = ScrollController();
  Future<void> mount(WidgetTester tester, {bool horizontal = true}) async {
    await tester.pumpWidget(MaterialApp(
      theme: themePresets[ThemePreset.creamLight]!.themeData,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
          body: GestureDetector(
        onPanEnd: (_) {
          if (horizontal) turns++;
        },
        child: ReaderTextGestures(
          horizontal: horizontal,
          onStart: (d) => start = d.globalPosition,
          onUpdate: (d) => end = d.globalPosition,
          onEnd: (_) {
            if (start != null &&
                end != null &&
                (end!.dx - start!.dx).abs() >
                    (end!.dy - start!.dy).abs() * 1.5) {
              turns++;
            }
          },
          child: ListView(controller: scroll, children: [
            HighlightableText(
              text:
                  List.filled(100, 'A readable paragraph for touch selection. ')
                      .join(),
              paragraphIndex: 0,
              highlights: const [],
              style: const TextStyle(fontSize: 18),
              backgroundColor: Colors.white,
            )
          ]),
        ),
      )),
    ));
    await tester.pumpAndSettle();
  }
}

void main() {
  final platforms =
      TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS});
  for (final dx in [-300.0, 300.0]) {
    testWidgets('body touch drag $dx reaches navigation once', (tester) async {
      final h = Harness();
      await h.mount(tester);
      await tester.dragFrom(const Offset(400, 200), Offset(dx, 0));
      await tester.pumpAndSettle();
      expect(h.turns, 1);
      expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .selection
              .isCollapsed,
          isTrue);
    }, variant: platforms);
  }
  testWidgets('vertical body drag still scrolls without a page request',
      (tester) async {
    final h = Harness();
    await h.mount(tester);
    await tester.dragFrom(const Offset(400, 300), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(h.turns, 0);
    expect(h.scroll.offset, greaterThan(0));
  }, variant: platforms);
  testWidgets('non-horizontal mode never forwards text drag', (tester) async {
    final h = Harness();
    await h.mount(tester, horizontal: false);
    await tester.dragFrom(const Offset(400, 200), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(h.turns, 0);
  }, variant: platforms);
  testWidgets('long press and selection drag do not navigate', (tester) async {
    final h = Harness();
    await h.mount(tester);
    final gesture = await tester.startGesture(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(180, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(h.turns, 0);
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .controller
            .selection
            .isCollapsed,
        isFalse);
  }, variant: platforms);
}
