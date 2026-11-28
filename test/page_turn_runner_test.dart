import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/modules/reader/page_turn_input_gate.dart';
import 'package:nyan_read/modules/reader/reader_engine/page_turn_request.dart';

/// Drives a [PageTurnRunner] with hand-completed dispatches. testWidgets
/// fakes the deadline/retry timers; `tester.pump` advances them.
class _Harness {
  _Harness() {
    runner = PageTurnRunner(
      dispatch: (forward, request) {
        final turn = Completer<void>();
        turns.add((forward: forward, request: request, done: turn));
        return turn.future;
      },
      canStart: () => !blocked,
      onFailure: failures.add,
      clock: () => now,
    );
  }

  late final PageTurnRunner runner;
  final turns =
      <({bool forward, PageTurnRequest request, Completer<void> done})>[];
  final failures = <Object>[];
  Duration now = Duration.zero;
  bool blocked = false;

  bool get running => runner.running.value;
}

void main() {
  testWidgets('cancelled presentation holds input until navigation lands',
      (tester) async {
    final h = _Harness();
    h.runner.offer(forward: true);
    expect(h.running, isTrue);

    h.runner.cancelPresentation();
    await tester.pump();
    expect(h.running, isTrue, reason: 'animateTo is still moving the page');

    h.turns.single.done.complete();
    await tester.pump();
    expect(h.running, isFalse);
    h.runner.dispose(); // ahead of the pending-timer check
  });

  testWidgets('deadline releases input when an engine never settles',
      (tester) async {
    final h = _Harness();
    h.runner.offer(forward: true);
    await tester.pump(h.runner.deadline);
    expect(h.running, isFalse);
    expect(h.failures, isEmpty);
    h.runner.dispose(); // ahead of the pending-timer check
  });

  testWidgets('a late completion does not release a newer turn',
      (tester) async {
    final h = _Harness();
    h.runner.offer(forward: true);
    await tester.pump(h.runner.deadline);
    h.now = const Duration(seconds: 4);
    h.runner.offer(forward: true);
    expect(h.turns, hasLength(2));

    h.turns.first.done.complete();
    await tester.pump();
    expect(h.running, isTrue, reason: 'turn 2 is still in flight');
    h.runner.dispose(); // ahead of the pending-timer check
  });

  testWidgets('a queued turn starts after the running one lands',
      (tester) async {
    final h = _Harness();
    h.runner.offer(forward: true);
    h.now = const Duration(milliseconds: 100);
    h.runner.offer(forward: false);
    expect(h.turns, hasLength(1));

    h.now = const Duration(milliseconds: 400);
    h.turns.single.done.complete();
    await tester.pump();
    expect(h.turns, hasLength(2));
    expect(h.turns.last.forward, isFalse);
    h.runner.dispose(); // ahead of the pending-timer check
  });

  testWidgets('a blocked runner drops the queue instead of starting',
      (tester) async {
    final h = _Harness();
    h.runner.offer(forward: true);
    h.now = const Duration(milliseconds: 100);
    h.runner.offer(forward: true);
    h.blocked = true; // e.g. exiting, or text selected meanwhile
    h.now = const Duration(milliseconds: 400);
    h.turns.single.done.complete();
    await tester.pump(const Duration(seconds: 1));
    expect(h.turns, hasLength(1));
    expect(h.running, isFalse);
    h.runner.dispose(); // ahead of the pending-timer check
  });

  testWidgets('cancelQueue also stops a pending interval retry',
      (tester) async {
    final h = _Harness();
    h.runner.offer(forward: true);
    h.turns.single.done.complete();
    await tester.pump();
    h.now = const Duration(milliseconds: 100);
    h.runner.offer(forward: true); // waits out the 220ms interval
    h.runner.cancelQueue();
    await tester.pump(const Duration(seconds: 1));
    expect(h.turns, hasLength(1));
    h.runner.dispose(); // ahead of the pending-timer check
  });

  testWidgets('a failure after cancel is still reported', (tester) async {
    final h = _Harness();
    h.runner.offer(forward: true);
    h.runner.cancelPresentation();
    h.turns.single.done.completeError(StateError('engine'));
    await tester.pump();
    expect(h.failures, hasLength(1));
    expect(h.running, isFalse);
    h.runner.dispose(); // ahead of the pending-timer check
  });

  testWidgets('settled waits for the turn in flight', (tester) async {
    final h = _Harness();
    expect(h.runner.settled(), completes);
    h.runner.offer(forward: true);
    var settled = false;
    unawaited(h.runner.settled().then((_) => settled = true));
    await tester.pump();
    expect(settled, isFalse);
    h.turns.single.done.complete();
    await tester.pump();
    expect(settled, isTrue);
    h.runner.dispose(); // ahead of the pending-timer check
  });
}
