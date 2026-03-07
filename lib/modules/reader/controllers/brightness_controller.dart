import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../../../../core/services/reader_preferences_service.dart';

class BrightnessController with WidgetsBindingObserver {
  // 核心 UI 驱动状态：绝对全量程 (0.00 到 1.00)
  final ValueNotifier<double> uiBrightnessValue = ValueNotifier(0.5);

  // 统一 HUD 悬浮窗显示状态
  final ValueNotifier<bool> isAdjusting = ValueNotifier(false);

  final ReaderPreferencesService _prefs;

  Timer? _hudHideTimer;
  Timer? _debounceTimer;
  StreamSubscription<double>? _systemBrightnessSubscription;
  double _lastCommittedLevel = -1.0;
  double? _lastAppliedBrightness;
  double? _originalSystemBrightness;
  bool _isDisposed = false;
  bool _isActiveReader = true;
  bool _isFlutterUpdating = false;

  BrightnessController(this._prefs) {
    WidgetsBinding.instance.addObserver(this);
    _initBrightnessTracking();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _restoreOriginalBrightness();
    } else if (state == AppLifecycleState.resumed && _isActiveReader) {
      _applyBrightnessState();
    }
  }

  /// 异步初始化：连接物理世界与软件感知的单向数据流桥梁
  Future<void> _initBrightnessTracking() async {
    // 监听全局设定变更
    _prefs.addListener(_handlePrefsChange);

    // 监听外部系统强制干扰
    _systemBrightnessSubscription = ScreenBrightness()
        .onCurrentBrightnessChanged
        .listen(_onSystemBrightnessInterfered);

    await _saveOriginalBrightness();

    // 首屏拉取
    try {
      final currentPhysical = await ScreenBrightness().current;
      uiBrightnessValue.value = currentPhysical;
    } catch (_) {}

    _applyBrightnessState();
  }

  Future<void> _saveOriginalBrightness() async {
    try {
      _originalSystemBrightness = await ScreenBrightness().current;
    } catch (_) {}
  }

  Future<void> _restoreOriginalBrightness() async {
    if (_originalSystemBrightness != null) {
      try {
        _isFlutterUpdating = true;
        _lastCommittedLevel = _originalSystemBrightness!;
        await ScreenBrightness()
            .setScreenBrightness(_originalSystemBrightness!);
      } catch (_) {
      } finally {
        _isFlutterUpdating = false;
      }
    } else {
      try {
        _isFlutterUpdating = true;
        _lastCommittedLevel = -1.0;
        await ScreenBrightness().resetScreenBrightness();
      } catch (_) {
      } finally {
        _isFlutterUpdating = false;
      }
    }
  }

  /// 来自操作系统的抢占干涉
  void _onSystemBrightnessInterfered(double systemLevel) {
    if (_isDisposed) return;
    if (_lastCommittedLevel < 0) return;
    if (_isFlutterUpdating) return;

    if ((systemLevel - _lastCommittedLevel).abs() > 0.05) {
      if (_prefs.brightness != null) {
        _lastCommittedLevel = -1.0;
        // 退回跟随系统
        _prefs.setBrightness(null);
        uiBrightnessValue.value = systemLevel;
      }
    }
  }

  /// Preferences 变化事件 (滑动 slider 或手势导致的设定变化都会走到这里)
  void _handlePrefsChange() {
    if (_prefs.brightness != null &&
        _prefs.brightness != uiBrightnessValue.value) {
      uiBrightnessValue.value = _prefs.brightness!;
    }

    // 100ms Debounce 防抖，组装一波 IO
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      _applyBrightnessState();
    });
  }

  /// 执行最后的单向流同步：计算 -> Native
  Future<void> _applyBrightnessState() async {
    if (_isDisposed) return;

    if (_prefs.brightness == null) {
      await _restoreOriginalBrightness();
      return;
    }

    try {
      final b = _prefs.brightness!;
      final perceptual = _prefs.getPerceptualBrightness(b);
      final minPhys = _prefs.minPhysicalBrightness;

      double systemLevel = perceptual > minPhys ? perceptual : minPhys;

      // 新增 last applied filter Threshold
      if (_lastAppliedBrightness != null &&
          (systemLevel - _lastAppliedBrightness!).abs() < 0.01) {
        return;
      }

      _lastAppliedBrightness = systemLevel;
      _lastCommittedLevel = systemLevel;

      try {
        _isFlutterUpdating = true;
        await ScreenBrightness().setScreenBrightness(systemLevel);
      } finally {
        _isFlutterUpdating = false;
      }
    } catch (_) {}
  }

  void _showHud() {
    isAdjusting.value = true;
    _hudHideTimer?.cancel();
  }

  // 统一的手势/滑动结束 (隐藏 HUD)
  void handleInteractionEnd() {
    // 阶段一：持久化落盘，移除每帧的 I/O 写盘
    _prefs.setBrightness(uiBrightnessValue.value);

    _hudHideTimer?.cancel();
    _hudHideTimer = Timer(const Duration(milliseconds: 800), () {
      if (_isDisposed) return;
      isAdjusting.value = false;
    });
  }

  /// ========== 对外交互暴露 (手势 & 菜单滑块) ==========

  /// 接受 BrightnessManager 彻底掏空后的手势回调
  void handleDragStart() {
    _showHud();
  }

  void handleDragUpdate(double dragDeltaY, double screenHeight) {
    _showHud();

    final sensitivity = 2.0 / screenHeight;
    final change = -(dragDeltaY * sensitivity);

    // 阶段一：仅基于当前内存值进行增减计算
    final currentBase = uiBrightnessValue.value;
    final newBrightness = (currentBase + change).clamp(0.0, 1.0);

    // 1. 无阻塞：直接驱动 120Hz HUD
    uiBrightnessValue.value = newBrightness;

    // 2. 将计算结果丢进数据源管线。
    // 阶段一：已移除此处的 _prefs.setBrightness(newBrightness); 以防 I/O 绞肉机
  }

  /// Called from the slider in ReaderMenu.
  void setFromSlider(double value) {
    _showHud();
    final clamped = value.clamp(0.0, 1.0);
    uiBrightnessValue.value = clamped;
    _prefs.setBrightness(clamped);
  }

  /// Resets screen brightness to OS control
  Future<void> resetToSystem() async {
    await _prefs.setBrightness(null);
  }

  /// 控制器销毁
  void dispose() {
    _isActiveReader = false;
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _prefs.removeListener(_handlePrefsChange);
    _systemBrightnessSubscription?.cancel();
    _restoreOriginalBrightness();

    _debounceTimer?.cancel();
    _hudHideTimer?.cancel();

    uiBrightnessValue.dispose();
    isAdjusting.dispose();
  }
}
