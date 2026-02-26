import 'package:flutter/material.dart';

/// 极限暗黑无阻塞遮罩
class SubZeroBrightnessWrapper extends StatelessWidget {
  final Widget child;
  final ValueNotifier<double> brightnessNotifier;

  // 映射之前的硬件防砖阀值
  static const double _hardwareSafeClamp = 0.10;

  const SubZeroBrightnessWrapper({
    Key? key,
    required this.child,
    required this.brightnessNotifier,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: brightnessNotifier,
      builder: (context, perceivedBrightness, _) {
        double dimOpacity = 0.0;

        // 当 UI 感知亮度低于硬件底线时，启动软件黑色遮罩的透明度补足
        if (perceivedBrightness < _hardwareSafeClamp) {
          double dimFactor = 1.0 - (perceivedBrightness / _hardwareSafeClamp);
          dimOpacity = dimFactor * 0.85; // 保护视网膜，最高 85% 黑度
        }

        return Stack(
          children: [
            // 你的基础阅读器 (核心内容区)
            child,

            // 软件级暗黑遮罩层
            if (dimOpacity > 0.01)
              IgnorePointer(
                // 核心！穿透手势，不然遮罩一出来就阻断全屏互动
                child: Container(
                  color: Colors.black.withOpacity(dimOpacity),
                ),
              ),
          ],
        );
      },
    );
  }
}
