import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/reader_engine/txt/txt_reader.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'baseline_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final format in ['txt', 'epub']) {
    for (final mode in [PageTurnMode.tap, PageTurnMode.swipe]) {
      final label = '$format/${mode.name}';
      testWidgets('$label long paragraph advances without skipping unread text',
          (tester) async {
        final engine =
            await mountFixture(tester, format, mode, oversized: true);
        final before = engine.getCurrentPosition()!;
        expect(before.paragraphTrailingEdge!, greaterThan(2));
        record('$label/long-before', engine);
        await perform(tester, engine.nextPage);
        record('$label/long-after', engine);
        final after = engine.getCurrentPosition()!;
        expect(after.paragraphIndex, before.paragraphIndex,
            reason: 'The oversized paragraph still contains unread text.');
        expect(advanced(before, after), isTrue,
            reason: 'Next must move forward.');
        final movement =
            before.paragraphLeadingEdge! - after.paragraphLeadingEdge!;
        expect(movement, lessThanOrEqualTo(1),
            reason: 'A forward turn must not skip a viewport.');
      });

      testWidgets('$label clipped next/previous preserves the viewport',
          (tester) async {
        final engine = await mountFixture(tester, format, mode);
        await tester.drag(
            find.byType(ScrollablePositionedList), const Offset(0, -90));
        await tester.pumpAndSettle();
        final before = engine.getCurrentPosition()!;
        expect(before.paragraphLeadingEdge!, lessThan(-0.01));
        record('$label/roundtrip-before', engine);
        await perform(tester, engine.nextPage);
        await perform(tester, engine.previousPage);
        record('$label/roundtrip-after', engine);
        expectSameViewport(before, engine.getCurrentPosition()!);
      });

      testWidgets('$label serialized clipped position restores precisely',
          (tester) async {
        final engine = await mountFixture(tester, format, mode);
        await tester.drag(
            find.byType(ScrollablePositionedList), const Offset(0, -90));
        await tester.pumpAndSettle();
        final before = engine.getCurrentPosition()!;
        final saved = ReadingPosition.fromJson(format, before.toJson());
        await perform(
            tester,
            () =>
                engine.goToPosition(const ReadingPosition(paragraphIndex: 60)));
        await perform(tester, () => engine.goToPosition(saved));
        record('$label/restore-after', engine);
        expectSameViewport(before, engine.getCurrentPosition()!);
      });

      testWidgets(
          '$label normal next retains the partially visible bottom text',
          (tester) async {
        final engine = await mountFixture(tester, format, mode);
        final before = engine.getCurrentPosition()!;
        final bottom = visibleItems(tester).last;
        expect(bottom.itemTrailingEdge, greaterThan(1));
        await perform(tester, engine.nextPage);
        record('$label/bottom-after', engine);
        expect(advanced(before, engine.getCurrentPosition()!), isTrue);
        expect(engine.getCurrentPosition()!.paragraphIndex!,
            lessThanOrEqualTo(bottom.index),
            reason:
                'The partially visible bottom paragraph must remain reachable.');
      });
    }
  }

  for (final mode in [PageTurnMode.tap, PageTurnMode.swipe]) {
    testWidgets('txt/${mode.name} fresh engine retains a pre-attach restore',
        (tester) async {
      final first = await mountFixture(tester, 'txt', mode);
      await tester.drag(
          find.byType(ScrollablePositionedList), const Offset(0, -90));
      await tester.pumpAndSettle();
      final saved =
          ReadingPosition.fromJson('txt', first.getCurrentPosition()!.toJson());
      expect(saved.paragraphLeadingEdge!, lessThan(-0.01));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final reopened =
          await mountFixture(tester, 'txt', mode, beforeAttachPosition: saved);
      record('txt/${mode.name}/fresh-restore', reopened);
      expectSameViewport(saved, reopened.getCurrentPosition()!);
    });

    testWidgets(
        'txt/${mode.name} manual scroll invalidates stale backward history',
        (tester) async {
      final engine = await mountFixture(tester, 'txt', mode);
      final rowHeight = visibleItems(tester).first.itemTrailingEdge;
      await perform(tester, engine.nextPage);
      await tester.drag(
          find.byType(ScrollablePositionedList), const Offset(0, -1600));
      await tester.pumpAndSettle();
      final before = engine.getCurrentPosition()!;
      await perform(tester, engine.previousPage);
      final after = engine.getCurrentPosition()!;
      // All rows in this fixture have identical geometry. Measure distance,
      // rather than assuming an arbitrary number of paragraphs per screen.
      final distance =
          (before.paragraphIndex! - after.paragraphIndex!) * rowHeight +
              after.paragraphLeadingEdge! -
              before.paragraphLeadingEdge!;
      debugPrint('BASELINE history/${mode.name} distanceInViewports=$distance');
      expect(distance, inInclusiveRange(0, 1 + rowHeight),
          reason:
              'Previous may align a row boundary, but must stay near the current screen.');
    });
  }

  for (final format in ['txt', 'epub']) {
    testWidgets('$format switching scroll to tap preserves the viewport',
        (tester) async {
      final engine = await mountFixture(tester, format, PageTurnMode.swipe);
      await tester.drag(
          find.byType(ScrollablePositionedList), const Offset(0, -700));
      await tester.pumpAndSettle();
      final before = engine.getCurrentPosition()!;
      engine.setConfig(baselineConfig(PageTurnMode.tap));
      await pumpReader(tester, engine, PageTurnMode.tap);
      record('$format/mode-after', engine);
      expectSameViewport(before, engine.getCurrentPosition()!);
    });

    testWidgets('$format layout change keeps a logical paragraph anchor',
        (tester) async {
      final engine = await mountFixture(tester, format, PageTurnMode.swipe);
      final before = engine.getCurrentPosition()!;
      engine.setConfig(baselineConfig(PageTurnMode.swipe, fontSize: 24));
      tester.view.physicalSize = const Size(640, 360);
      await tester.pumpAndSettle();
      expect(
          engine.getCurrentPosition()!.paragraphIndex, before.paragraphIndex);
    });
  }

  // Opt in via a local environment variable; no user book is committed.
  final externalTxt = Platform.environment['NYAN_BASELINE_TXT'];
  if (externalTxt != null && externalTxt.isNotEmpty) {
    late int longestIndex;
    late int normalIndex;
    setUpAll(() async {
      final font = FontLoader(NyanTypography.uiFontFamily);
      font.addFont(File('assets/fonts/subset/NotoSansSC-Regular.ttf')
          .readAsBytes()
          .then(ByteData.sublistView));
      await font.load();
      final bytes = await File(externalTxt).readAsBytes();
      // This standalone diagnostic suite lives outside test/ intentionally.
      // ignore: invalid_use_of_visible_for_testing_member
      final lines = decodeTxtBytesForParse(bytes).split('\n');
      longestIndex = 0;
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].length > lines[longestIndex].length) longestIndex = i;
      }
      normalIndex = lines.length ~/ 10;
      while (normalIndex < lines.length - 1 &&
          (lines[normalIndex].trim().length < 100 ||
              lines[normalIndex].length > 250)) {
        normalIndex++;
      }
      debugPrint(
          'BASELINE external bytes=${bytes.length} paragraphs=${lines.length} '
          'longestIndex=$longestIndex longestLength=${lines[longestIndex].length}');
    });
    for (final mode in [PageTurnMode.tap, PageTurnMode.swipe]) {
      testWidgets(
          'external/txt/${mode.name} long paragraph makes forward progress',
          (tester) async {
        final engine = await mountFixture(tester, 'txt', mode,
            path: externalTxt, initialIndex: longestIndex);
        final before = engine.getCurrentPosition()!;
        await perform(tester, engine.nextPage);
        record('external/${mode.name}/long-after', engine);
        expect(advanced(before, engine.getCurrentPosition()!), isTrue);
      });
      testWidgets('external/txt/${mode.name} clipped roundtrip is exact',
          (tester) async {
        final engine = await mountFixture(tester, 'txt', mode,
            path: externalTxt, initialIndex: normalIndex);
        await tester.drag(
            find.byType(ScrollablePositionedList), const Offset(0, -110));
        await tester.pumpAndSettle();
        final before = engine.getCurrentPosition()!;
        await perform(tester, engine.nextPage);
        await perform(tester, engine.previousPage);
        record('external/${mode.name}/roundtrip-after', engine);
        expectSameViewport(before, engine.getCurrentPosition()!);
      });
      testWidgets('external/txt/${mode.name} 30 normal steps move forward',
          (tester) async {
        final engine = await mountFixture(tester, 'txt', mode,
            path: externalTxt, initialIndex: normalIndex);
        final distances = <double>[];
        for (var i = 0; i < 30; i++) {
          final before = engine.getCurrentPosition()!;
          final items = visibleItems(tester);
          await perform(tester, engine.nextPage);
          expect(advanced(before, engine.getCurrentPosition()!), isTrue);
          final after = visibleItems(tester);
          expect(after.first.index, lessThanOrEqualTo(items.last.index),
              reason: 'Consecutive turns must retain an overlapping item.');
          for (final item in items) {
            final matches = after.where((p) => p.index == item.index);
            if (matches.isNotEmpty) {
              distances
                  .add(item.itemLeadingEdge - matches.first.itemLeadingEdge);
              break;
            }
          }
        }
        debugPrint(
            'BASELINE external/${mode.name}/distances=${distances.map((d) => d.toStringAsFixed(3)).join(',')}');
        expect(distances, hasLength(30));
      });
    }
  }
}
