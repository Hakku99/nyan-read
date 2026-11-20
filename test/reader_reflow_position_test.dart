import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/widgets/highlightable_text.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../tool/reader_baseline/baseline_support.dart';

ReaderConfig reflowConfig(int step) => ReaderConfig(
      backgroundColor: baselineConfig(PageTurnMode.swipe).backgroundColor,
      textColor: baselineConfig(PageTurnMode.swipe).textColor,
      fontSize: step.isEven ? 26 : 16,
      lineHeight: step.isEven ? 1.8 : 1.3,
      useSerif: step % 3 == 0,
      pageTurnMode: PageTurnMode.swipe,
    );

void expectTextVisible(WidgetTester tester, ReadingPosition anchor) {
  final paragraph = find.byWidgetPredicate((widget) =>
      widget is HighlightableText &&
      widget.paragraphIndex == anchor.paragraphIndex);
  final editable = tester
      .state<EditableTextState>(
          find.descendant(of: paragraph, matching: find.byType(EditableText)))
      .renderEditable;
  final caret =
      editable.getLocalRectForCaret(TextPosition(offset: anchor.textOffset!));
  final y = editable.localToGlobal(Offset(0, caret.top)).dy -
      tester.getTopLeft(find.byType(ScrollablePositionedList)).dy;
  expect(y, inInclusiveRange(-1.0, caret.height + 2),
      reason:
          'The original text must remain on the first visible reading line.');
}

