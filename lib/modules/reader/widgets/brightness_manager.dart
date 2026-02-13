import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

class BrightnessManager extends StatefulWidget {
  final Widget child;
  final double brightness; // 0.0 to 1.0
  final ValueChanged<double> onBrightnessChanged;

  const BrightnessManager({
    Key? key,
    required this.child,
    required this.brightness,
    required this.onBrightnessChanged,
  }) : super(key: key);

  @override
  State<BrightnessManager> createState() => _BrightnessManagerState();
}

class _BrightnessManagerState extends State<BrightnessManager> {
  // Threshold below which we start using the software mask
  // e.g., if brightness < 0.15, we clamp system brightness to 0.15
  // and increase the black overlay opacity.
  static const double kMinSystemBrightness = 0.15;

  // Track system brightness to restore later
  double? _originalSystemBrightness;

  // Gesture state
  bool _isDragging = false;
  double _dragStartY = 0.0;
  double _startBrightness = 0.0;

  // Timer to hide the indicator after dragging stops
  Timer? _hideTimer;
  bool _showIndicator = false;

  @override
  void initState() {
    super.initState();
    _saveOriginalBrightness();
    // Apply initial brightness
    _applyBrightness(widget.brightness);
  }

  @override
  void didUpdateWidget(BrightnessManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brightness != widget.brightness) {
      _applyBrightness(widget.brightness);
    }
  }

  @override
  void dispose() {
    _restoreOriginalBrightness();
    _hideTimer?.cancel();
    super.dispose();
  }

  Future<void> _saveOriginalBrightness() async {
    try {
      _originalSystemBrightness = await ScreenBrightness().current;
    } catch (_) {
      // Ignore errors (e.g. desktop/web)
    }
  }

  Future<void> _restoreOriginalBrightness() async {
    if (_originalSystemBrightness != null) {
      try {
        await ScreenBrightness()
            .setScreenBrightness(_originalSystemBrightness!);
      } catch (_) {}
    } else {
      try {
        await ScreenBrightness().resetScreenBrightness();
      } catch (_) {}
    }
  }

  /// Applies the "Dual-Layer" brightness
  Future<void> _applyBrightness(double target) async {
    try {
      double systemLevel;

      if (target > kMinSystemBrightness) {
        // Simple case: System brightness handles it all
        systemLevel = target;
      } else {
        // Complex case: Clamp system brightness, let mask handle the rest
        systemLevel = kMinSystemBrightness;
      }

      await ScreenBrightness().setScreenBrightness(systemLevel);
    } catch (_) {
      // Ignore platform errors
    }
  }

  /// Calculates the opacity of the black overlay based on current brightness
  double get _maskOpacity {
    if (widget.brightness > kMinSystemBrightness) {
      return 0.0;
    }
    // Map brightness [0.0 ... kMinSystemBrightness] -> Opacity [MAX ... 0.0]
    // When brightness is 0, opacity should be high (e.g. 0.7 or 0.8), not 1.0 (pitch black)
    // When brightness is kMin, opacity is 0.

    // We can say at 0.0 brightness, we want ~80% extra dimming.
    const double maxOpacity = 0.85;

    double t = 1.0 -
        (widget.brightness /
            kMinSystemBrightness); // 1.0 at bright=0, 0.0 at bright=min
    return t * maxOpacity;
  }

  void _onVerticalDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _showIndicator = true;
      _dragStartY = details.globalPosition.dy;
      _startBrightness = widget.brightness;
    });
    _hideTimer?.cancel();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final dy = details.globalPosition.dy;
    final deltaY = _dragStartY - dy; // Drag Up (+), Drag Down (-)

    // Total screen height
    final screenHeight = MediaQuery.of(context).size.height;

    // Sensitivity: Full screen swipe = 100% adjustment?
    // Let's make it so ~50% of screen height makes a full change.
    final sensitivity = 2.0 / screenHeight;

    final change = deltaY * sensitivity;

    // Calculate new raw brightness
    final newB =
        (_startBrightness + change).clamp(0.01, 1.0); // Keep purely positive

    if ((newB - widget.brightness).abs() > 0.005) {
      widget.onBrightnessChanged(newB);
      // Feedback ensures UI feels responsive
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    // Fade out indicator after short delay
    _hideTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showIndicator = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. The Child (Reader View)
        widget.child,

        // 2. The Software Mask (Dual-Layer)
        if (_maskOpacity > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity(_maskOpacity),
              ),
            ),
          ),

        // 3. Gesture Detector (Left Edge)
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 60.0, // Large enough to grab comfortably
          child: GestureDetector(
            behavior: HitTestBehavior
                .translucent, // Catch events on transparent region
            onVerticalDragStart: _onVerticalDragStart,
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Container(
              color: Colors.transparent, // Debug: Colors.red.withOpacity(0.2)
            ),
          ),
        ),

        // 4. Brightness Indicator (Centered)
        if (_showIndicator)
          Center(
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.brightness > 0.6
                          ? Icons.brightness_7
                          : // Sun
                          widget.brightness > 0.2
                              ? Icons.brightness_6
                              : // Half
                              Icons.brightness_3, // Moon
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${(widget.brightness * 100).toInt()}%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration
                            .none, // Inherited from Stack if not specified
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
