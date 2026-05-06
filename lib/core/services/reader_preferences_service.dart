import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/nyan_colors.dart';
import '../utils/layout_debouncer.dart';

/// Page turn direction.
enum PageTurnMode {
  upDown,
  leftRight,
}

/// 翻页动画类型
enum PageAnimation {
  fade, // 淡入淡出
  paper, // 纸张效果 (极弱曲线动画)
  none, // 无动画
}

/// Internal tagged wrapper for a pending SharedPreferences write.  Keeps the
/// original Dart type so [_flushPendingWrites] can dispatch to the right
/// `prefs.setXxx` call without losing numeric precision (e.g. not coercing a
/// `double` into `setInt`).
class _PendingPrefWrite {
  _PendingPrefWrite.value(this.value) : remove = false;
  _PendingPrefWrite.delete()
      : value = null,
        remove = true;

  final Object? value;
  final bool remove;
}

/// 阅读偏好设置服务
/// 管理翻页方式、翻页动画等阅读相关配置.
///
/// Persistence model (Phase 2 · P0-8):
///   - All continuous-input setters (slider drag: fontSize / lineHeight /
///     brightness / warmth / followSystemOffset / minPhysicalBrightness /
///     backgroundColor) update **in-memory state synchronously** and fire
///     `notifyListeners` immediately so UI reacts on the frame.
///   - The SharedPreferences disk write is coalesced through a 300 ms
///     [Debouncer] keyed by pref name.  A 10-second slider wiggle that used
///     to produce ~60 writes/s now collapses to one write at the end of the
///     gesture, respecting AGENTS.md §2.4 ("滑块类连续输入的 setter 使用
///     Debouncer(300ms) 批量落盘").
///   - [flushPendingWrites] must be called before the app backgrounds / the
///     reader pops, so no user settings are lost on a cold kill.
class ReaderPreferencesService extends ChangeNotifier {
  ReaderPreferencesService();

  SharedPreferences? _prefs;

  // 默认配置
  PageTurnMode _pageTurnMode = PageTurnMode.upDown;
  PageAnimation _pageAnimation = PageAnimation.fade;

  // Reader display settings
  double _fontSize = 18.0;
  double _lineHeight = 1.5;
  Color _backgroundColor = NyanColors.readerPaperDefault;
  double? _brightness;
  double _warmth = 0.0; // 0.0 (Cool/None) to 1.0 (Max Warmth)
  double _minPhysicalBrightness = 0.10; // User preferred hardware floor
  double _followSystemOffset = 0.0; // +/- offset from system brightness

  /// When false, the left-edge vertical drag gesture to adjust brightness is
  /// ignored (reduces accidental drags while still allowing sheet controls).
  bool _edgeBrightnessGestureEnabled = true;

  // Coalesced-write state.  Keyed by SharedPreferences key so that a second
  // write to the same key supersedes the first (no write amplification).
  final Map<String, _PendingPrefWrite> _pendingWrites = {};
  final Debouncer _writeDebouncer =
      Debouncer(delay: const Duration(milliseconds: 300));
  bool _disposed = false;

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

