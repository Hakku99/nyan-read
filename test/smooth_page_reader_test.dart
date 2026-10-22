import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';

void main() {
  Future<GlobalKey<SmoothPageReaderState>> mount(WidgetTester tester,
      {bool empty = false}) async {
    final key = GlobalKey<SmoothPageReaderState>();
    await tester.pumpWidget(MaterialApp(
        home: Center(
            child: SizedBox(
      width: empty ? 0 : 200,
      height: empty ? 0 : 300,
      child: SmoothPageReader(
          key: key,
          onPreviousTap: () {},
          onNextTap: () {},
          onCenterTap: () {},
          child: const ColoredBox(color: Colors.white)),
    ))));
    return key;
  }

  testWidgets('capture reserves the turn before yielding', (tester) async {
    final key = await mount(tester);
    var calls = 0;
    final first = key.currentState!.playTurn(
        forward: true,
        dispatchTurn: () async {
          calls++;
        });
    final second = key.currentState!.playTurn(
        forward: true,
        dispatchTurn: () async {
          calls++;
        });
    expect(key.currentState!.isAnimating, isTrue);
    await tester.pumpAndSettle();
    await Future.wait([first, second]);
    expect(calls, 1);
    expect(key.currentState!.isAnimating, isFalse);
  });

  testWidgets('unavailable snapshot still dispatches exactly once',
      (tester) async {
    final key = await mount(tester, empty: true);
    var calls = 0;
    final turn = key.currentState!.playTurn(
        forward: true,
        dispatchTurn: () async {
          calls++;
        });
    await tester.pumpAndSettle();
    await turn;
    expect(calls, 1);
    expect(key.currentState!.isAnimating, isFalse);
  });

  testWidgets('disposal during capture completes without dispatch',
      (tester) async {
    final key = await mount(tester);
    var calls = 0;
    final turn = key.currentState!.playTurn(
        forward: true,
        dispatchTurn: () async {
          calls++;
        });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await turn;
    expect(calls, 0);
  });

  testWidgets('disposal during animation completes without a late dispatch',
      (tester) async {
    final key = await mount(tester);
    var calls = 0;
    final turn = key.currentState!.playTurn(
        forward: true,
        dispatchTurn: () async {
          calls++;
        });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await turn;
    expect(calls, 0);
  });

  testWidgets('dispatch failures reach caller and release the turn',
      (tester) async {
    final key = await mount(tester);
    final failure = StateError('Navigation failed');
    final turn = key.currentState!.playTurn(
        forward: true,
        dispatchTurn: () async {
          throw failure;
        });
    final observed = expectLater(turn, throwsA(same(failure)));
    await tester.pumpAndSettle();
    await observed;
    expect(key.currentState!.isAnimating, isFalse);
  });

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
