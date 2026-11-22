import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Outcome of an OS authentication prompt. [error] is kept apart from
/// [cancelled] so the UI can say "unavailable" instead of failing silently
/// (a misconfigured Activity once made the fingerprint key a no-op).
enum BiometricResult { success, cancelled, error }

/// Thin wrapper around [LocalAuthentication] for biometric / device-credential
/// unlock. Used by [PinOverlayPage] in verify mode and by the forgot-PIN flow.
///
/// Registered as a get_it singleton; injected via [PrivacyLockService].
class BiometricService {
  final _auth = LocalAuthentication();

  /// Returns true when the device has enrolled biometrics and the platform
  /// supports checking them (Touch ID, Face ID, fingerprint, Windows Hello…).
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (e) {
      debugPrint('[BiometricService] isAvailable error: $e');
      return false;
    }
  }

  /// True when the OS can authenticate the owner at all — biometrics OR a
  /// device PIN/pattern/password. Gate for the forgot-PIN "verify with device
  /// lock" path, which must also work for users with no fingerprint enrolled.
  Future<bool> isDeviceAuthSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('[BiometricService] isDeviceAuthSupported error: $e');
      return false;
    }
  }

  /// Triggers the OS prompt. [localizedReason] is shown to the user in the
  /// system dialog. With [biometricOnly] false the device lock screen
  /// credential is accepted as well.
  Future<BiometricResult> authenticate(
    String localizedReason, {
    bool biometricOnly = true,
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
        ),
      );
      return ok ? BiometricResult.success : BiometricResult.cancelled;
    } catch (e) {
      debugPrint('[BiometricService] authenticate error: $e');
      return BiometricResult.error;
    }
  }
}
