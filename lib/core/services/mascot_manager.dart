import 'package:flutter/material.dart';

enum MascotType {
  typeA, // Pink, Cute, Natural
  typeB, // Blue, Cool, Quiet
}

enum MascotScene {
  splash,
  emptyShelf,
  readingReminder,
  nightMode,
  update,
  error,
}

class MascotManager {
  MascotType getMascotForScene(MascotScene scene) {
    switch (scene) {
      case MascotScene.splash:
      case MascotScene.emptyShelf:
      case MascotScene.readingReminder:
      case MascotScene.error:
        return MascotType.typeA;
      case MascotScene.nightMode:
      case MascotScene.update:
        return MascotType.typeB;
    }
  }

  Widget render(MascotScene scene, {double size = 100, Color? color}) {
    final type = getMascotForScene(scene);
    return _MascotWidget(type: type, scene: scene, size: size, color: color);
  }
}

class _MascotWidget extends StatelessWidget {
  final MascotType type;
  final MascotScene scene;
  final double size;
  final Color? color;

  const _MascotWidget({
    required this.type,
    required this.scene,
    required this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Use theme colors to match Japanese Cream design
    final theme = Theme.of(context);

    IconData icon;
    Color effectiveColor;

    if (color != null) {
      effectiveColor = color!;
      icon = (type == MascotType.typeA) ? Icons.pets : Icons.nightlight_round;
    } else {
      // Use theme primary color instead of hardcoded colors
      effectiveColor = theme.colorScheme.primary;
      icon = (type == MascotType.typeA) ? Icons.pets : Icons.nightlight_round;
    }

    // Scene specific tweaks
    if (scene == MascotScene.emptyShelf) {
      icon = Icons.inbox;
    } else if (scene == MascotScene.readingReminder) {
      icon = Icons.access_alarm;
    } else if (scene == MascotScene.error) {
      icon = Icons.error_outline;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: effectiveColor.withOpacity(0.5), width: 2),
      ),
      child: Center(
        child: Icon(
          icon,
          size: size * 0.5,
          color: effectiveColor,
        ),
      ),
    );
  }
}
