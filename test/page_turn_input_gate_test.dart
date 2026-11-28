import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/modules/reader/page_turn_input_gate.dart';

void main() {
  Duration at(int ms) => Duration(milliseconds: ms);

  test('duplicate dispatch of one tap is dropped', () {
    final gate = PageTurnInputGate();
    expect(gate.offer(forward: true, at: at(0)), isTrue);
    expect(gate.offer(forward: true, at: at(5)), isFalse);
  });

  test('tap during a running turn is queued and runs after it', () {
    final gate = PageTurnInputGate();
    gate.offer(forward: true, at: at(0));
    expect(gate.take(at(0)).forward, isTrue);

    // Second real tap 120ms later, while the first turn animates.
    expect(gate.offer(forward: true, at: at(120)), isTrue);
    expect(gate.take(at(120)).forward, isNull);

    gate.finish(succeeded: true);
    // Turn ended at 300ms, past the min interval: queued tap starts.
    expect(gate.take(at(300)).forward, isTrue);
    expect(gate.hasQueued, isFalse);
  });

  test('queued tap waits out the min interval after a fast turn', () {
    final gate = PageTurnInputGate();
    gate.offer(forward: true, at: at(0));
    gate.take(at(0));
    gate.offer(forward: false, at: at(80));
    gate.finish(succeeded: true);

    final early = gate.take(at(100));
    expect(early.forward, isNull);
    expect(early.retryAfter, const Duration(milliseconds: 120));
    expect(gate.take(at(220)).forward, isFalse);
  });

  test('only the latest of several queued taps survives', () {
    final gate = PageTurnInputGate();
    gate.offer(forward: true, at: at(0));
    gate.take(at(0));
    gate.offer(forward: true, at: at(100));
    gate.offer(forward: false, at: at(200));
    gate.finish(succeeded: true);
    expect(gate.take(at(400)).forward, isFalse);
    expect(gate.take(at(800)).forward, isNull);
  });

  test('cancelled turn drops the queue', () {
    final gate = PageTurnInputGate();
    gate.offer(forward: true, at: at(0));
    gate.take(at(0));
    gate.offer(forward: true, at: at(100));
    gate.finish(succeeded: false);
    expect(gate.take(at(400)).forward, isNull);
  });

  test('running is listenable and cleared on every finish', () {
    final gate = PageTurnInputGate();
    addTearDown(gate.dispose);
    final seen = <bool>[];
    gate.running.addListener(() => seen.add(gate.running.value));
    gate.offer(forward: true, at: at(0));
    gate.take(at(0));
    gate.finish(succeeded: true);
    gate.offer(forward: true, at: at(400));
    gate.take(at(400));
    gate.finish(succeeded: false);
    expect(seen, [true, false, true, false]);
  });
}
