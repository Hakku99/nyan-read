import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'brightness_state.dart';

class BrightnessOverlayWidget extends StatelessWidget {
  const BrightnessOverlayWidget({
    Key? key,
    required this.child,
    required this.stateListenable,
    required this.warmthListenable,
  }) : super(key: key);

  final Widget child;
  final ValueListenable<BrightnessState> stateListenable;
  final ValueListenable<double> warmthListenable;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BrightnessState>(
      valueListenable: stateListenable,
      builder: (context, state, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            ValueListenableBuilder<double>(
              valueListenable: warmthListenable,
              builder: (context, warmth, _) {
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
            if (state.overlayOpacity > 0.0)
              IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(state.overlayOpacity),
                ),
              ),
          ],
        );
      },
    );
  }
}

