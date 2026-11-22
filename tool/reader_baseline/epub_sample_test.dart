import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
import 'package:nyan_read/modules/reader/reader_engine/epub/epub_parse_helpers.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'baseline_support.dart';

void main() {
  final path = Platform.environment['NYAN_BASELINE_EPUB'];
  if (path == null) {
    throw StateError('Set NYAN_BASELINE_EPUB to an authorized local sample.');
  }
  late int longest;
  late int normal;
  setUpAll(() async {
    final loader = FontLoader(NyanTypography.uiFontFamily);
    loader.addFont(File('assets/fonts/subset/NotoSansSC-Regular.ttf')
        .readAsBytes()
        .then(ByteData.sublistView));
    await loader.load();
    final stats = await Isolate.run(() async {
      final parsed = await parseEpubFileInIsolate(path);
      var longestIndex = 0;
      var longestLength = 0;
      var normalIndex = 0;
      var images = 0;
      for (var i = 0; i < parsed.paragraphCount; i++) {
        if (parsed.paragraphKinds[i] == EpubParagraphKind.image) {
          images++;
          continue;
        }
        final length = utf8
            .decode(parsed.paragraphBytes.sublist(parsed.paragraphRanges[2 * i],
                parsed.paragraphRanges[2 * i + 1]))
            .length;
        if (length > longestLength) {
          longestLength = length;
          longestIndex = i;
        }
        if (normalIndex == 0 &&
            i > parsed.paragraphCount ~/ 3 &&
            length > 100 &&
            length < 250) {
          normalIndex = i;
        }
      }
      return {
        'paragraphs': parsed.paragraphCount,
        'chapters': parsed.chapters.length,
        'images': images,
        'longestIndex': longestIndex,
        'longestLength': longestLength,
        'normalIndex': normalIndex,
        'bytes': await File(path).length()
      };
    });
    longest = stats['longestIndex']!;
    normal = stats['normalIndex']!;
    debugPrint('EPUB_SAMPLE ${jsonEncode(stats)}');
  });

  for (final mode in [PageTurnMode.tap, PageTurnMode.swipe]) {
    testWidgets('external epub/${mode.name} long paragraph and restore',
        (tester) async {
      final engine = await mountFixture(tester, 'epub', mode,
          path: path, initialIndex: longest);
      final before = engine.getCurrentPosition()!;
      expect(before.paragraphTrailingEdge, greaterThan(2));
      await perform(tester, engine.nextPage);
      final after = engine.getCurrentPosition()!;
      record('epub-sample/${mode.name}/long-after', engine);
      expect(after.paragraphIndex, before.paragraphIndex);
      expect(before.paragraphLeadingEdge! - after.paragraphLeadingEdge!,
          closeTo(.92, 2 / 640));
      await perform(tester, engine.nextPage);
      await perform(tester, engine.previousPage);
      expectSameViewport(after, engine.getCurrentPosition()!);
      await perform(tester,
          () => engine.goToPosition(const ReadingPosition(paragraphIndex: 0)));
      await perform(
          tester,
          () => engine
              .goToPosition(ReadingPosition.fromJson('epub', after.toJson())));
      expectSameViewport(after, engine.getCurrentPosition()!);
    });
    testWidgets('external epub/${mode.name} 30 turns retain unread text',
        (tester) async {
      final engine = await mountFixture(tester, 'epub', mode,
          path: path, initialIndex: normal);
      await tester.drag(
          find.byType(ScrollablePositionedList), const Offset(0, -90));
      await tester.pumpAndSettle();
      final start = engine.getCurrentPosition()!;
      await perform(tester, engine.nextPage);
      await perform(tester, engine.previousPage);
      expectSameViewport(start, engine.getCurrentPosition()!);
      for (var i = 0; i < 30; i++) {
        final before = engine.getCurrentPosition()!;
        final bottom = visibleItems(tester).last;
        await perform(tester, engine.nextPage);
        final after = engine.getCurrentPosition()!;
        expect(advanced(before, after), isTrue);
        expect(after.paragraphIndex!, lessThanOrEqualTo(bottom.index));
      }
      record('epub-sample/${mode.name}/30-after', engine);
    });
  }
}
