import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'page_turn_pipeline_test.dart' show mount;

void main() {
  testWidgets('slow dispatch finishes silently and navigation still completes',
      (tester) async {
    final key = await mount(tester, capture: () async => null);
    var moved = false;
    final turn = key.currentState!.playTurn(
      forward: true,
      dispatchTurn: () async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        moved = true;
      },
    );
    await tester.pump(const Duration(milliseconds: 200)); // > prepareTimeout
    await turn; // must not throw
    expect(moved, isFalse, reason: 'navigation still in flight');
    await tester.pump(const Duration(milliseconds: 300));
    expect(moved, isTrue);
  });

  for (final error in <Object>[StateError('boom'), TimeoutException('inner')]) {
    testWidgets('dispatch failure ${error.runtimeType} still propagates',
        (tester) async {
      final key = await mount(tester, capture: () async => null);
      final turn = key.currentState!.playTurn(
        forward: true,
        dispatchTurn: () async => throw error,
      );
      await expectLater(turn, throwsA(same(error)));
    });
  }
}
