import 'dart:async';

class LifecycleRegistry {
  final List<Timer> _timers = [];
  final List<StreamSubscription> _subscriptions = [];
  bool _isDisposed = false;

  /// 添加并跟踪一个 Timer
  T registerTimer<T extends Timer>(T timer) {
    if (_isDisposed) {
      timer.cancel(); // 万一在刚销毁时挂载，直接拦截
      return timer;
    }
    _timers.add(timer);
    return timer;
  }

  void registerSubscription(StreamSubscription sub) {
    if (_isDisposed) {
      sub.cancel();
      return;
    }
    _subscriptions.add(sub);
  }

  /// 一键阻断
  void disposeAll() {
    _isDisposed = true;
    for (var timer in _timers) {
      if (timer.isActive) timer.cancel();
    }
    _timers.clear();

    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
