import 'dart:async';

import 'package:flutter/widgets.dart';

import 'brightness_repository.dart';
import 'brightness_state.dart';
import 'overlay_brightness_policy.dart';
import 'system_brightness_adapter.dart';

class BrightnessOrchestrator extends ChangeNotifier with WidgetsBindingObserver {
  BrightnessOrchestrator({
    required BrightnessRepository repository,
    required SystemBrightnessAdapter systemAdapter,
    OverlayBrightnessPolicy? overlayPolicy,
  })  : _repository = repository,
        _systemAdapter = systemAdapter,
        _overlayPolicy = overlayPolicy ?? const OverlayBrightnessPolicy();

  final BrightnessRepository _repository;
  final SystemBrightnessAdapter _systemAdapter;
  final OverlayBrightnessPolicy _overlayPolicy;

  BrightnessState _state = BrightnessState.initial();
  StreamSubscription<double>? _systemBrightnessSubscription;

  bool _initialized = false;
  bool _isDisposed = false;
  bool _isShuttingDown = false;
  bool _isApplyingBrightness = false;
  double? _queuedManualTarget;
  double? _ignoredSystemBrightness;

  BrightnessState get state => _state;
  double get warmth => _repository.warmth;

  Future<void> setWarmth(double value) async {
    await _repository.saveWarmth(value);
  }

  Future<void> initialize() async {
    if (_initialized || _isDisposed) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    final currentSystemBrightness = await _safeCurrentBrightness();
    final manualBrightness = await _repository.loadManualBrightness();

    _setState(BrightnessState(
      mode: manualBrightness == null
          ? BrightnessMode.followSystem
          : BrightnessMode.manual,
      uiBrightness: manualBrightness ?? currentSystemBrightness,
      hardwareFloor: BrightnessState.defaultHardwareFloor,
      originalSystemBrightness: currentSystemBrightness,
      lastObservedSystemBrightness: currentSystemBrightness,
      lastAppliedSystemBrightness: null,
    ));

    _systemBrightnessSubscription =
        _systemAdapter.brightnessChanges().listen(_handleSystemBrightnessChange);

    if (!_state.followSystem) {
      await _applyManualBrightness(force: true);
    }
  }

  void previewBrightness(double brightness) {
    if (_isDisposed) return;
    final normalizedBrightness = _normalize(brightness);
    _setState(_state.copyWith(
      mode: BrightnessMode.manual,
      uiBrightness: normalizedBrightness,
    ));
    _scheduleManualApply();
  }

  Future<void> commitBrightness([double? brightness]) async {
    if (_isDisposed) return;
    final normalizedBrightness =
        _normalize(brightness ?? _state.clampedUiBrightness);
    _setState(_state.copyWith(
      mode: BrightnessMode.manual,
      uiBrightness: normalizedBrightness,
    ));
    await _repository.saveManualBrightness(normalizedBrightness);
    _scheduleManualApply();
  }

  Future<void> enableFollowSystem() async {
    if (_isDisposed) return;

    final wasManual = !_state.followSystem;
    _queuedManualTarget = null;
    await _repository.clearManualBrightness();

    if (wasManual) {
      await _safeResetSystemBrightness();
    }

    final currentSystemBrightness = await _safeCurrentBrightness();
    _setState(_state.copyWith(
      mode: BrightnessMode.followSystem,
      uiBrightness: currentSystemBrightness,
      lastObservedSystemBrightness: currentSystemBrightness,
      lastAppliedSystemBrightness: null,
    ));
  }

