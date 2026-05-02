import 'package:flutter/material.dart';
import '../../../core/services/pin_service.dart';
import 'widgets/pin_input_widget.dart';

enum PinOverlayMode { setup, verify, change }

/// Full-screen dark overlay for PIN input
/// Minimalist design with no redundant text
class PinOverlayPage extends StatefulWidget {
  final PinOverlayMode mode;
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;

  const PinOverlayPage({
    super.key,
    required this.mode,
    this.onSuccess,
    this.onCancel,
  });

  @override
  State<PinOverlayPage> createState() => _PinOverlayPageState();
}

class _PinOverlayPageState extends State<PinOverlayPage> {
  final _pinService = PinService.instance;
  bool _isError = false;
  String? _firstPin; // For setup/change mode confirmation

  String get _title {
    switch (widget.mode) {
      case PinOverlayMode.setup:
        return _firstPin == null ? 'Set PIN' : 'Confirm PIN';
      case PinOverlayMode.verify:
        return 'Enter PIN';
      case PinOverlayMode.change:
        return _firstPin == null ? 'New PIN' : 'Confirm PIN';
    }
  }

  Future<void> _handlePinComplete(String pin) async {
    if (widget.mode == PinOverlayMode.setup) {
      await _handleSetup(pin);
    } else if (widget.mode == PinOverlayMode.verify) {
      await _handleVerify(pin);
    } else if (widget.mode == PinOverlayMode.change) {
      await _handleChange(pin);
    }
  }

  Future<void> _handleSetup(String pin) async {
    if (_firstPin == null) {
      // First entry
      setState(() {
        _firstPin = pin;
        _isError = false;
      });
    } else {
      // Confirmation
      if (_firstPin == pin) {
        await _pinService.setPin(pin);
        widget.onSuccess?.call();
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _isError = true;
          _firstPin = null;
        });
      }
    }
  }

  Future<void> _handleVerify(String pin) async {
    final isValid = await _pinService.verifyPin(pin);
    if (isValid) {
      widget.onSuccess?.call();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _isError = true;
      });
    }
  }

  Future<void> _handleChange(String pin) async {
    if (_firstPin == null) {
      // First entry (new PIN)
      setState(() {
        _firstPin = pin;
        _isError = false;
      });
    } else {
      // Confirmation
      if (_firstPin == pin) {
        // Note: In real implementation, you'd verify old PIN first
        await _pinService.setPin(pin);
        widget.onSuccess?.call();
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _isError = true;
          _firstPin = null;
        });
      }
    }
  }

  void _handleError() {
    setState(() {
      _isError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Minimal title
                  Text(
                    _title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 64),
                  // PIN input
                  PinInputWidget(
                    onPinComplete: _handlePinComplete,
                    isError: _isError,
                    onError: _handleError,
                  ),
                ],
              ),
            ),
            // Cancel button (top-right)
            if (widget.onCancel != null)
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    widget.onCancel?.call();
                    Navigator.of(context).pop(false);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
