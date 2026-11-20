import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  for (final distance in [90.0, 588.8, 6400.0]) {
    testWidgets('index and public pixel jump share one paint ($distance)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final items = ItemScrollController();
      ScrollPosition? position;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: ScrollablePositionedList.builder(
          itemCount: 100,
          itemScrollController: items,
          itemBuilder: (_, index) => Builder(builder: (context) {
            position = Scrollable.of(context).position;
            return SizedBox(
                key: ValueKey('row-$index'),
                height: index == 80 ? 10000 : 120,
                child: Text('Item $index'));
          }),
        ),
      )));
      await tester.pumpAndSettle();
      items.jumpTo(index: 80);
      position!.jumpTo(position!.pixels + distance);
      await tester.pump();
      // Assert the first target layout; a second corrective frame must not be
      // required, otherwise the user sees the paragraph start flash first.
      expect(tester.getTopLeft(find.byKey(const ValueKey('row-80'))).dy,
          closeTo(-distance, 2));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(const ValueKey('row-80'))).dy,
          closeTo(-distance, 2));
    });
  }
}