void main() {
  setUpAll(() async {
    for (final entry in {
      NyanTypography.uiFontFamily: 'assets/fonts/subset/NotoSansSC-Regular.ttf',
      NyanTypography.readingSerifFontFamily:
          'assets/fonts/SourceHanSerifSC-Regular.otf',
    }.entries) {
      final font = FontLoader(entry.key);
      font.addFont(File(entry.value).readAsBytes().then(ByteData.sublistView));
      await font.load();
    }
  });
  for (final format in ['txt', 'epub']) {
    testWidgets('$format end-of-book reflow keeps the original text reachable',
        (tester) async {
      final file = await tester.runAsync(() => writeFixture(
          format, List.generate(10, (index) => '段落 $index，书尾缩放保位。' * 16)));
      final engine = await mountFixture(tester, format, PageTurnMode.swipe,
          path: file!.path, initialIndex: 0);
      await perform(tester, () => engine.seekToProgress(1));
      final anchor = engine.getCurrentPosition()!;
      expect(anchor.textOffset, isNotNull);
      engine.setConfig(ReaderConfig(
          backgroundColor: reflowConfig(0).backgroundColor,
          textColor: reflowConfig(0).textColor,
          fontSize: 12,
          lineHeight: 1,
          pageTurnMode: PageTurnMode.swipe));
      tester.view.physicalSize = const Size(1000, 1600);
      await tester.pumpAndSettle();
      expect(
          engine.getCurrentPosition()!.paragraphIndex, anchor.paragraphIndex);
      expect(engine.getCurrentPosition()!.textOffset, anchor.textOffset);
      final paragraph = find.byWidgetPredicate((widget) =>
          widget is HighlightableText &&
          widget.paragraphIndex == anchor.paragraphIndex);
      final editable = tester
          .state<EditableTextState>(find.descendant(
              of: paragraph, matching: find.byType(EditableText)))
          .renderEditable;
      final caret = editable
          .getLocalRectForCaret(TextPosition(offset: anchor.textOffset!));
      final y = editable.localToGlobal(Offset(0, caret.top)).dy;
      expect(y, inInclusiveRange(-2, 1600));
      engine.setConfig(baselineConfig(PageTurnMode.swipe));
      tester.view.physicalSize = baselineViewport;
      await tester.pumpAndSettle();
      expectTextVisible(tester, anchor);
    });
    testWidgets('$format paragraph start must retain its first text line',
        (tester) async {
      final file = await tester.runAsync(() => writeFixture(
          format, List.filled(40, '中文第一行不能被光标的负偏移跳过。后续正文用于自动换行。' * 6)));
      final engine = await mountFixture(tester, format, PageTurnMode.swipe,
          path: file!.path);
      expect(engine.getCurrentPosition()!.textOffset, 0);
      engine.setConfig(reflowConfig(0));
      await tester.pumpAndSettle();
      expect(engine.getCurrentPosition()!.textOffset, 0);
    });
    testWidgets('$format newer navigation supersedes a pending reflow',
        (tester) async {
      final engine = await mountFixture(tester, format, PageTurnMode.swipe,
          oversized: true);
      await perform(tester, engine.nextPage);
      engine.setConfig(reflowConfig(0));
      final restore =
          engine.goToPosition(const ReadingPosition(paragraphIndex: 70));
      await tester.pumpAndSettle();
      await restore;
      expect(engine.getCurrentPosition()!.paragraphIndex, 70);
      await tester.pump(const Duration(seconds: 1));
      expect(engine.getCurrentPosition()!.paragraphIndex, 70);
    });
    testWidgets('$format user drag supersedes reflow without a later snap back',
        (tester) async {
      final engine = await mountFixture(tester, format, PageTurnMode.swipe,
          oversized: true);
      await perform(tester, engine.nextPage);
      engine.setConfig(reflowConfig(0));
      await tester.pump();
      await tester.drag(
          find.byType(ScrollablePositionedList), const Offset(0, -400));
      await tester.pumpAndSettle();
      final moved = engine.getCurrentPosition()!;
      await tester.pump(const Duration(seconds: 1));
      expectSameViewport(moved, engine.getCurrentPosition()!);
      await perform(tester, engine.nextPage);
      expect(advanced(moved, engine.getCurrentPosition()!), isTrue);
    });
    testWidgets(
        '$format scale immediately after scroll keeps last committed text',
        (tester) async {
      final engine = await mountFixture(tester, format, PageTurnMode.swipe,
          oversized: true);
      await tester.drag(
          find.byType(ScrollablePositionedList), const Offset(0, -500));
      await tester.pumpAndSettle();
      final anchor = engine.getCurrentPosition()!;
      expect(anchor.textOffset, isNotNull);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expectTextVisible(tester, anchor);
      expect(engine.getCurrentPosition()!.textOffset, anchor.textOffset);
    });
    testWidgets('$format reflows retain actual text without cumulative drift',
        (tester) async {
      final file = await tester.runAsync(() => writeFixture(format, [
            ...List.filled(20, '前面的段落。'),
            '中文 English e\u0301 👨‍👩‍👧‍👦 🌿，逐字保位验证。' * 400,
            ...List.filled(20, '后面的段落。'),
          ]));
      final engine = await mountFixture(tester, format, PageTurnMode.swipe,
          path: file!.path);
      await tester.drag(
          find.byType(ScrollablePositionedList), const Offset(0, -850));
      await tester.pumpAndSettle();
      final anchor = engine.getCurrentPosition()!;
      expect(anchor.textOffset, greaterThan(100));
      for (var step = 0; step < 12; step++) {
        engine.setConfig(reflowConfig(step));
        // Simultaneous orientation and typography updates must share one anchor.
        tester.view.physicalSize =
            step.isEven ? const Size(640, 360) : baselineViewport;
        await tester.pumpAndSettle();
        expect(engine.getCurrentPosition()!.textOffset, anchor.textOffset);
        expectTextVisible(tester, anchor);
      }
      for (var step = 0; step < 100; step++) {
        engine.setConfig(reflowConfig(step));
      }
      await tester.pumpAndSettle();
      expectTextVisible(tester, anchor);
      expect(engine.getCurrentPosition()!.textOffset, anchor.textOffset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expectTextVisible(tester, anchor);
      final saved = ReadingPosition.fromJson(
          format, engine.getCurrentPosition()!.toJson());
      await perform(tester, () => engine.seekToProgress(.9));
      engine.setConfig(reflowConfig(0));
      await perform(tester, () => engine.goToPosition(saved));
      expectTextVisible(tester, anchor);
    });
  }
  test('optional text anchors tolerate legacy and malformed payloads', () {
    expect(ReadingPosition.fromJson('txt', '{"paragraphIndex":2}').textOffset,
        isNull);
    final position = ReadingPosition.fromJson('txt',
        '{"paragraphIndex":2,"textOffset":"bad","textViewportOffset":-1,"anchorVersion":99}');
    expect(position.textOffset, isNull);
    expect(position.textViewportOffset, isNull);
    expect(position.anchorVersion, isNull);
  });
}
