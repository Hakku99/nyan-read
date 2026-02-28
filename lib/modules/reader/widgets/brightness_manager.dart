import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/reader_preferences_service.dart';
import '../controllers/brightness_controller.dart';

class BrightnessManager extends StatelessWidget {
  final Widget child;
  final ValueChanged<double>?
      onBrightnessChanged; // Deprecated or route to controller
  final BrightnessController controller;

  const BrightnessManager({
    Key? key,
    required this.child,
    required this.controller,
  }) : super(key: key);

  // Calculate mask opacity for "Software Dimming"
  double _getDimmingOpacity(ReaderPreferencesService prefs) {
    final b = prefs.brightness;
    if (b == null) return 0.0;

    final perceptual = prefs.getPerceptualBrightness(b);
    final minPhys = prefs.minPhysicalBrightness;

    if (perceptual > minPhys) return 0.0;

    double t = 1.0 - (perceptual / minPhys);
    return t * 0.85;
  }

  void _onVerticalDragStart(DragStartDetails details, BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (details.globalPosition.dy < screenHeight * 0.1 ||
        details.globalPosition.dy > screenHeight * 0.9) {
      return;
    }
    controller.handleDragStart();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, BuildContext context) {
    final dy = details.globalPosition.dy;
    final screenHeight = MediaQuery.of(context).size.height;
    // We pass the raw delta since drag behavior depends on dy in controller
    controller.handleDragUpdate(details.delta.dy, screenHeight);
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    controller.handleInteractionEnd();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // 1. The Child (Reader View)
            // No longer wrapped in Consumer, isolated from ReaderPreferencesService changes
            child,

            // 2. Warmth Layer (Amber/Orange)
            // Only rebuilds when warmth explicitly changes
            Selector<ReaderPreferencesService, double>(
              selector: (context, prefs) => prefs.warmth,
              builder: (context, warmth, child) {
                if (warmth <= 0.01) return const SizedBox.shrink();
                return IgnorePointer(
                  child: Container(
                    color: Colors.amber.withOpacity(warmth * 0.3),
                    foregroundDecoration: BoxDecoration(
                      backgroundBlendMode: BlendMode.multiply,
                      color: Colors.orangeAccent.withOpacity(warmth * 0.2),
                    ),
                  ),
                );
              },
            ),

            // 3. Dimming Layer (Black)
            // Only rebuilds when the calculated dimOpacity changes
            Selector<ReaderPreferencesService, double>(
              selector: (context, prefs) => _getDimmingOpacity(prefs),
              builder: (context, dimOpacity, child) {
                if (dimOpacity <= 0.01) return const SizedBox.shrink();
                return IgnorePointer(
                  child: Container(
                    color: Colors.black.withOpacity(dimOpacity),
                  ),
                );
              },
            ),

            // 4. Gesture Detector (Left Edge - Safe Zones logic in handler)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 30.0,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragStart: (details) =>
                    _onVerticalDragStart(details, context),
                onVerticalDragUpdate: (details) =>
                    _onVerticalDragUpdate(details, context),
                onVerticalDragEnd: _onVerticalDragEnd,
                child: Container(color: Colors.transparent),
              ),
            ),

            // 5. The generic HUD widget is expected to be placed elsewhere or top-level.
            // BrightnessManager no longer houses the local indicator.
          ],
        );
      },
    );
  }
}
