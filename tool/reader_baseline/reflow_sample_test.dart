import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../test/reader_reflow_position_test.dart'
    show expectTextVisible, reflowConfig;
import 'baseline_support.dart';

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
    final path = Platform.environment['NYAN_BASELINE_${format.toUpperCase()}'];
    if (path == null) throw StateError('Provide both authorized sample paths.');
    for (final index in format == 'txt' ? [12544, 34455] : [61007, 149859]) {
      for (final initialMode in PageTurnMode.values) {
        testWidgets('external $format index=$index mode=${initialMode.name}',
            (tester) async {
          final engine = await mountFixture(tester, format, initialMode,
              path: path, initialIndex: index);
          await tester.drag(find.byType(ScrollablePositionedList),
              Offset(0, index == 34455 || index == 149859 ? -750 : -90));
          await tester.pumpAndSettle();
          final anchor = engine.getCurrentPosition()!;
          expect(anchor.textOffset, isNotNull);
          for (final mode in PageTurnMode.values) {
            engine.setConfig(baselineConfig(mode));
            await pumpReader(tester, engine, mode);
            expectSameViewport(anchor, engine.getCurrentPosition()!);
          }
          for (var step = 0; step < 6; step++) {
            engine.setConfig(reflowConfig(step));
            tester.view.physicalSize =
                step.isEven ? const Size(640, 360) : baselineViewport;
            await tester.pumpAndSettle();
            expectTextVisible(tester, anchor);
            expect(engine.getCurrentPosition()!.textOffset, anchor.textOffset);
          }
          final saved = ReadingPosition.fromJson(
              format, engine.getCurrentPosition()!.toJson());
          await perform(tester, () => engine.seekToProgress(.01));
          engine.setConfig(reflowConfig(0));
          await perform(tester, () => engine.goToPosition(saved));
          expectTextVisible(tester, anchor);
          // A new engine must consume the same additive JSON across layouts.
          await tester.pumpWidget(const SizedBox.shrink());
          final reopened = await mountFixture(tester, format, initialMode,
              path: path, beforeAttachPosition: saved);
          expectTextVisible(tester, anchor);
          expect(reopened.getCurrentPosition()!.textOffset, anchor.textOffset);
        });
      }
    }
  }
}
