import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/reader/reader_engine/text_layout_anchor.dart';
import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../tool/reader_baseline/baseline_support.dart';

void main() {
  for (final format in ['txt', 'epub']) {
    testWidgets(
        '$format real horizontal captures tolerate viewport reconstruction',
        (tester) async {
      final engine = await mountFixture(tester, format, PageTurnMode.tap);
      for (var turn = 0; turn < 3; turn++) {
        final before = engine.getCurrentPosition()!;
        final reader =
            tester.state<SmoothPageReaderState>(find.byType(SmoothPageReader));
        await perform(
            tester,
            () =>
                reader.playTurn(forward: true, dispatchTurn: engine.nextPage));
        expect(advanced(before, engine.getCurrentPosition()!), isTrue);
        expect(tester.takeException(), isNull);
      }
    });
    for (final from in PageTurnMode.values) {
      for (final to in PageTurnMode.values.where((mode) => mode != from)) {
        for (final oversized in [false, true]) {
          testWidgets('$format $from to $to long=$oversized preserves viewport',
              (tester) async {
            final engine =
                await mountFixture(tester, format, from, oversized: oversized);
            await tester.drag(find.byType(ScrollablePositionedList),
                Offset(0, oversized ? -800 : -90));
            await tester.pumpAndSettle();
            final before = engine.getCurrentPosition()!;
            final oldScrollable =
                tester.state<ScrollableState>(find.byType(Scrollable).first);
            engine.setConfig(baselineConfig(to));
            await tester.pumpWidget(MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: Builder(builder: (context) {
                final body = engine.buildReader(context);
                return SmoothPageReader(
                    enabled: to == PageTurnMode.tap,
                    onPreviousTap: () {},
                    onNextTap: () {},
                    onCenterTap: () {},
                    child: body);
              })),
            ));
            final firstFrame = visibleItems(tester).first;
            expect(firstFrame.index, before.paragraphIndex);
            expect(
                firstFrame.itemLeadingEdge,
                closeTo(
                    before.paragraphLeadingEdge!, 2 / baselineViewport.height));
            expect(
                tester
                    .widget<RestoreVisibility>(find.byType(RestoreVisibility))
                    .covered
                    .value,
                isFalse,
                reason: 'Mode-only changes must not blank the reader.');
            expect(tester.state<ScrollableState>(find.byType(Scrollable).first),
                same(oldScrollable),
                reason: 'Reparenting must retain the live viewport.');
            await tester.pumpAndSettle();
            for (var repeat = 0; repeat < 3; repeat++) {
              engine.setConfig(baselineConfig(to));
              expectSameViewport(before, engine.getCurrentPosition()!);
              await pumpReader(tester, engine, to);
              expectSameViewport(before, engine.getCurrentPosition()!);
              engine.setConfig(baselineConfig(from));
              await pumpReader(tester, engine, from);
              expectSameViewport(before, engine.getCurrentPosition()!);
            }
          });
        }
      }
    }
  }
}
