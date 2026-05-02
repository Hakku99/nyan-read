import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'brightness_state.dart';

class BrightnessOverlayWidget extends StatelessWidget {
  const BrightnessOverlayWidget({
    super.key,
    required this.child,
    required this.stateListenable,
    required this.warmthListenable,

    /// [StackFit.expand] for full-screen reader body; [StackFit.passthrough]
    /// for bottom sheets so the stack sizes to [child] only (barrier taps work,
    /// height constraints like 92% max are preserved).
    this.stackFit = StackFit.expand,
  });

  final Widget child;
  final ValueListenable<BrightnessState> stateListenable;
  final ValueListenable<double> warmthListenable;
  final StackFit stackFit;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BrightnessState>(
      valueListenable: stateListenable,
      builder: (context, state, _) {
        return ValueListenableBuilder<double>(
          valueListenable: warmthListenable,
          builder: (context, warmth, _) {
            return Stack(
              fit: stackFit,
              children: [
                child,
                if (warmth > 0.01)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.amber.withValues(alpha: warmth * 0.3),
                        foregroundDecoration: BoxDecoration(
                          backgroundBlendMode: BlendMode.multiply,
                          color: Colors.orangeAccent
                              .withValues(alpha: warmth * 0.2),
                        ),
                      ),
                    ),
                  ),
                if (state.overlayOpacity > 0.0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black
                            .withValues(alpha: state.overlayOpacity),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
