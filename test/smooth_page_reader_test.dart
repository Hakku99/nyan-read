import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';

void main() {
  testWidgets('SmoothPageReader uses 20/60/20 tap zones', (tester) async {
    var prevCount = 0;
    var nextCount = 0;
    var centerCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 100,
            height: 200,
            child: SmoothPageReader(
              onPreviousTap: () => prevCount++,
              onNextTap: () => nextCount++,
              onCenterTap: () => centerCount++,
              child: const ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(10, 50));
    await tester.pump();
    await tester.tapAt(const Offset(90, 50));
    await tester.pump();
    await tester.tapAt(const Offset(50, 50));
    await tester.pump();

    expect(prevCount, 1);
    expect(nextCount, 1);
    expect(centerCount, 1);
  });

  testWidgets('playTurn dispatches exactly once', (tester) async {
    final key = GlobalKey<SmoothPageReaderState>();
    var dispatchCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 300,
            child: SmoothPageReader(
              key: key,
              onPreviousTap: () {},
              onNextTap: () {},
              onCenterTap: () {},
              child: const ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ),
    );

    unawaited(key.currentState!.playTurn(
      forward: true,
      dispatchTurn: () async {
        dispatchCount++;
      },
    ));
    await tester.pumpAndSettle();

    expect(dispatchCount, 1);
    expect(key.currentState!.isAnimating, isFalse);
  });
}
