import 'package:flutter/foundation.dart';
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
  static final ReaderPreferencesService _instance =
      ReaderPreferencesService._internal();
  static ReaderPreferencesService get instance => _instance;

  factory ReaderPreferencesService() => _instance;

  ReaderPreferencesService._internal();

  SharedPreferences? _prefs;

  // 默认配置
  PageTurnMode _pageTurnMode = PageTurnMode.swipe;
  PageAnimation _pageAnimation = PageAnimation.fade;

  // Getters
  PageTurnMode get pageTurnMode => _pageTurnMode;
  PageAnimation get pageAnimation => _pageAnimation;

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

  // 重置为默认配置
  Future<void> resetToDefaults() async {
    _pageTurnMode = PageTurnMode.swipe;
    _pageAnimation = PageAnimation.fade;

    await _prefs?.setInt('page_turn_mode', PageTurnMode.swipe.index);
    await _prefs?.setInt('page_animation', PageAnimation.fade.index);

    notifyListeners();
  }
}
