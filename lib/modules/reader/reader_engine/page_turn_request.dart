import 'dart:async';

/// Cancellation of presentation work never rolls back an accepted navigation.
final class PageTurnRequest {
  final _cancelled = Completer<void>();
  bool get isActive => !_cancelled.isCompleted;

  void cancel() {
    if (isActive) _cancelled.complete();
  }

  void checkActive() {
    if (!isActive) throw const PageTurnCancelled();
  }

  /// Observes late failures even when cancellation wins the race.
  Future<T> wait<T>(Future<T> operation) => Future.any([
        operation,
        _cancelled.future.then<T>((_) => throw const PageTurnCancelled()),
      ]);
}

final class PageTurnCancelled implements Exception {
  const PageTurnCancelled();
}
