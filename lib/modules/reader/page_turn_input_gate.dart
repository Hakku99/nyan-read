/// Turns raw page-turn inputs into at most one running turn plus one queued
/// turn, so a tap that lands during an animation is deferred, not dropped.
///
/// Pure (clock passed in) so the timing rules are unit-testable without
/// pumping the whole reader page.
class PageTurnInputGate {
  /// One physical tap can reach both the outer detector and a paragraph
  /// recognizer within the same pointer-up dispatch. 50ms covers that
  /// duplicate while staying well under the ~100ms floor of real repeated
  /// taps (the old 350ms window swallowed genuine fast taps — audit N11).
  static const Duration dedupWindow = Duration(milliseconds: 50);

  /// Minimum spacing between turn starts so snapshot capture can settle.
  static const Duration minInterval = Duration(milliseconds: 220);

  DateTime? _lastInputAt;
  DateTime? _lastStartAt;
  bool? _queuedForward;
  bool _busy = false;

  bool get busy => _busy;
  bool get hasQueued => _queuedForward != null;

  /// Records an input. Returns false when it is a duplicate of the last one.
  /// A newer input replaces an older queued one: only one turn ever waits.
  bool offer({required bool forward, required DateTime at}) {
    final last = _lastInputAt;
    if (last != null && at.difference(last) < dedupWindow) return false;
    _lastInputAt = at;
    _queuedForward = forward;
    return true;
  }

  /// Returns the direction to start now, or null. When null and a turn is
  /// still queued, [retryAfter] says how long until the interval allows it
  /// (zero while a turn is running: the caller retries on completion).
  ({bool? forward, Duration retryAfter}) take(DateTime now) {
    final queued = _queuedForward;
    if (queued == null || _busy) {
      return (forward: null, retryAfter: Duration.zero);
    }
    final last = _lastStartAt;
    final wait =
        last == null ? Duration.zero : minInterval - now.difference(last);
    if (wait > Duration.zero) return (forward: null, retryAfter: wait);
    _queuedForward = null;
    _lastStartAt = now;
    _busy = true;
    return (forward: queued, retryAfter: Duration.zero);
  }

  /// Marks the running turn finished. A cancelled or failed turn also drops
  /// the queue: the layout/route that cancelled it outranks the stale tap.
  void finish({required bool succeeded}) {
    _busy = false;
    if (!succeeded) _queuedForward = null;
  }

  void clearQueue() => _queuedForward = null;
}
