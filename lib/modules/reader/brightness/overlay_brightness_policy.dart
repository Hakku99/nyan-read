class OverlayBrightnessPolicy {
  const OverlayBrightnessPolicy();

  double calculate({
    required double uiBrightness,
    required double hardwareFloor,
  }) {
    final normalizedBrightness = _clamp(uiBrightness);
    final normalizedFloor = hardwareFloor <= 0 ? 0.0 : _clamp(hardwareFloor);
    if (normalizedFloor == 0.0 || normalizedBrightness >= normalizedFloor) {
      return 0.0;
    }

    return ((normalizedFloor - normalizedBrightness) / normalizedFloor)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _clamp(double value) => value.clamp(0.0, 1.0).toDouble();
}
