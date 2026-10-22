import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../test/txt_reader_history_test.dart'
    show expectLocalPrevious, scrollable;
import 'baseline_support.dart';

void main() {
  final path = Platform.environment['NYAN_BASELINE_TXT'];
  if (path == null || path.isEmpty) {
    test('authorized TXT sample required', () {},
        skip: 'Set NYAN_BASELINE_TXT');
    return;
  }
  setUpAll(() async {
    final loader = FontLoader(NyanTypography.uiFontFamily);
    loader.addFont(File('assets/fonts/subset/NotoSansSC-Regular.ttf')
        .readAsBytes()
        .then(ByteData.sublistView));
    await loader.load();
  });
  // Fixed anchors in the authorized 9,190,763-byte baseline sample.
  for (final index in [12544, 34455]) {
    for (final mode in [PageTurnMode.tap, PageTurnMode.swipe]) {
      for (final input in ['drag', 'wheel', 'external movement']) {
        testWidgets('sample/${mode.name}/$index/$input keeps previous local',
            (tester) async {
          final engine = await mountFixture(tester, 'txt', mode,
              path: path, initialIndex: index);
          await perform(tester, engine.nextPage);
          final before = engine.getCurrentPosition()!;
          if (input == 'drag') {
            await tester.drag(
                find.byType(ScrollablePositionedList), const Offset(0, -1600));
          } else if (input == 'wheel') {
            await tester.sendEventToBinding(PointerScrollEvent(
                position:
                    tester.getCenter(find.byType(ScrollablePositionedList)),
                scrollDelta: const Offset(0, 900)));
          } else {
            final position = scrollable(tester).position;
            position.jumpTo(position.pixels + 90);
          }
          await tester.pumpAndSettle();
          expect(advanced(before, engine.getCurrentPosition()!), isTrue);
          await expectLocalPrevious(tester, engine);
          final anchor = engine.getCurrentPosition()!;
          await perform(tester, engine.nextPage);
          await perform(tester, engine.previousPage);
          expectSameViewport(anchor, engine.getCurrentPosition()!);
          record('history/${mode.name}/$index/$input', engine);
        });
      }
    }
  }
}
