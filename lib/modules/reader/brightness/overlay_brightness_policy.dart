class OverlayBrightnessPolicy {
  const OverlayBrightnessPolicy();

  /// Caps software dimming so the reader never becomes a fully opaque black layer
  /// (which made recovery confusing and hid all content).
  static const double maxOverlayOpacity = 0.82;

  double calculate({
    required double uiBrightness,
    required double hardwareFloor,
  }) {
    final normalizedBrightness = _clamp(uiBrightness);
    final normalizedFloor = hardwareFloor <= 0 ? 0.0 : _clamp(hardwareFloor);
    if (normalizedFloor == 0.0 || normalizedBrightness >= normalizedFloor) {
      return 0.0;
    }

    final ratio = ((normalizedFloor - normalizedBrightness) / normalizedFloor)
        .clamp(0.0, 1.0)
        .toDouble();
    return (ratio * maxOverlayOpacity).clamp(0.0, maxOverlayOpacity).toDouble();
  }

  double _clamp(double value) => value.clamp(0.0, 1.0).toDouble();
}
