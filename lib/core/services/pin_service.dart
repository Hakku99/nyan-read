import 'dart:convert';
import 'dart:math';
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
  static const String _pinIterationsKey = 'privacy_pin_iterations';
  static const String _failedAttemptsKey = 'privacy_pin_failed_attempts';
  static const String _lockoutUntilKey = 'privacy_pin_lockout_until';

  // 10k rounds of SHA-256 (~ms on-device): raises a 10^4-space offline brute
  // force from trivial to mildly costly. Not a KDF-grade promise — the
  // private shelf is a visibility gate, not encryption (AGENTS §2.4).
  static const int _hashIterations = 10000;

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

    final salt = _generateSalt();
    final hash = _hashPinIterated(pin, salt, _hashIterations);

    await _storage.write(key: _pinKey, value: hash);
    await _storage.write(key: _pinSaltKey, value: salt);
    // The iterations key doubles as the scheme marker: records without it
    // are legacy (timestamp salt + single SHA-256 round) and get verified —
    // then upgraded — through the legacy path in [verifyPin].
    await _storage.write(key: _pinIterationsKey, value: '$_hashIterations');
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

    final iterationsRaw = await _storage.read(key: _pinIterationsKey);
    final iterations = iterationsRaw == null ? null : int.tryParse(iterationsRaw);
    final hash = iterations == null
        ? _hashPinLegacy(pin, salt)
        : _hashPinIterated(pin, salt, iterations);
    if (hash == storedHash) {
      await _clearFailureState();
      if (iterations == null) {
        // Upgrade-on-verify: rewrite the legacy record with a secure salt +
        // iterated hash. Old hashes stay valid until the owner types the PIN
        // once, so no user ever gets locked out by the scheme change.
        await setPin(pin);
      }
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
    await _storage.delete(key: _pinIterationsKey);
  }

  /// Check if a PIN string is valid (4 digits)
  bool _isValidPin(String pin) {
    if (pin.length != 4) return false;
    return RegExp(r'^\d{4}$').hasMatch(pin);
  }

  /// 16 random bytes from a CSPRNG, hex-encoded.
  String _generateSalt() {
    final rng = Random.secure();
    return List<int>.generate(16, (_) => rng.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Current scheme: SHA-256 over `salt:pin`, then re-hashed [iterations]-1
  /// times. The `:` separator also makes the preimage disjoint from the
  /// legacy `pin + salt` concatenation.
  String _hashPinIterated(String pin, String salt, int iterations) {
    var digest = sha256.convert(utf8.encode('$salt:$pin'));
    for (var i = 1; i < iterations; i++) {
      digest = sha256.convert(digest.bytes);
    }
    return digest.toString();
  }

  /// Pre-2026-07 scheme (timestamp salt, single round). Kept only to verify
  /// records written before the upgrade; never used for new writes.
  String _hashPinLegacy(String pin, String salt) {
    return sha256.convert(utf8.encode(pin + salt)).toString();
  }

  /// Validate PIN format (for UI validation)
  static bool isValidPinFormat(String pin) {
    return pin.length == 4 && RegExp(r'^\d{4}$').hasMatch(pin);
  }
}
