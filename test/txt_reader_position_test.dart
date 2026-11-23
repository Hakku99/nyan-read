import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../tool/reader_baseline/baseline_support.dart';

void main() {
  for (final mode in [PageTurnMode.tap, PageTurnMode.swipe]) {
    testWidgets(
        '${mode.name}: long paragraph crosses its tail and roundtrips 20 turns',
        (tester) async {
      final engine = await mountFixture(tester, 'txt', mode, oversized: true);
      final anchors = <ReadingPosition>[engine.getCurrentPosition()!];
      for (var i = 0; i < 20; i++) {
        await perform(tester, engine.nextPage);
        final current = engine.getCurrentPosition()!;
        expect(advanced(anchors.last, current), isTrue);
        anchors.add(current);
      }
      expect(anchors.last.paragraphIndex!, greaterThan(20));
      for (var i = 19; i >= 0; i--) {
        await perform(tester, engine.previousPage);
        expectSameViewport(anchors[i], engine.getCurrentPosition()!);
      }
    });

    testWidgets('${mode.name}: repeated EOF turns do not trap previous',
        (tester) async {
      final file = await tester.runAsync(() => writeFixture('txt', [
            '中文与 emoji 🌿 remain together. ' * 1200,
          ]));
      final engine = await mountFixture(tester, 'txt', mode,
          path: file!.path, initialIndex: 0);
      var steps = 0;
      while (steps++ < 200) {
        final before = engine.getCurrentPosition()!;
        await perform(tester, engine.nextPage);
        if (!advanced(before, engine.getCurrentPosition()!)) break;
      }
      expect(steps, greaterThan(20));
      expect(steps, lessThan(200));
      final end = engine.getCurrentPosition()!;
      expect(end.paragraphTrailingEdge, closeTo(1, .004));
      for (var i = 0; i < 3; i++) {
        await perform(tester, engine.nextPage);
        expectSameViewport(end, engine.getCurrentPosition()!);
      }
      await perform(tester, engine.previousPage);
      expect(engine.getCurrentPosition()!.paragraphLeadingEdge!,
          greaterThan(end.paragraphLeadingEdge!));
    });

    testWidgets(
        '${mode.name}: restore is authoritative before and during layout',
        (tester) async {
      final engine = await mountFixture(tester, 'txt', mode);
      await tester.drag(
          find.byType(ScrollablePositionedList), const Offset(0, -90));
      await tester.pumpAndSettle();
      final saved = engine.getCurrentPosition()!;
      await perform(tester,
          () => engine.goToPosition(const ReadingPosition(paragraphIndex: 70)));
      final restore = engine.goToPosition(saved);
      expectSameViewport(saved, engine.getCurrentPosition()!);
      await tester.pump();
      expectSameViewport(saved, engine.getCurrentPosition()!);
      await tester.pumpAndSettle();
      await restore;
      expectSameViewport(saved, engine.getCurrentPosition()!);
    });

    testWidgets(
        '${mode.name}: chapter and progress navigation replace a pending turn',
        (tester) async {
      final engine = await mountFixture(tester, 'txt', mode, oversized: true);
      final oldTurn = engine.nextPage();
      await tester.pump(const Duration(milliseconds: 50));
      await perform(tester,
          () => engine.goToChapter(const ChapterLocator(chapterIndex: 60)));
      await oldTurn;
      final chapter = engine.getCurrentPosition()!;
      expect(chapter.paragraphIndex, 60);
      await tester.pump(const Duration(milliseconds: 500));
      expectSameViewport(chapter, engine.getCurrentPosition()!);
      await perform(tester, () => engine.seekToProgress(.8));
      // Character-based: the one long paragraph at index 20 shifts 80% back
      // from line 79 to line 77.
      expect(engine.getCurrentPosition()!.paragraphIndex, 77);
      final before = engine.getCurrentPosition()!;
      await perform(tester, engine.nextPage);
      expect(advanced(before, engine.getCurrentPosition()!), isTrue);
    });
  }

  for (final ratio in [.99, 1.0, 1.01, 2.0, 10.0]) {
    testWidgets('paragraph height $ratio viewports advances without skipping',
        (tester) async {
      final engine = await mountFixture(tester, 'txt', PageTurnMode.tap);
      final first = engine.getCurrentPosition()!;
      final height =
          (first.paragraphTrailingEdge! - first.paragraphLeadingEdge!) * 640;
      tester.view.physicalSize = Size(360, height / ratio);
      await tester.pumpAndSettle();
      await perform(tester,
          () => engine.goToPosition(const ReadingPosition(paragraphIndex: 20)));
      final before = engine.getCurrentPosition()!;
      await perform(tester, engine.nextPage);
      final after = engine.getCurrentPosition()!;
      expect(advanced(before, after), isTrue);
      if (ratio > 1) {
        expect(after.paragraphIndex, before.paragraphIndex);
        expect(before.paragraphLeadingEdge! - after.paragraphLeadingEdge!,
            lessThanOrEqualTo(1.01));
      }
    });
  }

  testWidgets('invalid geometry and out-of-range indices recover safely',
      (tester) async {
    final engine = await mountFixture(tester, 'txt', PageTurnMode.tap);
    for (final edges in [
      (double.nan, 1.0),
      (-double.infinity, 1.0),
      (-1e308, 1e308),
      (-1e308, 1.0),
      (-.2, -.3),
      (2.0, 3.0)
    ]) {
      await perform(
          tester,
          () => engine.goToPosition(ReadingPosition(
              paragraphIndex: 20,
              paragraphLeadingEdge: edges.$1,
              paragraphTrailingEdge: edges.$2)));
      expect(engine.getCurrentPosition()!.paragraphIndex, 20);
      expect(
          engine.getCurrentPosition()!.paragraphLeadingEdge, closeTo(0, .004));
    }
    await perform(tester,
        () => engine.goToPosition(const ReadingPosition(paragraphIndex: -100)));
    expect(engine.getCurrentPosition()!.paragraphIndex, 0);
    await perform(
        tester,
        () => engine
            .goToPosition(const ReadingPosition(paragraphIndex: 1000000)));
    expect(
        engine.getCurrentPosition()!.paragraphIndex!, inInclusiveRange(97, 99));
  });

  for (final text in ['', 'Short book.', '\r\n\r\n中文🌿\r\n\r\n']) {
    testWidgets(
        'short and empty inputs have stable boundaries (${text.length})',
        (tester) async {
      final file = await tester.runAsync(() => writeFixture('txt', [text]));
      final engine = await mountFixture(tester, 'txt', PageTurnMode.tap,
          path: file!.path, initialIndex: 0);
      final before = engine.getCurrentPosition()!;
      await perform(tester, engine.nextPage);
      await perform(tester, engine.previousPage);
      expectSameViewport(before, engine.getCurrentPosition()!);
    });
  }

  testWidgets('layout changes and disposal cancel outstanding motion',
      (tester) async {
    final engine =
        await mountFixture(tester, 'txt', PageTurnMode.swipe, oversized: true);
    final turn = engine.nextPage();
    await tester.pump(const Duration(milliseconds: 60));
    engine.setConfig(baselineConfig(PageTurnMode.swipe, fontSize: 24));
    tester.view.physicalSize = const Size(640, 360);
    await tester.pumpAndSettle();
    await turn;
    final stable = engine.getCurrentPosition()!.toJson();
    await tester.pump(const Duration(milliseconds: 600));
    expect(engine.getCurrentPosition()!.toJson(), stable);
    final pending = engine.nextPage();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pending;
    expect(tester.takeException(), isNull);
  });
}
