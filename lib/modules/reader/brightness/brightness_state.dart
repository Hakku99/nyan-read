import 'overlay_brightness_policy.dart';

enum BrightnessMode { manual, followSystem }

class BrightnessState {
  static const double defaultHardwareFloor = 0.05;

  final BrightnessMode mode;
  final double uiBrightness;
  final double hardwareFloor;
  final double? originalSystemBrightness;
  final double? lastObservedSystemBrightness;
  final double? lastAppliedSystemBrightness;

  const BrightnessState({
    required this.mode,
    required this.uiBrightness,
    this.hardwareFloor = defaultHardwareFloor,
    this.originalSystemBrightness,
    this.lastObservedSystemBrightness,
    this.lastAppliedSystemBrightness,
  });

  factory BrightnessState.initial() {
    return const BrightnessState(
      mode: BrightnessMode.followSystem,
      uiBrightness: 0.5,
    );
  }

  bool get followSystem => mode == BrightnessMode.followSystem;

  double get clampedUiBrightness => uiBrightness.clamp(0.0, 1.0).toDouble();

  double get normalizedHardwareFloor =>
      hardwareFloor.clamp(0.0, 1.0).toDouble();

  double get targetSystemBrightness =>
      clampedUiBrightness >= normalizedHardwareFloor
          ? clampedUiBrightness
          : normalizedHardwareFloor;

  double get overlayOpacity => const OverlayBrightnessPolicy().calculate(
        uiBrightness: clampedUiBrightness,
        hardwareFloor: normalizedHardwareFloor,
      );

  bool get isSystemOverrideActive => lastAppliedSystemBrightness != null;

  BrightnessState copyWith({
    BrightnessMode? mode,
    double? uiBrightness,
    double? hardwareFloor,
    Object? originalSystemBrightness = _unset,
    Object? lastObservedSystemBrightness = _unset,
    Object? lastAppliedSystemBrightness = _unset,
  }) {
    return BrightnessState(
      mode: mode ?? this.mode,
      uiBrightness: uiBrightness ?? this.uiBrightness,
      hardwareFloor: hardwareFloor ?? this.hardwareFloor,
      originalSystemBrightness: identical(originalSystemBrightness, _unset)
          ? this.originalSystemBrightness
          : originalSystemBrightness as double?,
      lastObservedSystemBrightness:
          identical(lastObservedSystemBrightness, _unset)
              ? this.lastObservedSystemBrightness
              : lastObservedSystemBrightness as double?,
      lastAppliedSystemBrightness:
          identical(lastAppliedSystemBrightness, _unset)
              ? this.lastAppliedSystemBrightness
              : lastAppliedSystemBrightness as double?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BrightnessState &&
        other.mode == mode &&
        other.uiBrightness == uiBrightness &&
        other.hardwareFloor == hardwareFloor &&
        other.originalSystemBrightness == originalSystemBrightness &&
        other.lastObservedSystemBrightness == lastObservedSystemBrightness &&
        other.lastAppliedSystemBrightness == lastAppliedSystemBrightness;
  }

  @override
  int get hashCode => Object.hash(
        mode,
        uiBrightness,
        hardwareFloor,
        originalSystemBrightness,
        lastObservedSystemBrightness,
        lastAppliedSystemBrightness,
      );
}

const Object _unset = Object();
