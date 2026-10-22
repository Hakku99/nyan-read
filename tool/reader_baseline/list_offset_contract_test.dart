import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'baseline_support.dart';

void main() {
  for (final height in [120.0, 2560.0]) {
    testWidgets('public relative offset works within a $height pixel item',
        (tester) async {
      tester.view.physicalSize = baselineViewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final items = ItemScrollController();
      final offsets = ScrollOffsetController();
      final positions = ItemPositionsListener.create();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: ScrollablePositionedList.builder(
          itemCount: 100,
          itemScrollController: items,
          scrollOffsetController: offsets,
          itemPositionsListener: positions,
          itemBuilder: (_, index) => SizedBox(
              height: index == 20 ? height : 120, child: Text('Item $index')),
        ),
      )));
      await tester.pumpAndSettle();
      items.jumpTo(index: 20);
      await tester.pumpAndSettle();
      final distance = height > 640 ? 640 * .92 : 90.0;
      await perform(
          tester,
          () => offsets.animateScroll(
              offset: distance, duration: const Duration(milliseconds: 1)));
      final anchor = positions.itemPositions.value
          .singleWhere((position) => position.index == 20);
      expect(anchor.itemLeadingEdge, closeTo(-distance / 640, 2 / 640));
      await perform(
          tester,
          () => offsets.animateScroll(
              offset: -distance, duration: const Duration(milliseconds: 1)));
      final returned = positions.itemPositions.value
          .singleWhere((position) => position.index == 20);
      expect(returned.itemLeadingEdge, closeTo(0, 2 / 640));
    });
  }
}
