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
}

class MascotManager {
  
  MascotType getMascotForScene(MascotScene scene) {
    switch (scene) {
      case MascotScene.splash:
      case MascotScene.emptyShelf:
      case MascotScene.readingReminder:
        return MascotType.typeA;
      case MascotScene.nightMode:
      case MascotScene.update:
        return MascotType.typeB;
    }
  }

  Widget render(MascotScene scene, {double size = 100}) {
    final type = getMascotForScene(scene);
    return _MascotWidget(type: type, scene: scene, size: size);
  }
}

class _MascotWidget extends StatelessWidget {
  final MascotType type;
  final MascotScene scene;
  final double size;

  const _MascotWidget({
    required this.type,
    required this.scene,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // Placeholder using Icons and Colors since we don't have assets yet
    IconData icon;
    Color color;

    if (type == MascotType.typeA) {
      color = const Color(0xFFF7B7C8); // Pink
      icon = Icons.pets; // Cat paw
    } else {
      color = const Color(0xFF7DB7D9); // Blue
      icon = Icons.nightlight_round; // Moon/Night
    }

    // Scene specific tweaks
    if (scene == MascotScene.emptyShelf) {
      icon = Icons.inbox;
    } else if (scene == MascotScene.readingReminder) {
      icon = Icons.access_alarm;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Icon(
          icon,
          size: size * 0.5,
          color: color,
        ),
      ),
    );
  }
}
