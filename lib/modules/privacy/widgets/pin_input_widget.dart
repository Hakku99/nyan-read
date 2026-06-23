import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';

// Internal layout constants sourced from bundle4.jsx NumPad — not exposed as
// NyanSpacing tokens since these are PIN keypad-exclusive values.
const double _kKeySize = 74;
const double _kKeyColGap = 20; // gap between keys in a row
const double _kKeyRowGap = 15; // gap between rows
const double _kDotSize = 13;
const double _kDotGap = 17; // gap between dots in the row

/// Minimalist 4-digit PIN input — dot row + numeric keypad.
///
/// The host [PinOverlayPage] resolves all colours from the active theme (or the
/// bespoke ink palette for dark mode) and passes them in. This widget is
/// colour-agnostic; every tint is a parameter.
/// Source: `screens/bundle4.jsx` `PinDots` + `NumPad`.
class PinInputWidget extends StatefulWidget {
  final Function(String pin) onPinComplete;

  /// Colour for a filled dot (primary in light; bespoke ink in dark).
  final Color dotFill;

  /// Colour for the unfilled dot ring border — `nyan.textPrimary @ 26%`.
  final Color dotRing;

  /// Colour for dots + message when there is a PIN mismatch.
  final Color dotError;

  /// Number-key background (`nyan.surface` in light; tinted in dark).
  final Color keyBackground;

  /// Elevation shadow for number keys (empty in dark — tint provides contrast).
  final List<BoxShadow> keyShadow;

  /// Digit text colour — `nyan.textPrimary`.
  final Color keyText;

  /// Ghost-key (delete / biometric) icon colour — `nyan.textMuted`.
  final Color ghostColor;

  final bool isError;

  /// Show the fingerprint biometric key in the bottom-left cell (verify mode).
  final bool showBiometric;

  /// Called when the biometric key is tapped. Null hides the button entirely.
  final VoidCallback? onBiometricTap;

  final VoidCallback? onError;

  const PinInputWidget({
    super.key,
    required this.onPinComplete,
    required this.dotFill,
    required this.dotRing,
    required this.dotError,
    required this.keyBackground,
    required this.keyShadow,
    required this.keyText,
    required this.ghostColor,
    this.isError = false,
    this.showBiometric = false,
    this.onBiometricTap,
    this.onError,
  });

  @override
  State<PinInputWidget> createState() => _PinInputWidgetState();
}

class _PinInputWidgetState extends State<PinInputWidget>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  static const double _kShakeAmplitude = 8;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PinInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isError && !oldWidget.isError) {
      _triggerError();
    }
  }

  void _triggerError() {
    HapticFeedback.lightImpact();
    _shakeController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() => _pin = '');
      widget.onError?.call();
    });
  }

  void _onNumberPressed(int number) {
    if (_pin.length < 4) {
      setState(() => _pin += number.toString());
      HapticFeedback.selectionClick();
      if (_pin.length == 4) widget.onPinComplete(_pin);
    }
  }

  void _onDeletePressed() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            final t = _shakeAnimation.value;
            final dx =
                _kShakeAmplitude * (1 - t) * math.sin(t * 4 * math.pi);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: _buildPinDots(),
        ),
        const SizedBox(height: 42),
        _buildKeypad(),
      ],
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final isFilled = i < _pin.length;
        final dotColor = widget.isError ? widget.dotError : widget.dotFill;
        // Spec: each container is 13×13 with gap:17. The halo uses inset:-6
        // (overflows 6px on every side). Clip.none lets the halo bleed without
        // widening the item, keeping gap math identical to the CSS flex layout.
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kDotGap / 2),
          child: SizedBox(
            width: _kDotSize,
            height: _kDotSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Soft halo — positioned -6px outside the 13×13 container.
                Positioned(
                  top: -6,
                  left: -6,
                  child: AnimatedOpacity(
                    opacity: isFilled ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: AnimatedScale(
                      scale: isFilled ? 1.0 : 0.4,
                      duration: const Duration(milliseconds: 220),
                      child: Container(
                        width: _kDotSize + 12, // 13 + 6*2
                        height: _kDotSize + 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor.withValues(alpha: 0.16),
                        ),
                      ),
                    ),
                  ),
                ),
                // The dot itself
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: _kDotSize,
                  height: _kDotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? dotColor : Colors.transparent,
                    border: Border.all(
                      color: isFilled ? dotColor : widget.dotRing,
                      width: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow([1, 2, 3]),
        SizedBox(height: _kKeyRowGap),
        _buildRow([4, 5, 6]),
        SizedBox(height: _kKeyRowGap),
        _buildRow([7, 8, 9]),
        SizedBox(height: _kKeyRowGap),
        _buildRow([null, 0, -1]),
      ],
    );
  }

  Widget _buildRow(List<int?> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((k) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kKeyColGap / 2),
          child: _buildKey(k),
        );
      }).toList(),
    );
  }

  Widget _buildKey(int? key) {
    if (key == null) {
      // Empty cell or biometric
      return SizedBox(
        width: _kKeySize,
        height: _kKeySize,
        child: widget.showBiometric
            ? _ghostButton(
                icon: NyanIcons.fingerprint,
                size: NyanTypography.pinKeyGlyph,
                // Biometric uses primary colour per spec — dotFill is primary.
                color: widget.dotFill,
                onTap: widget.onBiometricTap ?? () {},
                semanticLabel: 'Unlock with biometrics',
              )
            : null,
      );
    }

    if (key == -1) {
      return _ghostButton(
        icon: NyanIcons.backspace,
        size: NyanTypography.pinKeyGlyph,
        color: widget.ghostColor,
        onTap: _onDeletePressed,
        semanticLabel: 'Delete',
        width: _kKeySize,
        height: _kKeySize,
      );
    }

    // Number key — surface card with subtle shadow
    return SizedBox(
      width: _kKeySize,
      height: _kKeySize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.keyBackground,
          boxShadow: widget.keyShadow,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _onNumberPressed(key),
            customBorder: const CircleBorder(),
            splashColor: widget.keyText.withValues(alpha: 0.08),
            highlightColor: widget.keyText.withValues(alpha: 0.04),
            child: Center(
              child: Text(
                key.toString(),
                style: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  fontSize: NyanTypography.pinKeyDigit,
                  fontWeight: FontWeight.w500,
                  color: widget.keyText,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ghostButton({
    required IconData icon,
    required double size,
    required Color color,
    required VoidCallback onTap,
    required String semanticLabel,
    double width = _kKeySize,
    double height = _kKeySize,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          splashColor: color.withValues(alpha: 0.10),
          highlightColor: color.withValues(alpha: 0.05),
          child: Semantics(
            label: semanticLabel,
            child: Center(
              child: Icon(icon, size: size, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
