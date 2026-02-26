import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'package:provider/provider.dart';
import '../../../../core/services/reader_preferences_service.dart';

class BrightnessManager extends StatefulWidget {
  final Widget child;
  final ValueChanged<double> onBrightnessChanged;

  const BrightnessManager({
    Key? key,
    required this.child,
    required this.onBrightnessChanged,
  }) : super(key: key);

  @override
  State<BrightnessManager> createState() => _BrightnessManagerState();
}

class _BrightnessManagerState extends State<BrightnessManager>
    with WidgetsBindingObserver {
  // Track system brightness to restore later
  double? _originalSystemBrightness;

  // Gesture state
  bool _isDragging = false;
  double _dragStartY = 0.0;
  double _startBrightness = 0.0;

  // Timer to hide the indicator after dragging stops
  Timer? _hideTimer;
  bool _showIndicator = false;

  // Debouncer for brightness updates
  Timer? _debounceTimer;

  late ReaderPreferencesService _prefs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prefs = Provider.of<ReaderPreferencesService>(context, listen: false);
    _prefs.addListener(_handlePrefsChange);
    _saveOriginalBrightness();
    _enableWakeLock();
    // _checkPermissions();

    // Apply initial state
    _applyBrightnessState();
  }

  void _handlePrefsChange() {
    _applyBrightnessState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _restoreOriginalBrightness();
      _disableWakeLock();
    } else if (state == AppLifecycleState.resumed) {
      _enableWakeLock();
      _saveOriginalBrightness(); // Re-save in case it changed while backgrounded
      _applyBrightnessState();
    }
  }

  void _applyBrightnessState() {
    if (_prefs.brightness != null) {
      _applyBrightness(_prefs.brightness!);
    } else {
      _restoreOriginalBrightness();
    }
  }

  @override
  void didUpdateWidget(BrightnessManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    // React to changes is handled by Consumer/Provider in build method mostly,
    // but if we had local state that depended on widget params we'd update here.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _prefs.removeListener(_handlePrefsChange);
    _restoreOriginalBrightness();
    _disableWakeLock();
    _hideTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _enableWakeLock() async {
    try {
      // await WakelockPlus.enable();
    } catch (_) {}
  }

  Future<void> _disableWakeLock() async {
    try {
      // await WakelockPlus.disable();
    } catch (_) {}
  }

  Future<void> _saveOriginalBrightness() async {
    try {
      _originalSystemBrightness = await ScreenBrightness().current;
    } catch (_) {
      // Ignore errors (e.g. desktop/web)
    }
  }

  Future<void> _restoreOriginalBrightness() async {
    // If user has "Follow System" ON (brightness == null), we don't need to restore anything
    // because we shouldn't have changed it much, or we want to leave it as is.
    // However, if we were overriding, we should restore.

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

  /// Applies the Brightness Logic
  Future<void> _applyBrightness(double sliderValue) async {
    try {
      // 1. Gamma Correction
      final perceptual = _prefs.getPerceptualBrightness(sliderValue);

      // 2. Dual-Layer Logic
      final minPhys = _prefs.minPhysicalBrightness;

      double systemLevel;

      if (perceptual > minPhys) {
        // Physical range
        systemLevel = perceptual;
      } else {
        // Software Clamp
        systemLevel = minPhys;
      }

      await ScreenBrightness().setScreenBrightness(systemLevel);
    } catch (_) {
      // Ignore platform errors
    }
  }

  // Calculate mask opacity for "Software Dimming"
  double get _dimmingOpacity {
    final b = _prefs.brightness;
    if (b == null)
      return 0.0; // Follow system -> no dimming (unless offset used, complex)

    final perceptual = _prefs.getPerceptualBrightness(b);
    final minPhys = _prefs.minPhysicalBrightness;

    if (perceptual > minPhys) return 0.0;

    // Map [0.0 ... minPhys] -> [MAX_OPACITY ... 0.0]
    double t = 1.0 - (perceptual / minPhys);
    // Max opacity 85%
    return t * 0.85;
  }

  void _onVerticalDragStart(DragStartDetails details) {
    // Safe Zone Check: Ignore top/bottom 10%
    final screenHeight = MediaQuery.of(context).size.height;
    if (details.globalPosition.dy < screenHeight * 0.1 ||
        details.globalPosition.dy > screenHeight * 0.9) {
      return;
    }

    setState(() {
      _isDragging = true;
      _showIndicator = true;
      _dragStartY = details.globalPosition.dy;
      // If null (follow system), assume 50% for start or current system?
      // Simpler to just default to 0.5 if unset.
      _startBrightness = _prefs.brightness ?? 0.5;
    });
    _hideTimer?.cancel();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final dy = details.globalPosition.dy;
    final deltaY = _dragStartY - dy; // Drag Up (+), Drag Down (-)

    // Hysteresis / Deadzone check could go here if we tracked total delta

    final screenHeight = MediaQuery.of(context).size.height;
    final sensitivity = 2.0 / screenHeight; // 50% screen = 100% change

    final change = deltaY * sensitivity;

    // Calculate new raw slider value
    final newB = (_startBrightness + change).clamp(0.0, 1.0);

    if ((newB - (_prefs.brightness ?? 0.0)).abs() > 0.005) {
      widget.onBrightnessChanged(newB);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
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
    return Consumer<ReaderPreferencesService>(
      builder: (context, prefs, child) {
        // We trigger the side-effect of brightness application here if it changed
        // Ideally we shouldn't do side-effects in build, but for simple state sync it works.
        // Better pattern: use addListener in initState.
        // For now, relies on the fact that setBrightness calls notifyListeners.
        // We already have a listener in initState via updateWidget or didChangeDependencies?
        // Actually, we should call _applyBrightness explicitly when prefs change.
        // Let's rely on the parent or the setter to have driven the change.

        final double warmth = prefs.warmth;
        final double dimOpacity = _dimmingOpacity;

        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // 1. The Child (Reader View)
                widget.child,

                // 2. Warmth Layer (Amber/Orange)
                // Optimization: Don't render if negligible
                if (warmth > 0.01)
                  IgnorePointer(
                    child: Container(
                      color: Colors.amber.withOpacity(warmth * 0.3),
                      foregroundDecoration: BoxDecoration(
                        backgroundBlendMode: BlendMode.multiply,
                        color: Colors.orangeAccent.withOpacity(warmth * 0.2),
                      ),
                    ),
                  ),

                // 3. Dimming Layer (Black)
                if (dimOpacity > 0.01)
                  IgnorePointer(
                    child: Container(
                      color: Colors.black.withOpacity(dimOpacity),
                    ),
                  ),

                // 4. Gesture Detector (Left Edge - Safe Zones logic in handler)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 30.0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: _onVerticalDragStart,
                    onVerticalDragUpdate: _onVerticalDragUpdate,
                    onVerticalDragEnd: _onVerticalDragEnd,
                    child: Container(color: Colors.transparent),
                  ),
                ),

                // 5. Brightness Indicator (Centered)
                if (_showIndicator)
                  Center(
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (prefs.brightness ?? 0.5) > 0.6
                                  ? Icons.brightness_7
                                  : (prefs.brightness ?? 0.5) > 0.2
                                      ? Icons.brightness_6
                                      : Icons.brightness_3,
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${((prefs.brightness ?? 0.0) * 100).toInt()}%",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
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
