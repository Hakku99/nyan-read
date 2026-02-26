import 'dart:ui';
import 'package:flutter/material.dart';
import '../controllers/brightness_controller.dart';

class BrightnessHudWidget extends StatelessWidget {
  final BrightnessController controller;

  const BrightnessHudWidget({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: IgnorePointer(
        child: ValueListenableBuilder<bool>(
          valueListenable: controller.isAdjusting,
          builder: (context, isAdjusting, child) {
            return AnimatedOpacity(
              opacity: isAdjusting ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.brightness_6_rounded,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<double>(
                          valueListenable: controller.uiBrightnessValue,
                          builder: (context, value, child) {
                            return Text(
                              '${(value * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                                decoration: TextDecoration.none,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
