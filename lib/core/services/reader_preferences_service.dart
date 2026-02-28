import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 翻页方式
enum PageTurnMode {
  tap, // 点击翻页
  swipe, // 滑动翻页
  disabled, // 禁用翻页
}

/// 翻页动画类型
enum PageAnimation {
  fade, // 淡入淡出
  paper, // 纸张效果 (极弱曲线动画)
  none, // 无动画
}

/// 阅读偏好设置服务
/// 管理翻页方式、翻页动画等阅读相关配置
class ReaderPreferencesService extends ChangeNotifier {
  ReaderPreferencesService();

  SharedPreferences? _prefs;

  // 默认配置
  PageTurnMode _pageTurnMode = PageTurnMode.swipe;
  PageAnimation _pageAnimation = PageAnimation.fade;

  // Reader display settings
  double _fontSize = 18.0;
  double _lineHeight = 1.5;
  Color _backgroundColor = const Color(0xFFFDFCF8); // Default Cream Paper
  double? _brightness;
  double _warmth = 0.0; // 0.0 (Cool/None) to 1.0 (Max Warmth)
  double _minPhysicalBrightness = 0.10; // User preferred hardware floor
  double _followSystemOffset = 0.0; // +/- offset from system brightness

  // Getters
  PageTurnMode get pageTurnMode => _pageTurnMode;
  PageAnimation get pageAnimation => _pageAnimation;
  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  Color get backgroundColor => _backgroundColor;
  double? get brightness => _brightness;
  double get warmth => _warmth;
  double get minPhysicalBrightness => _minPhysicalBrightness;
  double get followSystemOffset => _followSystemOffset;

  /// Returns the gamma-corrected brightness value (0.0 - 1.0)
  /// Input: Linear slider value (0.0 - 1.0)
  /// Output: Perceptual brightness (Power 2.2 curve)
  double getPerceptualBrightness(double sliderValue) {
    if (sliderValue <= 0) return 0.0;
    if (sliderValue >= 1) return 1.0;
    // Gamma 2.2 approximation
    return sliderValue *
        sliderValue; // Using 2.0 (quadratic) for slightly better performance/feel on mobile
  }

  // 初始化服务
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadPreferences();
  }

  // 从持久化存储加载配置
  void _loadPreferences() {
    final turnModeIndex =
        _prefs?.getInt('page_turn_mode') ?? PageTurnMode.swipe.index;
    final animationIndex =
        _prefs?.getInt('page_animation') ?? PageAnimation.fade.index;

    _pageTurnMode = PageTurnMode
        .values[turnModeIndex.clamp(0, PageTurnMode.values.length - 1)];
    _pageAnimation = PageAnimation
        .values[animationIndex.clamp(0, PageAnimation.values.length - 1)];

    // Load reader display settings
    _fontSize = _prefs?.getDouble('reader_font_size') ?? 18.0;
    _lineHeight = _prefs?.getDouble('reader_line_height') ?? 1.5;
    final bgColorInt = _prefs?.getInt('reader_background_color');
    if (bgColorInt != null) {
      _backgroundColor = Color(bgColorInt);
    }
    _brightness = _prefs?.getDouble('reader_brightness');
    _warmth = _prefs?.getDouble('reader_warmth') ?? 0.0;
    _minPhysicalBrightness =
        _prefs?.getDouble('reader_min_physical_brightness') ?? 0.10;
    _followSystemOffset =
        _prefs?.getDouble('reader_follow_system_offset') ?? 0.0;
  }

  // 设置翻页方式
  Future<void> setPageTurnMode(PageTurnMode mode) async {
    if (_pageTurnMode == mode) return;

    _pageTurnMode = mode;
    await _prefs?.setInt('page_turn_mode', mode.index);
    notifyListeners();
  }

  // 设置翻页动画
  Future<void> setPageAnimation(PageAnimation animation) async {
    if (_pageAnimation == animation) return;

    _pageAnimation = animation;
    await _prefs?.setInt('page_animation', animation.index);
    notifyListeners();
  }

  // Set font size
  Future<void> setFontSize(double size) async {
    if (_fontSize == size) return;
    _fontSize = size;
    await _prefs?.setDouble('reader_font_size', size);
    notifyListeners();
  }

  // Set line height
  Future<void> setLineHeight(double height) async {
    if (_lineHeight == height) return;
    _lineHeight = height;
    await _prefs?.setDouble('reader_line_height', height);
    notifyListeners();
  }

  // Set background color
  Future<void> setBackgroundColor(Color color) async {
    if (_backgroundColor.value == color.value) return;
    _backgroundColor = color;
    await _prefs?.setInt('reader_background_color', color.value);
    notifyListeners();
  }

  // Set brightness
  Future<void> setBrightness(double? b) async {
    if (_brightness == b) return;
    _brightness = b;

    if (b == null) {
      await _prefs?.remove('reader_brightness');
    } else {
      await _prefs?.setDouble('reader_brightness', b);
    }
    notifyListeners();
  }

  // Set warmth
  Future<void> setWarmth(double w) async {
    if (_warmth == w) return;
    _warmth = w;
    await _prefs?.setDouble('reader_warmth', w);
    notifyListeners();
  }

  // Set min physical brightness
  Future<void> setMinPhysicalBrightness(double min) async {
    if (_minPhysicalBrightness == min) return;
    _minPhysicalBrightness = min;
    await _prefs?.setDouble('reader_min_physical_brightness', min);
    notifyListeners();
  }

  // Set follow system offset
  Future<void> setFollowSystemOffset(double offset) async {
    if (_followSystemOffset == offset) return;
    _followSystemOffset = offset;
    await _prefs?.setDouble('reader_follow_system_offset', offset);
    notifyListeners();
  }

  // 重置为默认配置
  Future<void> resetToDefaults() async {
    _pageTurnMode = PageTurnMode.swipe;
    _pageAnimation = PageAnimation.fade;
    _fontSize = 18.0;
    _lineHeight = 1.5;
    _backgroundColor = const Color(0xFFFDFCF8);
    _warmth = 0.0;
    _followSystemOffset = 0.0;

    await _prefs?.setInt('page_turn_mode', PageTurnMode.swipe.index);
    await _prefs?.setInt('page_animation', PageAnimation.fade.index);
    await _prefs?.setDouble('reader_font_size', 18.0);
    await _prefs?.setDouble('reader_line_height', 1.5);
    await _prefs?.setInt('reader_background_color', 0xFFFDFCF8);
    await _prefs?.setDouble('reader_warmth', 0.0);
    await _prefs?.setDouble('reader_follow_system_offset', 0.0);

    notifyListeners();
  }
}