  bool get edgeBrightnessGestureEnabled => _edgeBrightnessGestureEnabled;

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
        _prefs?.getInt('page_turn_mode') ?? PageTurnMode.upDown.index;
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
    _edgeBrightnessGestureEnabled =
        _prefs?.getBool('reader_edge_brightness_gesture_enabled') ?? true;
  }

  // 设置翻页方式
  Future<void> setPageTurnMode(PageTurnMode mode) async {
    if (_pageTurnMode == mode) return;

    _pageTurnMode = mode;
    _schedulePrefWrite('page_turn_mode', mode.index);
    notifyListeners();
  }

  // 设置翻页动画
  Future<void> setPageAnimation(PageAnimation animation) async {
    if (_pageAnimation == animation) return;

    _pageAnimation = animation;
    _schedulePrefWrite('page_animation', animation.index);
    notifyListeners();
  }

  // Set font size
  Future<void> setFontSize(double size) async {
    if (_fontSize == size) return;
    _fontSize = size;
    _schedulePrefWrite('reader_font_size', size);
    notifyListeners();
  }

  // Set line height
  Future<void> setLineHeight(double height) async {
    if (_lineHeight == height) return;
    _lineHeight = height;
    _schedulePrefWrite('reader_line_height', height);
    notifyListeners();
  }

  // Set background color
  Future<void> setBackgroundColor(Color color) async {
    if (_backgroundColor == color) return;
    _backgroundColor = color;
    // toARGB32() 返回与 Flutter 3.27 前 Color.value 相同的 32-bit int，
    // 因此不会破坏老用户已经持久化的 'reader_background_color' 字段。
    _schedulePrefWrite('reader_background_color', color.toARGB32());
    notifyListeners();
  }

  // Set brightness
  Future<void> setBrightness(double? b) async {
    if (_brightness == b) return;
    _brightness = b;

    if (b == null) {
      _schedulePrefRemove('reader_brightness');
    } else {
      _schedulePrefWrite('reader_brightness', b);
    }
    notifyListeners();
  }

  // Set warmth
  Future<void> setWarmth(double w) async {
    if (_warmth == w) return;
    _warmth = w;
    _schedulePrefWrite('reader_warmth', w);
    notifyListeners();
  }

  // Set min physical brightness
  Future<void> setMinPhysicalBrightness(double min) async {
    if (_minPhysicalBrightness == min) return;
    _minPhysicalBrightness = min;
    _schedulePrefWrite('reader_min_physical_brightness', min);
    notifyListeners();
  }

  // Set follow system offset
  Future<void> setFollowSystemOffset(double offset) async {
    if (_followSystemOffset == offset) return;
    _followSystemOffset = offset;
    _schedulePrefWrite('reader_follow_system_offset', offset);
    notifyListeners();
  }

  /// Enables or disables the in-reader left-edge vertical brightness gesture.
  Future<void> setEdgeBrightnessGestureEnabled(bool value) async {
    if (_edgeBrightnessGestureEnabled == value) return;
    _edgeBrightnessGestureEnabled = value;
    _schedulePrefWrite('reader_edge_brightness_gesture_enabled', value);
    notifyListeners();
  }

  // 重置为默认配置
  Future<void> resetToDefaults() async {
    _pageTurnMode = PageTurnMode.upDown;
    _pageAnimation = PageAnimation.fade;
    _fontSize = 18.0;
    _lineHeight = 1.5;
    _backgroundColor = NyanColors.readerPaperDefault;
    _warmth = 0.0;
    _followSystemOffset = 0.0;

    // Reset is an atomic user-intent: drop any in-flight continuous-slider
    // writes so we don't resurrect them half a second later, then persist
    // the defaults straight to disk.
    _writeDebouncer.cancel();
    _pendingWrites.clear();

    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setInt('page_turn_mode', PageTurnMode.upDown.index);
      await prefs.setInt('page_animation', PageAnimation.fade.index);
      await prefs.setDouble('reader_font_size', 18.0);
      await prefs.setDouble('reader_line_height', 1.5);
      await prefs.setInt('reader_background_color',
          NyanColors.readerPaperDefault.toARGB32());
      await prefs.setDouble('reader_warmth', 0.0);
      await prefs.setDouble('reader_follow_system_offset', 0.0);
    }

    notifyListeners();
  }

  /// Flush any pending SharedPreferences writes immediately.  Call this
  /// before the app backgrounds or the reader pops so a cold kill does not
  /// eat the last 300 ms worth of settings drag.
  Future<void> flushPendingWrites() async {
    _writeDebouncer.cancel();
    await _flushPendingWrites();
  }

  // --- Internal coalescing helpers ---

  void _schedulePrefWrite(String key, Object value) {
    if (_disposed) return;
    _pendingWrites[key] = _PendingPrefWrite.value(value);
    _writeDebouncer.run(() => unawaited(_flushPendingWrites()));
  }

  void _schedulePrefRemove(String key) {
    if (_disposed) return;
    _pendingWrites[key] = _PendingPrefWrite.delete();
    _writeDebouncer.run(() => unawaited(_flushPendingWrites()));
  }

  Future<void> _flushPendingWrites() async {
    final prefs = _prefs;
    if (prefs == null || _pendingWrites.isEmpty) return;

    // Snapshot & clear first so any writer firing during disk await goes
    // into a fresh batch rather than racing with this flush.
    final snapshot = Map<String, _PendingPrefWrite>.from(_pendingWrites);
    _pendingWrites.clear();

    for (final entry in snapshot.entries) {
      final key = entry.key;
      final write = entry.value;
      try {
        if (write.remove) {
          await prefs.remove(key);
          continue;
        }
        final value = write.value;
        if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        } else {
          debugPrint(
              'ReaderPreferencesService: unsupported pref type for "$key": ${value.runtimeType}');
        }
      } catch (e) {
        debugPrint('ReaderPreferencesService: pref write for "$key" failed: $e');
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      super.dispose();
      return;
    }
    _disposed = true;
    // Best-effort final flush; fire-and-forget because dispose() is sync.
    _writeDebouncer.cancel();
    unawaited(_flushPendingWrites());
    _writeDebouncer.dispose();
    super.dispose();
  }
}
