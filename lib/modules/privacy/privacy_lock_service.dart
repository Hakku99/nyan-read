import 'package:flutter/material.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/pin_service.dart';
import 'pin_overlay_page.dart';

/// Facade over PIN + biometric unlock flows.
///
/// Registered in get_it with constructor-injected services (§2.3); UI
/// obtains it via `privacyLockServiceRpProvider`.
class PrivacyLockService {
  PrivacyLockService(this._pinService, this._biometricService);

  final PinService _pinService;
  final BiometricService _biometricService;

  /// Check if a PIN has been set up
  Future<bool> hasPassword() async {
    return await _pinService.hasPinSet();
  }

  /// Verify password (kept for backward compatibility, delegates to PIN)
  Future<bool> verifyPassword(String input) async {
    if (input.length == 4 && RegExp(r'^\d{4}$').hasMatch(input)) {
      return await _pinService.verifyPin(input);
    }
    return false;
  }

  /// Set password (kept for backward compatibility, delegates to PIN)
  Future<void> setPassword(String password) async {
    if (password.length == 4 && RegExp(r'^\d{4}$').hasMatch(password)) {
      await _pinService.setPin(password);
    }
  }

  /// Show PIN setup overlay
  Future<bool> showPinSetup(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PinOverlayPage(
          mode: PinOverlayMode.setup,
          pinService: _pinService,
        ),
        opaque: false,
        barrierDismissible: false,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    return result ?? false;
  }

  /// Show PIN verification overlay
  Future<bool> showPinVerify(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PinOverlayPage(
          mode: PinOverlayMode.verify,
          pinService: _pinService,
          biometricService: _biometricService,
        ),
        opaque: false,
        barrierDismissible: false,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    return result ?? false;
  }
}
