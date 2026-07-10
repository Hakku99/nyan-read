import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

/// Service for managing privacy PIN
/// Handles PIN setup, verification, secure storage, and brute-force lockout.
///
/// Registered as a get_it singleton; injected via [PrivacyLockService].
class PinService {
  PinService();

  final _storage = const FlutterSecureStorage();
  static const String _pinKey = 'privacy_pin_hash';
  static const String _pinSaltKey = 'privacy_pin_salt';
  static const String _failedAttemptsKey = 'privacy_pin_failed_attempts';
  static const String _lockoutUntilKey = 'privacy_pin_lockout_until';

  // 5 wrong PINs → 30s lockout. Persisted in secure storage so restarting
  // the app does not reset the window. A 4-digit PIN is inherently weak
  // (10^4 space); this only stops casual rapid guessing, not forensics.
  static const int _maxFailedAttempts = 5;
  static const Duration _lockoutDuration = Duration(seconds: 30);

  /// Check if a PIN has been set
  Future<bool> hasPinSet() async {
    final hash = await _storage.read(key: _pinKey);
    return hash != null;
  }

  /// Set a new PIN (must be 4 digits)
  ///
  /// Throws [ArgumentError] if PIN is not 4 digits
  Future<void> setPin(String pin) async {
    if (!_isValidPin(pin)) {
      throw ArgumentError('PIN must be exactly 4 digits');
    }

    // Generate a random salt for additional security
    final salt = DateTime.now().millisecondsSinceEpoch.toString();
    final hash = _hashPin(pin, salt);

    await _storage.write(key: _pinKey, value: hash);
    await _storage.write(key: _pinSaltKey, value: salt);
  }

  /// Verify if the provided PIN matches the stored PIN.
  ///
  /// Rate-limited: after [_maxFailedAttempts] consecutive failures every
  /// attempt is rejected until [_lockoutDuration] elapses.
  // ponytail: lockout surfaces as the generic wrong-PIN shake in the
  // overlay; add a dedicated "try again in Ns" hint if users get confused.
  Future<bool> verifyPin(String pin) async {
    if (!_isValidPin(pin)) {
      return false;
    }
    if (await _isLockedOut()) {
      return false;
    }

    final storedHash = await _storage.read(key: _pinKey);
    final salt = await _storage.read(key: _pinSaltKey);

    if (storedHash == null || salt == null) {
      return false;
    }

    final hash = _hashPin(pin, salt);
    if (hash == storedHash) {
      await _clearFailureState();
      return true;
    }

    await _recordFailedAttempt();
    return false;
  }

  Future<bool> _isLockedOut() async {
    final raw = await _storage.read(key: _lockoutUntilKey);
    final until = raw == null ? null : int.tryParse(raw);
    if (until == null) return false;
    if (DateTime.now().millisecondsSinceEpoch >= until) {
      await _storage.delete(key: _lockoutUntilKey);
      return false;
    }
    return true;
  }

  Future<void> _recordFailedAttempt() async {
    final raw = await _storage.read(key: _failedAttemptsKey);
    final failures = (raw == null ? 0 : int.tryParse(raw) ?? 0) + 1;
    if (failures >= _maxFailedAttempts) {
      final until = DateTime.now().add(_lockoutDuration);
      await _storage.write(
          key: _lockoutUntilKey, value: '${until.millisecondsSinceEpoch}');
      await _storage.delete(key: _failedAttemptsKey);
    } else {
      await _storage.write(key: _failedAttemptsKey, value: '$failures');
    }
  }

  Future<void> _clearFailureState() async {
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockoutUntilKey);
  }

  /// Change the PIN (requires old PIN verification)
  ///
  /// Returns true if successful, false if old PIN is incorrect
  Future<bool> changePin(String oldPin, String newPin) async {
    final isValid = await verifyPin(oldPin);
    if (!isValid) {
      return false;
    }

    await setPin(newPin);
    return true;
  }

  /// Reset the PIN (clears stored PIN)
  /// WARNING: This should only be called after additional verification
  Future<void> resetPin() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _pinSaltKey);
  }

  /// Check if a PIN string is valid (4 digits)
  bool _isValidPin(String pin) {
    if (pin.length != 4) return false;
    return RegExp(r'^\d{4}$').hasMatch(pin);
  }

  /// Hash a PIN with salt using SHA-256
  String _hashPin(String pin, String salt) {
    final combined = pin + salt;
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Validate PIN format (for UI validation)
  static bool isValidPinFormat(String pin) {
    return pin.length == 4 && RegExp(r'^\d{4}$').hasMatch(pin);
  }
}
