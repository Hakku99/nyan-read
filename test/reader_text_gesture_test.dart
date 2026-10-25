import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:nyan_read/core/models/highlight.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/reader/widgets/reader_text_gestures.dart';
import 'package:nyan_read/modules/reader/widgets/highlightable_text.dart';

class Harness {
  int turns = 0;
  int highlightActions = 0;
  int centerInteractions = 0;
  final taps = <Offset>[];
  final selections = ReaderTextSelectionRegistry();
  Offset? start;
  Offset? end;
  final scroll = ScrollController();
  Future<void> mount(WidgetTester tester,
      {bool horizontal = true,
      bool highlighted = false,
      bool split = false}) async {
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
          selections: selections,
          onCenterInteraction: () => centerInteractions++,
          isTurnZone: (p) => p.dx < 160 || p.dx > 640,
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
            if (split)
              HighlightableText(
                  text: 'A separate first paragraph. ' * 3,
                  paragraphIndex: 1,
                  highlights: const [],
                  onTap: taps.add,
                  style: const TextStyle(fontSize: 18),
                  backgroundColor: Colors.white),
            HighlightableText(
              text:
                  List.filled(100, 'A readable paragraph for touch selection. ')
                      .join(),
              paragraphIndex: 0,
              highlights: highlighted
                  ? [
                      Highlight(
                          id: 'h',
                          bookId: 'b',
                          paragraphIndex: 0,
                          startOffset: 0,
                          endOffset: 1000,
                          selectedText: '',
                          colorCode: '#F2E58A',
                          createdAt: DateTime(2026))
                    ]
                  : const [],
              onHighlightTap: (_) => highlightActions++,
              onTap: taps.add,
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
  for (final gap in [30, 80, 250, 350]) {
    testWidgets('side burst $gap ms dispatches without accidental selection',
        (tester) async {
      final h = Harness();
      await h.mount(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tapAt(const Offset(700, 200));
        await tester.pump(Duration(milliseconds: gap));
      }
      await tester.pumpAndSettle();
      expect(h.taps.length, 3);
      expect(h.selections.hasSelection, isFalse);
      expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .selection
              .isCollapsed,
          isTrue);
      await tester.tapAt(const Offset(100, 200));
      await tester.pumpAndSettle();
      expect(h.taps.length, 4);
    }, variant: platforms);
  }
  testWidgets('center double tap selects text without opening controls',
      (tester) async {
    final h = Harness();
    await h.mount(tester);
    await tester.tapAt(const Offset(400, 200));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(400, 200));
    await tester.pumpAndSettle();
    expect(h.taps, isEmpty);
    expect(h.selections.hasSelection, isTrue);
  }, variant: platforms);
  testWidgets(
      'center single tap waits for double tap window then opens controls once',
      (tester) async {
    final h = Harness();
    await h.mount(tester);
    await tester.tapAt(const Offset(400, 200));
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.taps, isEmpty);
    await tester.pump(const Duration(milliseconds: 250));
    expect(h.taps.length, 1);
  }, variant: platforms);
  testWidgets(
      'long press at a turn edge retains selection instead of navigation',
      (tester) async {
    final h = Harness();
    await h.mount(tester);
    await tester.longPressAt(const Offset(700, 200));
    await tester.pumpAndSettle();
    expect(h.taps, isEmpty);
    expect(h.selections.hasSelection, isTrue);
  }, variant: platforms);
  testWidgets('mode switch cancels pending center tap', (tester) async {
    final h = Harness();
    await h.mount(tester);
    await tester.tapAt(const Offset(400, 200));
    await tester.pump(const Duration(milliseconds: 50));
    await h.mount(tester, horizontal: false);
    expect(h.taps, isEmpty);
  }, variant: platforms);
  testWidgets('highlight tap wins over page turn in side zone', (tester) async {
    final h = Harness();
    await h.mount(tester, highlighted: true);
    await tester.tapAt(const Offset(700, 20));
    await tester.pumpAndSettle();
    expect(h.highlightActions, 1);
    expect(h.taps, isEmpty);
  }, variant: platforms);

  testWidgets('dismiss selected text before a later side tap navigates',
      (tester) async {
    final h = Harness();
    await h.mount(tester);
    await tester.longPressAt(const Offset(400, 200));
    await tester.pumpAndSettle();
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    state.hideToolbar();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(100, 250));
    await tester.pumpAndSettle();
    expect(h.taps, isEmpty);
    expect(h.selections.hasSelection, isFalse);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(const Offset(100, 250));
    await tester.pumpAndSettle();
    expect(h.taps.length, 1);
  }, variant: platforms);
  testWidgets('mouse drag remains text selection', (tester) async {
    final h = Harness();
    await h.mount(tester);
    final drag = await tester.startGesture(const Offset(200, 200),
        kind: PointerDeviceKind.mouse);
    await drag.moveBy(const Offset(200, 0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(h.turns, 0);
    expect(h.taps, isEmpty);
    expect(h.selections.hasSelection, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  testWidgets('selection copy still writes only selected text', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final h = Harness();
    await h.mount(tester);
    await tester.longPressAt(const Offset(400, 200));
    await tester.pumpAndSettle();
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    final expected =
        editable.controller.selection.textInside(editable.controller.text);
    expect(expected, isNotEmpty);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, expected);
    expect(h.taps, isEmpty);
    expect(h.turns, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
      'center down cancels presentation before controls are disambiguated',
      (tester) async {
    final h = Harness();
    await h.mount(tester);
    final touch = await tester.startGesture(const Offset(400, 200));
    expect(h.centerInteractions, 1);
    expect(h.taps, isEmpty);
    await touch.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.taps, isEmpty);
    await tester.pump(const Duration(milliseconds: 250));
    expect(h.taps.length, 1);
    await tester.tapAt(const Offset(700, 200));
    await tester.pumpAndSettle();
    expect(h.centerInteractions, 1);
  }, variant: platforms);
  testWidgets(
      'a newer tap in another paragraph cancels pending center controls',
      (tester) async {
    final h = Harness();
    await h.mount(tester, split: true);
    await tester.tapAt(const Offset(400, 10));
    await tester.pump(const Duration(milliseconds: 50));
    final second = tester.getTopLeft(find.byType(HighlightableText).last);
    await tester.tapAt(Offset(700, second.dy + 10));
    await tester.pumpAndSettle();
    expect(h.taps.length, 1);
    expect(h.taps.single.dx, 700);
  }, variant: platforms);
}
