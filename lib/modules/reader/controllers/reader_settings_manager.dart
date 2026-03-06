import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../../../core/services/reader_preferences_service.dart';
import '../../../core/services/service_locator.dart';
import '../reader_engine/reader_engine.dart';
import '../../../core/utils/lifecycle_registry.dart';
import 'brightness_controller.dart';

class ReaderSettingsManager {
  final ReaderEngine engine;
  final LifecycleRegistry lifecycle;
  final VoidCallback onSettingsChanged;

  double _fontSize = 18.0;
  double _lineHeight = 1.5;
  double _brightness = 1.0;
  Color _backgroundColor = const Color(0xFFFDFCF8);
  Color _textColor = const Color(0xFF4A453E);
  bool _followSystem = false;
  BrightnessController? _brightnessControllerRef;

  /// 按需说明：不使用 lifecycle.registerSubscription，
  /// 而是用命名引用来防止多次调用 toggleFollowSystem 日累积订阅。
  StreamSubscription<double>? _followSystemSubscription;

  /// 监听 BrightnessController 的 uiBrightnessValue 变化的移除函数引用
  VoidCallback? _brightnessValueListener;

  ReaderSettingsManager({
    required this.engine,
    required this.lifecycle,
    required this.onSettingsChanged,
  }) {
    _loadPreferences();
  }

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  double get brightness => _brightness;
  Color get backgroundColor => _backgroundColor;
  Color get textColor => _textColor;
  bool get followSystem => _followSystem;

  void _loadPreferences() {
    final prefs = getIt<ReaderPreferencesService>();
    _fontSize = prefs.fontSize;
    _lineHeight = prefs.lineHeight;
    _backgroundColor = prefs.backgroundColor;

    // Load or sync brightness
    _brightness = prefs.brightness ?? 0.5;
    if (prefs.brightness == null) {
      ScreenBrightness().current.then((b) {
        _brightness = b;
        onSettingsChanged();
      });
    }

    _updateEngineConfig();
  }

  void attachBrightnessController(BrightnessController bc) {
    _brightnessControllerRef = bc;
    bc.uiBrightnessValue.value = _brightness;

    // 修复漏洞 #1：监听系统干预导致的亮度变化，同步回_brightness防止 Slider 错位。
    // 当用户拉下系统控制中心改变亮度时，_onSystemBrightnessInterfered
    // 会更新 uiBrightnessValue，这里同步回本地缓存使 Slider 始终显示正确值。
    _brightnessValueListener = () {
      _brightness = bc.uiBrightnessValue.value;
      onSettingsChanged();
    };
    bc.uiBrightnessValue.addListener(_brightnessValueListener!);
  }

  void detachBrightnessController() {
    if (_brightnessControllerRef != null && _brightnessValueListener != null) {
      _brightnessControllerRef!.uiBrightnessValue
          .removeListener(_brightnessValueListener!);
    }
    _brightnessValueListener = null;
    _brightnessControllerRef = null;
  }

  void _updateEngineConfig() {
    final isDark = _backgroundColor.computeLuminance() < 0.5;
    _textColor = isDark ? const Color(0xFFE6E2D8) : const Color(0xFF4A453E);

    final prefs = getIt<ReaderPreferencesService>();
    engine.setConfig(ReaderConfig(
      backgroundColor: _backgroundColor,
      textColor: _textColor,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      pageTurnMode: prefs.pageTurnMode,
      pageAnimation: prefs.pageAnimation,
    ));
  }

  void setFontSize(double size) {
    _fontSize = size;
    _updateEngineConfig();
    getIt<ReaderPreferencesService>().setFontSize(size);
    onSettingsChanged();
  }

  void setLineHeight(double height) {
    _lineHeight = height;
    _updateEngineConfig();
    getIt<ReaderPreferencesService>().setLineHeight(height);
    onSettingsChanged();
  }

  void setBackground(Color color) {
    _backgroundColor = color;
    _updateEngineConfig();
    getIt<ReaderPreferencesService>().setBackgroundColor(color);
    onSettingsChanged();
  }

  Future<void> setBrightness(double b) async {
    if (_followSystem) {
      _followSystem = false;
    }
    _brightness = b;
    _brightnessControllerRef?.setFromSlider(b);
    await getIt<ReaderPreferencesService>().setBrightness(b);
    onSettingsChanged();
  }

  Future<void> toggleFollowSystem() async {
    // 修复漏洞 #4：先取消上一次的订阅，应对用户快速反复拨动 Toggle 导致的订阅累积。
    await _followSystemSubscription?.cancel();
    _followSystemSubscription = null;

    _followSystem = !_followSystem;
    if (_followSystem) {
      try {
        await _brightnessControllerRef?.resetToSystem();
        if (_brightnessControllerRef == null) {
          await ScreenBrightness().resetScreenBrightness();
        }
        double systemBrightness = await ScreenBrightness().current;
        _brightness = systemBrightness;
        _brightnessControllerRef?.uiBrightnessValue.value = systemBrightness;
        await getIt<ReaderPreferencesService>().setBrightness(null);

        // 单一命名引用，确保后续可以一次性取消。
        _followSystemSubscription =
            ScreenBrightness().onCurrentBrightnessChanged.listen((double b) {
          if (_followSystem) {
            _brightness = b;
            _brightnessControllerRef?.uiBrightnessValue.value = b;
            onSettingsChanged();
          }
        });
      } catch (e) {
        debugPrint("Failed to get system brightness: $e");
        _followSystem = false;
      }
    } else {
      await setBrightness(_brightness);
    }
    onSettingsChanged();
  }

  void handleLayoutChange(Size newSize, Size? lastSize, VoidCallback onUpdate) {
    if (lastSize != null &&
        (newSize.width - lastSize.width).abs() < 10 &&
        (newSize.height - lastSize.height).abs() < 10) {
      return;
    }

    final baseFontSize = 18.0;
    final scaleFactor = (newSize.width / 800).clamp(0.7, 1.5);
    final adjustedFontSize = (baseFontSize * scaleFactor).clamp(12.0, 32.0);

    if ((adjustedFontSize - _fontSize).abs() > 1.0) {
      _fontSize = adjustedFontSize;
      _updateEngineConfig();
      onUpdate();
    }
  }

  /// 生命周期终结清理。
  /// 必须在 ReaderController.dispose() 中调用，确保
  /// 1. ScreenBrightness 的系统事件流监听被绝对销毁。
  /// 2. BrightnessController.uiBrightnessValue 的监听器被移除。
  Future<void> dispose() async {
    await _followSystemSubscription?.cancel();
    _followSystemSubscription = null;
    detachBrightnessController();
  }
}
