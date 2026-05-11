import 'dart:async';

import 'package:flutter/foundation.dart';

import '../brightness/brightness_orchestrator.dart';
import '../brightness/brightness_state.dart';

class BrightnessController extends ChangeNotifier {
  BrightnessController(this._orchestrator) {
    _stateListener = _syncFromOrchestrator;
    _orchestrator.addListener(_stateListener);
    _syncLocalState(_orchestrator.state);
  }

  final BrightnessOrchestrator _orchestrator;

  late final VoidCallback _stateListener;
  final ValueNotifier<double> uiBrightnessValue = ValueNotifier(0.5);
  final ValueNotifier<double> warmthValue = ValueNotifier(0.0);
  final ValueNotifier<bool> isAdjusting = ValueNotifier(false);
  final ValueNotifier<BrightnessState> _stateNotifier =
      ValueNotifier(BrightnessState.initial());

  Timer? _hudHideTimer;
  bool _isDisposed = false;

  ValueListenable<BrightnessState> get stateListenable => _stateNotifier;
  ValueListenable<double> get warmthListenable => warmthValue;
  BrightnessState get state => _stateNotifier.value;
  bool get followSystem => state.followSystem;
  double get warmth => warmthValue.value;

  Future<void> setWarmth(double value) async {
    await _orchestrator.setWarmth(value);
    if (_isDisposed) return;
    final normalized = _normalize(value);
    if (warmthValue.value != normalized) {
      warmthValue.value = normalized;
      notifyListeners();
    }
  }

  Future<void> toggleFollowSystem() async {
    if (followSystem) {
      await setBrightness(uiBrightnessValue.value);
    } else {
      await resetToSystem();
    }
  }

  Future<void> initialize() async {
    await _orchestrator.initialize();
    if (_isDisposed) return;
    _syncLocalState(_orchestrator.state);
  }

  void setFromSlider(double value) {
    final clamped = _normalize(value);
    _showHud();
    _syncLocalState(state.copyWith(
      mode: BrightnessMode.manual,
      uiBrightness: clamped,
    ));
    _orchestrator.previewBrightness(clamped);
  }

  Future<void> commitFromSlider(double value) async {
    final clamped = _normalize(value);
    _showHud();
    await _orchestrator.commitBrightness(clamped);
    if (_isDisposed) return;
    _syncLocalState(_orchestrator.state);
    _scheduleHudHide();
  }

  Future<void> setBrightness(double value) async {
    setFromSlider(value);
    await commitFromSlider(value);
  }

  void handleDragStart() {
    _showHud();
  }

  void handleDragUpdate(double dragDeltaY, double screenHeight) {
    _showHud();

    final sensitivity = 2.0 / screenHeight;
    final change = -(dragDeltaY * sensitivity);
    final nextBrightness = _normalize(uiBrightnessValue.value + change);

    _syncLocalState(state.copyWith(
      mode: BrightnessMode.manual,
      uiBrightness: nextBrightness,
    ));
    _orchestrator.previewBrightness(nextBrightness);
  }

  Future<void> handleInteractionEnd() async {
    await _orchestrator.commitBrightness(uiBrightnessValue.value);
    if (_isDisposed) return;
    _syncLocalState(_orchestrator.state);
    _scheduleHudHide();
  }

  Future<void> resetToSystem() async {
    _showHud();
    await _orchestrator.enableFollowSystem();
    if (_isDisposed) return;
    _syncLocalState(_orchestrator.state);
    _scheduleHudHide();
  }

  Future<void> shutdown() async {
    await _orchestrator.shutdown();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _hudHideTimer?.cancel();
    _orchestrator.removeListener(_stateListener);
    _orchestrator.dispose();
    uiBrightnessValue.dispose();
    warmthValue.dispose();
    isAdjusting.dispose();
    _stateNotifier.dispose();
    super.dispose();
  }

  void _showHud() {
    if (isAdjusting.value) return;
    isAdjusting.value = true;
    _hudHideTimer?.cancel();
    notifyListeners();
  }

  void _scheduleHudHide() {
    _hudHideTimer?.cancel();
    _hudHideTimer = Timer(const Duration(milliseconds: 800), () {
      if (_isDisposed) return;
      if (!isAdjusting.value) return;
      isAdjusting.value = false;
      notifyListeners();
    });
  }

  void _syncFromOrchestrator() {
    if (_isDisposed) return;
    _syncLocalState(_orchestrator.state);
  }

  void _syncLocalState(BrightnessState nextState) {
    final stateChanged = _stateNotifier.value != nextState;
    final brightnessChanged =
        uiBrightnessValue.value != nextState.clampedUiBrightness;
    final warmthChanged = warmthValue.value != _orchestrator.warmth;

    if (stateChanged) _stateNotifier.value = nextState;
    if (brightnessChanged) uiBrightnessValue.value = nextState.clampedUiBrightness;
    if (warmthChanged) warmthValue.value = _orchestrator.warmth;

    if (stateChanged || brightnessChanged || warmthChanged) {
      notifyListeners();
    }
  }

  double _normalize(double value) => value.clamp(0.0, 1.0).toDouble();
}

