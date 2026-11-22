import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../tool/reader_baseline/baseline_support.dart';

ScrollableState scrollable(WidgetTester tester) =>
    tester.state<ScrollableState>(find
        .descendant(
            of: find.byType(ScrollablePositionedList),
            matching: find.byType(Scrollable))
        .first);

// The same visible starting position must behave identically with an obsolete
// history and with a clean explicit restore. This also covers mixed row heights.
Future<void> expectLocalPrevious(
    WidgetTester tester, ReaderEngine engine) async {
  final origin = engine.getCurrentPosition()!;
  await perform(tester, engine.previousPage);
  final actual = engine.getCurrentPosition()!;
  await perform(tester, () => engine.goToPosition(origin));
  await perform(tester, engine.previousPage);
  expectSameViewport(engine.getCurrentPosition()!, actual);
}

void main() {
  testWidgets('a boundary no-op supersedes a returning animation',
      (tester) async {
    final file = await tester.runAsync(
        () => writeFixture('txt', ['A very long paragraph. ' * 1200]));
    final engine = await mountFixture(tester, 'txt', PageTurnMode.swipe,
        path: file!.path, initialIndex: 0);
    await perform(tester, engine.nextPage);
    final returning = engine.previousPage();
    await tester.pump(const Duration(milliseconds: 60));
    final position = scrollable(tester).position;
    position.jumpTo(position.minScrollExtent);
    final noOp = engine.previousPage();
    await tester.pumpAndSettle();
    await returning;
    await noOp;
    expect(engine.getCurrentPosition()!.paragraphIndex, 0);
    expect(tester.takeException(), isNull);
  });
  for (final mode in [PageTurnMode.tap, PageTurnMode.swipe]) {
    testWidgets(
        '${mode.name}: gesture returning to the old endpoint clears history',
        (tester) async {
      final engine = await mountFixture(tester, 'txt', mode);
      await tester.drag(
          find.byType(ScrollablePositionedList), const Offset(0, -90));
      await tester.pumpAndSettle();
      await perform(tester, engine.nextPage);
      final position = scrollable(tester).position;
      final oldEndpoint = position.pixels;
      await tester.drag(
          find.byType(ScrollablePositionedList), const Offset(0, -120));
      await tester.pumpAndSettle();
      position.jumpTo(oldEndpoint);
      await tester.pumpAndSettle();
      await expectLocalPrevious(tester, engine);
    });
    for (final movement in [
      'small drag',
      'large drag',
      'wheel',
      'external jump'
    ]) {
      testWidgets('${mode.name}: $movement invalidates history',
          (tester) async {
        final engine = await mountFixture(tester, 'txt', mode);
        await perform(tester, engine.nextPage);
        if (movement == 'wheel') {
          await tester.sendEventToBinding(PointerScrollEvent(
              position: tester.getCenter(find.byType(ScrollablePositionedList)),
              scrollDelta: const Offset(0, 900)));
        } else if (movement == 'external jump') {
          final position = scrollable(tester).position;
          position.jumpTo(position.pixels + 1200);
        } else {
          await tester.drag(find.byType(ScrollablePositionedList),
              Offset(0, movement == 'small drag' ? -45 : -1600));
        }
        await tester.pumpAndSettle();
        await expectLocalPrevious(tester, engine);
      });
    }

    testWidgets('${mode.name}: same long paragraph drift invalidates history',
        (tester) async {
      final engine = await mountFixture(tester, 'txt', mode, oversized: true);
      await perform(tester, engine.nextPage);
      final before = engine.getCurrentPosition()!;
      final position = scrollable(tester).position;
      position.jumpTo(position.pixels + 90);
      await tester.pumpAndSettle();
      expect(
          engine.getCurrentPosition()!.paragraphIndex, before.paragraphIndex);
      await expectLocalPrevious(tester, engine);
    });

    for (final change in ['font', 'mode', 'viewport', 'detach']) {
      testWidgets('${mode.name}: $change discards old geometry',
          (tester) async {
        final engine = await mountFixture(tester, 'txt', mode);
        await tester.drag(
            find.byType(ScrollablePositionedList), const Offset(0, -90));
        await tester.pumpAndSettle();
        await perform(tester, engine.nextPage);
        if (change == 'font') {
          engine.setConfig(baselineConfig(mode, fontSize: 24));
        } else if (change == 'mode') {
          engine.setConfig(baselineConfig(mode == PageTurnMode.tap
              ? PageTurnMode.swipe
              : PageTurnMode.tap));
        } else if (change == 'viewport') {
          tester.view.physicalSize = const Size(640, 360);
        } else {
          await tester.pumpWidget(const SizedBox.shrink());
          await pumpReader(tester, engine, mode);
        }
        await tester.pumpAndSettle();
        await expectLocalPrevious(tester, engine);
      });
    }

    testWidgets('${mode.name}: history beyond 48 stays bounded and contiguous',
        (tester) async {
      final file = await tester.runAsync(() => writeFixture(
          'txt',
          List.filled(
              500,
              'A normal paragraph with enough words to span several text lines. ' *
                  2)));
      final engine = await mountFixture(tester, 'txt', mode, path: file!.path);
      final anchors = <ReadingPosition>[];
      for (var i = 0; i < 60; i++) {
        anchors.add(engine.getCurrentPosition()!);
        await perform(tester, engine.nextPage);
      }
      for (var i = 59; i >= 12; i--) {
        await perform(tester, engine.previousPage);
        expectSameViewport(anchors[i], engine.getCurrentPosition()!);
      }
      await expectLocalPrevious(tester, engine);
    });
  }

  for (final interruption in ['drag', 'wheel', 'jump', 'chapter']) {
    testWidgets(
        'swipe: $interruption during animation cannot restore history later',
        (tester) async {
      final engine = await mountFixture(tester, 'txt', PageTurnMode.swipe,
          oversized: true);
      await perform(tester, engine.nextPage);
      final pending = engine.nextPage();
      await tester.pump(const Duration(milliseconds: 60));
      if (interruption == 'drag') {
        await tester.drag(
            find.byType(ScrollablePositionedList), const Offset(0, -140));
      } else if (interruption == 'wheel') {
        await tester.sendEventToBinding(PointerScrollEvent(
            position: tester.getCenter(find.byType(ScrollablePositionedList)),
            scrollDelta: const Offset(0, 140)));
      } else if (interruption == 'jump') {
        final position = scrollable(tester).position;
        position.jumpTo(position.pixels + 180);
      } else {
        await perform(tester,
            () => engine.goToChapter(const ChapterLocator(chapterIndex: 60)));
      }
      await tester.pumpAndSettle();
      await pending;
      final stable = engine.getCurrentPosition()!;
      await tester.pump(const Duration(milliseconds: 500));
      expectSameViewport(stable, engine.getCurrentPosition()!);
      await expectLocalPrevious(tester, engine);
    });
  }
  testWidgets('overlapping engine turns retain only the latest completed turn',
      (tester) async {
    final engine =
        await mountFixture(tester, 'txt', PageTurnMode.swipe, oversized: true);
    final first = engine.nextPage();
    await tester.pump(const Duration(milliseconds: 80));
    final secondStart = engine.getCurrentPosition()!;
    final second = engine.nextPage();
    await tester.pumpAndSettle();
    await first;
    await second;
    await perform(tester, engine.previousPage);
    expectSameViewport(secondStart, engine.getCurrentPosition()!);
    await expectLocalPrevious(tester, engine);
  });
}
