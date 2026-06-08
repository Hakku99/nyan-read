import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nyan_read/core/theme/nyan_spacing.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
/// Minimalist 4-digit PIN input widget — dot matrix display + numeric keypad.
///
/// Theme-agnostic: the host [PinOverlayPage] resolves the takeover palette
/// (cream-light tokens vs. bespoke ink literals) and injects the single
/// [foreground] ink colour. Dots, keypad fill, border and glyphs are all
/// derived from it via alpha, matching the U16 mock's `color-mix` recipe.
/// Source: `screens/bundle4.jsx` `PinDots` + `NumPad`.
class PinInputWidget extends StatefulWidget {
  final Function(String pin) onPinComplete;
  final Color foreground;
  final bool isError;
  final VoidCallback? onError;

  const PinInputWidget({
    super.key,
    required this.onPinComplete,
    required this.foreground,
    this.isError = false,
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

  // Mock `pin-shake`: ±8px horizontal over 320ms. We drive a sine envelope so
  // the dots settle back to centre regardless of where the curve lands.
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
    // One gentle tap on mismatch — AGENTS.md §4.3 keeps haptics restrained.
    HapticFeedback.lightImpact();
    _shakeController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _pin = '';
      });
      widget.onError?.call();
    });
  }

  void _onNumberPressed(int number) {
    if (_pin.length < 4) {
      setState(() {
        _pin += number.toString();
      });

      HapticFeedback.selectionClick();

      if (_pin.length == 4) {
        widget.onPinComplete(_pin);
      }
    }
  }

  void _onDeletePressed() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
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
            // Damped sine: two full swings inside the 320ms window, decaying to
            // centre so the dots never end up offset. Matches mock `pin-shake`.
            final t = _shakeAnimation.value;
            final dx = _kShakeAmplitude * (1 - t) * math.sin(t * 4 * math.pi);
            return Transform.translate(
              offset: Offset(dx, 0),
              child: child,
            );
          },
          child: _buildPinDots(),
        ),
        const SizedBox(height: 48),
        _buildKeypad(),
      ],
    );
  }

  Widget _buildPinDots() {
    // Mock: 16px dots, 20px gap, 1.5px border.
    // Border alpha softens on error (38%) vs. resting (56%).
    final borderAlpha = widget.isError ? 0.38 : 0.56;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < _pin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: NyanSpacing.space12 - 2),
          width: NyanSpacing.space16,
          height: NyanSpacing.space16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? widget.foreground : Colors.transparent,
            border: Border.all(
              color: widget.foreground.withValues(alpha: borderAlpha),
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        _buildKeypadRow([1, 2, 3]),
        const SizedBox(height: NyanSpacing.space12),
        _buildKeypadRow([4, 5, 6]),
        const SizedBox(height: NyanSpacing.space12),
        _buildKeypadRow([7, 8, 9]),
        const SizedBox(height: NyanSpacing.space12),
        _buildKeypadRow([null, 0, -1]), // null = empty, -1 = delete
      ],
    );
  }

  Widget _buildKeypadRow(List<int?> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: numbers.map((number) {
        if (number == null) {
          return const SizedBox(width: 72, height: 72);
        } else if (number == -1) {
          return _buildKeypadButton(
            // Mock renders the ⌫ Unicode glyph as plain text at 22pt, not a
            // Phosphor icon — match the handoff literally (bundle4.jsx NumPad).
            child: Text(
              '⌫',
              style: TextStyle(
                fontFamily: NyanTypography.uiFontFamily,
                fontSize: NyanTypography.pinKeyGlyph,
                fontWeight: FontWeight.w400,
                color: widget.foreground,
              ),
            ),
            onPressed: _onDeletePressed,
          );
        } else {
          return _buildKeypadButton(
            child: Text(
              number.toString(),
              style: TextStyle(
                fontFamily: NyanTypography.uiFontFamily,
                fontSize: NyanTypography.pinKeyDigit,
                fontWeight: FontWeight.w400,
                color: widget.foreground,
              ),
            ),
            onPressed: () => _onNumberPressed(number),
          );
        }
      }).toList(),
    );
  }

  Widget _buildKeypadButton({
    required Widget child,
    required VoidCallback onPressed,
  }) {
    // Mock key: 72×72 circle, fg@10% fill, fg@16% border, subtle press feedback.
    final fg = widget.foreground;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: NyanSpacing.space8),
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fg.withValues(alpha: 0.10),
        border: Border.all(
          color: fg.withValues(alpha: 0.16),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          splashColor: fg.withValues(alpha: 0.12),
          highlightColor: fg.withValues(alpha: 0.06),
          child: Center(child: child),
        ),
      ),
    );
  }
}
