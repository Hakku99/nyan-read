import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/brightness_controller.dart';

/// 左侧锚定竖向亮度轨道 HUD
///
/// Moon+ Reader 设计哲学：手指在哪儿，反馈就在哪儿。
/// HUD 锚定于手势操作区同侧（屏幕左侧），
/// 使用竖向自绘轨道 + 动态图标 + 触觉刻度反馈。
class BrightnessHudWidget extends StatefulWidget {
  final BrightnessController controller;

  const BrightnessHudWidget({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<BrightnessHudWidget> createState() => _BrightnessHudWidgetState();
}

class _BrightnessHudWidgetState extends State<BrightnessHudWidget> {
  /// 上次触发触觉反馈时的 10% 刻度整数，避免连续无效触发
  int _lastHapticStep = -1;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 8,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: ValueListenableBuilder<bool>(
          valueListenable: widget.controller.isAdjusting,
          builder: (context, isAdjusting, _) {
            return AnimatedOpacity(
              opacity: isAdjusting ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: Align(
                alignment: Alignment.centerLeft,
                child: ValueListenableBuilder<double>(
                  valueListenable: widget.controller.uiBrightnessValue,
                  builder: (context, brightness, _) {
                    // 触觉刻度：每跨越 10% 整数刻度触发一次 selectionClick
                    final currentStep = (brightness * 10).floor();
                    if (isAdjusting && currentStep != _lastHapticStep) {
                      _lastHapticStep = currentStep;
                      HapticFeedback.selectionClick();
                    }

                    return _BrightnessTrackPanel(brightness: brightness);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 竖向亮度轨道面板，包含图标 + 轨道条 + 百分比数字
class _BrightnessTrackPanel extends StatelessWidget {
  final double brightness;

  static const double _trackHeight = 180.0;
  static const double _trackWidth = 6.0;
  static const double _hardwareFloor = 0.10; // 子零区着色切入点（视觉参考）

  const _BrightnessTrackPanel({required this.brightness});

  IconData _resolveIcon() {
    if (brightness < 0.30) return Icons.brightness_low_rounded;
    if (brightness < 0.70) return Icons.brightness_medium_rounded;
    return Icons.brightness_high_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isSubZero = brightness < _hardwareFloor;
    final trackColor = isSubZero
        ? const Color(0xFF3D5AFE) // 靛蓝 = 软件暗化模式
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.85);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 动态图标：三档灵活切换
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  _resolveIcon(),
                  key: ValueKey(_resolveIcon()),
                  color: trackColor,
                  size: 22,
                ),
              ),

              const SizedBox(height: 12),

              // 竖向轨道
              SizedBox(
                height: _trackHeight,
                width: _trackWidth + 16, // 含左右 padding
                child: Center(
                  child: CustomPaint(
                    size: const Size(_trackWidth, _trackHeight),
                    painter: _VerticalTrackPainter(
                      fillRatio: brightness.clamp(0.0, 1.0),
                      trackColor: trackColor,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 百分比数字
              Text(
                '${(brightness * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: trackColor,
                  decoration: TextDecoration.none,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 圆角竖向进度轨道绘制器
class _VerticalTrackPainter extends CustomPainter {
  final double fillRatio;
  final Color trackColor;
  final Color backgroundColor;

  const _VerticalTrackPainter({
    required this.fillRatio,
    required this.trackColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(3);
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      radius,
    );

    // 背景轨道
    canvas.drawRRect(bgRect, Paint()..color = backgroundColor);

    // 填充部分（从底部往上）
    final fillHeight = size.height * fillRatio;
    final fillTop = size.height - fillHeight;
    if (fillHeight > 0) {
      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, fillTop, size.width, fillHeight),
        radius,
      );
      canvas.drawRRect(
        fillRect,
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_VerticalTrackPainter old) =>
      old.fillRatio != fillRatio ||
      old.trackColor != trackColor ||
      old.backgroundColor != backgroundColor;
}
