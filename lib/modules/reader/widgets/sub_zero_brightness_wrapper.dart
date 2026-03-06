import 'package:flutter/material.dart';

/// 极限暗黑无阻塞遮罩
/// [hardwareFloor]：与 ReaderPreferencesService.minPhysicalBrightness 保持同源注入，
/// 确保软件遮罩的切入点与硬件底线完全一致。
class SubZeroBrightnessWrapper extends StatelessWidget {
  final Widget child;
  final ValueNotifier<double> brightnessNotifier;

  /// 硬件亮度底线，由外部注入，确保与 ReaderPreferencesService 中的配置同源。
  final double hardwareFloor;

  const SubZeroBrightnessWrapper({
    Key? key,
    required this.child,
    required this.brightnessNotifier,
    this.hardwareFloor = 0.10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: brightnessNotifier,
      builder: (context, perceivedBrightness, _) {
        double dimOpacity = 0.0;

        // 当 UI 感知亮度低于硬件底线时，启动软件黑色遮罩的透明度补足
        if (perceivedBrightness < hardwareFloor) {
          final dimFactor = 1.0 - (perceivedBrightness / hardwareFloor);
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