  Future<void> restoreOriginalBrightness() async {
    if (_isDisposed) return;
    if (!_state.isSystemOverrideActive &&
        _state.mode != BrightnessMode.manual) {
      return;
    }

    final originalBrightness = _state.originalSystemBrightness;
    if (originalBrightness == null) return;

    _ignoredSystemBrightness = originalBrightness;
    await _safeSetSystemBrightness(originalBrightness);
    _setState(_state.copyWith(
      lastObservedSystemBrightness: originalBrightness,
      lastAppliedSystemBrightness: null,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_handleBackgrounding());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_handleResume());
    }
  }

  Future<void> shutdown() async {
    if (_isShuttingDown) return;
    _isShuttingDown = true;
    await _systemBrightnessSubscription?.cancel();
    _systemBrightnessSubscription = null;
    WidgetsBinding.instance.removeObserver(this);
    await restoreOriginalBrightness();
    _isDisposed = true;
  }

  @override
  void dispose() {
    unawaited(shutdown());
    super.dispose();
  }

  Future<void> _handleBackgrounding() async {
    if (_state.followSystem) return;
    await restoreOriginalBrightness();
  }

  Future<void> _handleResume() async {
    if (_state.followSystem) return;
    await _applyManualBrightness(force: true);
  }

  void _handleSystemBrightnessChange(double systemBrightness) {
    if (_isDisposed) return;

    if (_shouldIgnoreSystemBrightness(systemBrightness)) {
      _setState(_state.copyWith(
        lastObservedSystemBrightness: systemBrightness,
      ));
      return;
    }

    if (_state.followSystem) {
      _setState(_state.copyWith(
        uiBrightness: systemBrightness,
        lastObservedSystemBrightness: systemBrightness,
        lastAppliedSystemBrightness: null,
      ));
      return;
    }

    _setState(_state.copyWith(
      mode: BrightnessMode.followSystem,
      uiBrightness: systemBrightness,
      lastObservedSystemBrightness: systemBrightness,
      lastAppliedSystemBrightness: null,
    ));
    unawaited(_repository.clearManualBrightness());
  }

  void _scheduleManualApply() {
    if (_state.followSystem || _isDisposed) return;

    _queuedManualTarget = _state.targetSystemBrightness;
    if (_isApplyingBrightness) return;
    unawaited(_drainManualApplyQueue());
  }

  Future<void> _drainManualApplyQueue() async {
    _isApplyingBrightness = true;
    try {
      while (!_isDisposed && !_state.followSystem && _queuedManualTarget != null) {
        final target = _queuedManualTarget!;
        _queuedManualTarget = null;
        await _applyManualBrightness(target: target);
      }
    } finally {
      _isApplyingBrightness = false;
    }
  }

  Future<void> _applyManualBrightness({
    bool force = false,
    double? target,
  }) async {
    if (_state.followSystem || _isDisposed) return;

    final effectiveTarget = target ?? _state.targetSystemBrightness;
    final currentApplied = _state.lastAppliedSystemBrightness;
    if (!force &&
        currentApplied != null &&
        (currentApplied - effectiveTarget).abs() < 0.001) {
      return;
    }

    _ignoredSystemBrightness = effectiveTarget;
    await _safeSetSystemBrightness(effectiveTarget);
    _setState(_state.copyWith(
      lastObservedSystemBrightness: effectiveTarget,
      lastAppliedSystemBrightness: effectiveTarget,
    ));
  }

  bool _shouldIgnoreSystemBrightness(double systemBrightness) {
    final ignoredBrightness = _ignoredSystemBrightness;
    if (ignoredBrightness == null) return false;
    final shouldIgnore = (ignoredBrightness - systemBrightness).abs() < 0.001;
    if (shouldIgnore) {
      _ignoredSystemBrightness = null;
    }
    return shouldIgnore;
  }

  Future<double> _safeCurrentBrightness() async {
    try {
      return await _systemAdapter.currentBrightness();
    } catch (_) {
      return _state.lastObservedSystemBrightness ?? _state.clampedUiBrightness;
    }
  }

  Future<void> _safeSetSystemBrightness(double brightness) async {
    try {
      await _systemAdapter.setSystemBrightness(brightness);
    } catch (_) {}
  }

  Future<void> _safeResetSystemBrightness() async {
    try {
      await _systemAdapter.resetSystemBrightness();
    } catch (_) {}
  }

  void _setState(BrightnessState nextState) {
    final overlayOpacity = _overlayPolicy.calculate(
      uiBrightness: nextState.clampedUiBrightness,
      hardwareFloor: nextState.normalizedHardwareFloor,
    );
    final normalizedState = nextState.copyWith(
      uiBrightness: nextState.clampedUiBrightness,
      hardwareFloor: nextState.normalizedHardwareFloor,
      lastAppliedSystemBrightness: nextState.followSystem
          ? null
          : nextState.lastAppliedSystemBrightness,
    );

    if (_state.mode == normalizedState.mode &&
        (_state.clampedUiBrightness - normalizedState.clampedUiBrightness).abs() <
            0.001 &&
        (_state.hardwareFloor - normalizedState.hardwareFloor).abs() < 0.001 &&
        _state.originalSystemBrightness ==
            normalizedState.originalSystemBrightness &&
        _state.lastObservedSystemBrightness ==
            normalizedState.lastObservedSystemBrightness &&
        _state.lastAppliedSystemBrightness ==
            normalizedState.lastAppliedSystemBrightness &&
        (_state.overlayOpacity - overlayOpacity).abs() < 0.001) {
      return;
    }

    _state = normalizedState;
    notifyListeners();
  }

  double _normalize(double brightness) => brightness.clamp(0.0, 1.0).toDouble();
}
