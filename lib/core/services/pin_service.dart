import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

/// Service for managing privacy PIN
/// Handles PIN setup, verification, and secure storage
class PinService {
  static final PinService _instance = PinService._internal();
  static PinService get instance => _instance;

  PinService._internal();

  final _storage = const FlutterSecureStorage();
  static const String _pinKey = 'privacy_pin_hash';
  static const String _pinSaltKey = 'privacy_pin_salt';

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

  /// Verify if the provided PIN matches the stored PIN
  Future<bool> verifyPin(String pin) async {
    if (!_isValidPin(pin)) {
      return false;
    }

    final storedHash = await _storage.read(key: _pinKey);
    final salt = await _storage.read(key: _pinSaltKey);

    if (storedHash == null || salt == null) {
      return false;
    }

    final hash = _hashPin(pin, salt);
    return hash == storedHash;
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
