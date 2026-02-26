import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

class BrightnessController {
  // 核心 UI 驱动状态：绝对全量程 (0.00 到 1.00)
  // 初始值给 0.5 仅为防空指针，真理必须在 initBrightness 中从物理世界拉取
  final ValueNotifier<double> uiBrightnessValue = ValueNotifier(0.5);

  Timer? _throttleTimer;
  double _lastCommittedValue = -1.0;

  // ===== 硬件防砖底线防御参数 =====
  static const double hardwareSafeClamp = 0.10;

  /// 异步初始化：连接物理世界与软件感知的桥梁
  /// 必须在 Widget 的 initState 中被调用，拒绝“闪瞎眼”
  Future<void> initBrightness() async {
    try {
      final currentPhysical = await ScreenBrightness().current;
      // 同步真实世界状态到 UI 内存
      uiBrightnessValue.value = currentPhysical;
      _lastCommittedValue = currentPhysical;
    } catch (_) {
      // 降级保护：如果获取失败（无权限/模拟器），回退安全中庸值
      uiBrightnessValue.value = 0.5;
    }
  }

  /// 接收 UI 层的相对滑动像素，转换为亮度值
  void handleDragUpdate(double dragDeltaY, double screenHeight) {
    // 灵敏度映射：手指划过半个屏幕，亮度变化 100%
    final sensitivity = 2.0 / screenHeight;

    // 🚨 物理坐标系修正 🚨
    // Flutter 坐标原点在左上角。向下滑动 dragDeltaY 为正数。
    // 逻辑修正：向下滑动 (为正) = 变暗 (做减法)。
    final change = -(dragDeltaY * sensitivity);

    // 获取当前基准值，叠加增量，并严格限制在 0.0 - 1.0 数学区间内
    final newBrightness = (uiBrightnessValue.value + change).clamp(0.0, 1.0);

    // 1. 无阻塞：直接驱动 120Hz 局部重绘
    uiBrightnessValue.value = newBrightness;

    // 2. 丢弃高频垃圾请求，启动 50ms 节流窗口
    if (_throttleTimer?.isActive ?? false) return;

    _throttleTimer = Timer(const Duration(milliseconds: 50), () {
      _commitToNative(uiBrightnessValue.value);
    });
  }

  /// 滑动结束（手势抬起），强制核对最后状态，拒绝脏数据残留
  void handleDragEnd() {
    _throttleTimer?.cancel();
    _commitToNative(uiBrightnessValue.value);
  }

  /// 核心原生拦截层：向下通信的唯一咽喉
  Future<void> _commitToNative(double value) async {
    // 🚨 硬件底线拦截 (Safe-clamp) 🚨
    final safePhysicalLevel =
        value > hardwareSafeClamp ? value : hardwareSafeClamp;

    // 如果物理亮度与上次一致，拦截 IPC 通信，避免无意义损耗。
    if ((_lastCommittedValue - safePhysicalLevel).abs() < 0.01) return;

    _lastCommittedValue = safePhysicalLevel;

    try {
      // 真正接触系统 API 的一发决胜点
      await ScreenBrightness().setScreenBrightness(safePhysicalLevel);
    } catch (_) {}
  }

  /// 控制器销毁，释放定时器与 Notifier
  void dispose() {
    _throttleTimer?.cancel();
    uiBrightnessValue.dispose();
  }
}
