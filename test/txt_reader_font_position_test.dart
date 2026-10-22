import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';

import '../tool/reader_baseline/baseline_support.dart';

void main() {
  setUpAll(() async {
    for (final font in {
      NyanTypography.uiFontFamily: 'assets/fonts/subset/NotoSansSC-Regular.ttf',
      NyanTypography.readingSerifFontFamily:
          'assets/fonts/SourceHanSerifSC-Regular.otf',
    }.entries) {
      final loader = FontLoader(font.key);
      loader.addFont(File(font.value).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  for (final serif in [false, true]) {
    for (final scale in [1.0, 1.5]) {
      for (final mode in [PageTurnMode.tap, PageTurnMode.swipe]) {
        testWidgets(
            'serif=$serif scale=$scale ${mode.name}: retain text anchor',
            (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final file = await tester.runAsync(() => writeFixture('txt', [
                ...List.filled(20, '第一个段落。A quiet afternoon. 🌿'),
                '中文正文与 English words，还有 emoji 🌿。' * 400,
                ...List.filled(20, '后面的段落。The next paragraph.'),
              ]));
          final engine =
              await mountFixture(tester, 'txt', mode, path: file!.path);
          engine.setConfig(ReaderConfig(
            backgroundColor: baselineConfig(mode).backgroundColor,
            textColor: baselineConfig(mode).textColor,
            fontSize: serif ? 24 : 16,
            lineHeight: serif ? 1.8 : 1.4,
            useSerif: serif,
            pageTurnMode: mode,
          ));
          await tester.pumpAndSettle();
          await perform(tester, engine.nextPage);
          final anchor = engine.getCurrentPosition()!;
          expect(anchor.paragraphIndex, 20);
          expect(anchor.paragraphLeadingEdge!, lessThan(-.5));
          await perform(tester, engine.nextPage);
          await perform(tester, engine.previousPage);
          expectSameViewport(anchor, engine.getCurrentPosition()!);
          await perform(
              tester,
              () => engine
                  .goToPosition(const ReadingPosition(paragraphIndex: 0)));
          await perform(
              tester,
              () => engine.goToPosition(
                  ReadingPosition.fromJson('txt', anchor.toJson())));
          expectSameViewport(anchor, engine.getCurrentPosition()!);
          tester.view.physicalSize = const Size(640, 360);
          await tester.pumpAndSettle();
          expect(engine.getCurrentPosition()!.paragraphIndex, 20);
          final rotated = engine.getCurrentPosition()!;
          await perform(tester, engine.nextPage);
          expect(advanced(rotated, engine.getCurrentPosition()!), isTrue);
        });
      }
    }
  }
}
