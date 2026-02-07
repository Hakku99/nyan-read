import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Minimalist 4-digit PIN input widget
/// Features a dot matrix display and numeric keypad
class PinInputWidget extends StatefulWidget {
  final Function(String pin) onPinComplete;
  final bool isError;
  final VoidCallback? onError;

  const PinInputWidget({
    Key? key,
    required this.onPinComplete,
    this.isError = false,
    this.onError,
  }) : super(key: key);

  @override
  State<PinInputWidget> createState() => _PinInputWidgetState();
}

class _PinInputWidgetState extends State<PinInputWidget>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
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
    HapticFeedback.vibrate();
    _shakeController.forward(from: 0).then((_) {
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
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // PIN Dots Display
          _buildPinDots(),
          const SizedBox(height: 48),
          // Numeric Keypad
          _buildKeypad(),
        ],
      ),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < _pin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? Colors.white : Colors.transparent,
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 2,
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
        const SizedBox(height: 16),
        _buildKeypadRow([4, 5, 6]),
        const SizedBox(height: 16),
        _buildKeypadRow([7, 8, 9]),
        const SizedBox(height: 16),
        _buildKeypadRow([null, 0, -1]), // null = empty, -1 = delete
      ],
    );
  }

  Widget _buildKeypadRow(List<int?> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: numbers.map((number) {
        if (number == null) {
          return const SizedBox(width: 80, height: 80);
        } else if (number == -1) {
          return _buildKeypadButton(
            child: const Icon(Icons.backspace_outlined, color: Colors.white),
            onPressed: _onDeletePressed,
          );
        } else {
          return _buildKeypadButton(
            child: Text(
              number.toString(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                color: Colors.white,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 80,
      height: 80,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Center(child: child),
        ),
      ),
    );
  }
}
