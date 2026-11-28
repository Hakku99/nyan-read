import 'dart:async';

import 'package:flutter/foundation.dart';

import 'reader_engine/page_turn_request.dart';

/// Turns raw page-turn inputs into at most one running turn plus one queued
/// turn, so a tap that lands during an animation is deferred, not dropped.
///
/// Pure (clock passed in) so the timing rules are unit-testable without
/// pumping the whole reader page. Times are offsets on a monotonic clock
/// (a `Stopwatch`), never wall-clock `DateTime`s, which can jump backward.
class PageTurnInputGate {
  /// One physical tap can reach both the outer detector and a paragraph
  /// recognizer within the same pointer-up dispatch. 50ms covers that
  /// duplicate while staying well under the ~100ms floor of real repeated
  /// taps (the old 350ms window swallowed genuine fast taps — audit N11).
  static const Duration dedupWindow = Duration(milliseconds: 50);

  /// Minimum spacing between turn starts so snapshot capture can settle.
  static const Duration minInterval = Duration(milliseconds: 220);

  Duration? _lastInputAt;
  Duration? _lastStartAt;
  bool? _queuedForward;
  final ValueNotifier<bool> _running = ValueNotifier(false);

  /// True while a started turn is in flight. The reader shields the text
  /// list from touches meanwhile (audit N17): in scroll mode a touch-down
  /// holds the Scrollable, which ends the turn's animateTo halfway yet still
  /// reports success, leaving a misaligned page.
  ValueListenable<bool> get running => _running;
  bool get hasQueued => _queuedForward != null;

  /// Records an input. Returns false when it is a duplicate of the last one.
  /// A newer input replaces an older queued one: only one turn ever waits.
  bool offer({required bool forward, required Duration at}) {
    final last = _lastInputAt;
    if (last != null && at - last < dedupWindow) return false;
    _lastInputAt = at;
    _queuedForward = forward;
    return true;
  }

  /// Returns the direction to start now, or null. When null and a turn is
  /// still queued, [retryAfter] says how long until the interval allows it
  /// (zero while a turn is running: the caller retries on completion).
  ({bool? forward, Duration retryAfter}) take(Duration now) {
    final queued = _queuedForward;
    if (queued == null || _running.value) {
      return (forward: null, retryAfter: Duration.zero);
    }
    final last = _lastStartAt;
    final wait =
        last == null ? Duration.zero : minInterval - (now - last);
    if (wait > Duration.zero) return (forward: null, retryAfter: wait);
    _queuedForward = null;
    _lastStartAt = now;
    _running.value = true;
    return (forward: queued, retryAfter: Duration.zero);
  }

  /// Marks the running turn finished. A cancelled or failed turn also drops
  /// the queue: the layout/route that cancelled it outranks the stale tap.
  void finish({required bool succeeded}) {
    _running.value = false;
    if (!succeeded) _queuedForward = null;
  }

  void clearQueue() => _queuedForward = null;

  void dispose() => _running.dispose();
}

/// Runs page turns through a [PageTurnInputGate]: starts queued turns, arms
/// the deadline, waits out cancellation and releases input. Lives outside
/// the reader widget so this lifecycle is unit-testable.
class PageTurnRunner {
  PageTurnRunner({
    required Future<void> Function(bool forward, PageTurnRequest request)
        dispatch,
    required bool Function() canStart,
    required void Function(Object error) onFailure,
    Duration Function()? clock,
    this.deadline = const Duration(seconds: 3),
  })  : _dispatch = dispatch,
        _canStart = canStart,
        _onFailure = onFailure,
        _clock = clock ?? _monotonicClock();

  /// Releases input even if an engine never settles a dispatch.
  final Duration deadline;

  final Future<void> Function(bool forward, PageTurnRequest request) _dispatch;
  // False drops the queue instead of starting: a selection owns the page,
  // and nothing may move it under the exit save.
  final bool Function() _canStart;
  final void Function(Object error) _onFailure;
  // Monotonic: a wall-clock jump must not stall or delay queued turns.
  final Duration Function() _clock;
  final PageTurnInputGate _gate = PageTurnInputGate();

  PageTurnRequest? _request;
  Completer<void>? _turnDone;
  Timer? _deadlineTimer;
  Timer? _retryTimer;
  bool _disposed = false;

  static Duration Function() _monotonicClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  ValueListenable<bool> get running => _gate.running;

  /// Completes once the turn in flight (if any) has landed, failed or hit
  /// its deadline. Never throws.
  Future<void> settled() => _turnDone?.future ?? Future<void>.value();

  void offer({required bool forward}) {
    if (_gate.offer(forward: forward, at: _clock())) _drain();
  }

  /// Drops any waiting turn: exits, sheets and chrome outrank a stale tap.
  void cancelQueue() {
    _gate.clearQueue();
    _retryTimer?.cancel();
  }

  /// Cancels the running turn's presentation. Its navigation still lands,
  /// and input stays held until it does.
  void cancelPresentation() => _request?.cancel();

  void _drain() {
    if (_disposed) return;
    if (!_canStart()) {
      cancelQueue();
      return;
    }
    final next = _gate.take(_clock());
    final forward = next.forward;
    if (forward == null) {
      if (next.retryAfter > Duration.zero) {
        _retryTimer?.cancel();
        _retryTimer = Timer(next.retryAfter, _drain);
      }
      return;
    }
    final request = _request = PageTurnRequest();
    _turnDone = Completer<void>();
    final dispatch = Future<void>.sync(() => _dispatch(forward, request));
    _deadlineTimer?.cancel();
    _deadlineTimer = Timer(deadline, () {
      request.cancel();
      _release(request, succeeded: false);
    });
    unawaited(_complete(dispatch, request));
  }

  Future<void> _complete(Future<void> dispatch, PageTurnRequest request) async {
    var succeeded = false;
    try {
      await request.wait(dispatch);
      succeeded = true;
    } on PageTurnCancelled {
      // A changed layout, route or deadline supersedes this presentation, but
      // never rolls back accepted navigation: keep the gate busy (and the
      // scroll-mode list shielded) until it lands, or a touch would stop its
      // animateTo halfway (audit N17).
      try {
        await dispatch;
      } catch (error) {
        _report(error);
      }
    } catch (error) {
      _report(error);
    }
    _release(request, succeeded: succeeded);
  }

  void _report(Object error) {
    if (!_disposed) _onFailure(error);
  }

  void _release(PageTurnRequest request, {required bool succeeded}) {
    request.cancel();
    // A late completion cannot unlock a newer turn or cancel its deadline.
    if (_disposed || !identical(_request, request)) return;
    _deadlineTimer?.cancel();
    _request = null;
    _gate.finish(succeeded: succeeded);
    _completeTurnDone();
    _drain();
  }

  void _completeTurnDone() {
    final done = _turnDone;
    if (done != null && !done.isCompleted) done.complete();
  }

  void dispose() {
    _disposed = true;
    _request?.cancel();
    _deadlineTimer?.cancel();
    _retryTimer?.cancel();
    _completeTurnDone();
    _gate.dispose();
  }
}
