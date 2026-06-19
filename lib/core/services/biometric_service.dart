import 'package:local_auth/local_auth.dart';

/// Thin wrapper around [LocalAuthentication] for biometric / device-credential
/// unlock. Used exclusively by [PinOverlayPage] in verify mode.
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
    } catch (_) {
      return false;
    }
  }

  /// Triggers the OS biometric prompt. [localizedReason] is shown to the user
  /// in the system dialog. Returns true on successful authentication.
  Future<bool> authenticate(String localizedReason) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
