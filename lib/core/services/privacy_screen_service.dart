import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Tracks which screens are currently showing private-shelf content and, on
/// Android, mirrors that to `FLAG_SECURE` (screenshots, screen recording and
/// the recents thumbnail all go black).
///
/// This is a visibility gate, not encryption: it only hides what is on screen.
/// Holders are ref-counted by token so nested private screens (shelf → search
/// → reader) never clear the flag out from under each other.
class PrivacyScreenService {
  PrivacyScreenService({MethodChannel? channel, bool? nativeEnabled})
      : _channel = channel ?? const MethodChannel(channelName),
        _nativeEnabled = nativeEnabled ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  static const String channelName = 'com.example.nyan_read/privacy';

  final MethodChannel _channel;
  final bool _nativeEnabled;

  // Insertion order == the order screens were opened, which is also their
  // stacking order. Each completer fires when that holder is released.
  final LinkedHashMap<Object, Completer<void>> _holders =
      LinkedHashMap<Object, Completer<void>>.identity();
  bool _nativeSecure = false;
  final ValueNotifier<bool> _active = ValueNotifier<bool>(false);

  /// True while any holder is registered. Drives the iOS inactive cover.
  ValueListenable<bool> get active => _active;
  bool get hasHolders => _holders.isNotEmpty;

  void acquire(Object token) {
    if (_holders.containsKey(token)) return;
    _holders[token] = Completer<void>();
    _sync();
  }

  void release(Object token) {
    final completer = _holders.remove(token);
    if (completer == null) return;
    completer.complete();
    _sync();
  }

  /// Completes once every holder acquired after [token] has been released.
  ///
  /// Lets a lower screen wait for the screens stacked above it to finish their
  /// own exit (e.g. the reader saving progress) before it pops itself.
  Future<void> untilNewerReleased(Object token) {
    final keys = _holders.keys.toList(growable: false);
    final index = keys.indexWhere((k) => identical(k, token));
    if (index < 0) return Future<void>.value();
    return Future.wait([
      for (final k in keys.skip(index + 1)) _holders[k]!.future,
    ]).then((_) {});
  }

  void _sync() {
    final want = _holders.isNotEmpty;
    if (want != _nativeSecure) {
      _nativeSecure = want;
      if (_nativeEnabled) {
        // Fire-and-forget: the flag is best-effort and failures are logged.
        unawaited(_pushNative(want));
      }
    }
    // Deferred: holders release from State.dispose(), where notifying a
    // widget listener would hit "tree locked".
    scheduleMicrotask(() => _active.value = _holders.isNotEmpty);
  }

  Future<void> _pushNative(bool secure) async {
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } catch (e) {
      debugPrint('PrivacyScreenService.setSecure($secure) failed: $e');
    }
  }
}
