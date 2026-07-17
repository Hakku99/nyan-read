/// PIN hashing scheme tests (2026-07 hardening):
///   1. New records use a CSPRNG salt + iterated SHA-256.
///   2. Legacy records (timestamp salt + single SHA-256 round, no iterations
///      key) still verify — and are upgraded in place on first success, so
///      no existing user is ever locked out by the scheme change.
///   3. Brute-force lockout survives the refactor.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/pin_service.dart';

/// The exact pre-upgrade hash: sha256(pin + salt), single round.
String legacyHash(String pin, String salt) =>
    sha256.convert(utf8.encode(pin + salt)).toString();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('set + verify roundtrip; wrong PIN rejected', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final service = PinService();

    await service.setPin('1234');
    expect(await service.hasPinSet(), isTrue);
    expect(await service.verifyPin('1234'), isTrue);
    expect(await service.verifyPin('4321'), isFalse);
  });

  test('salt is unpredictable and per-record', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    final service = PinService();

    await service.setPin('1234');
    final salt1 = await storage.read(key: 'privacy_pin_salt');
    await service.setPin('1234');
    final salt2 = await storage.read(key: 'privacy_pin_salt');

    // 16 random bytes hex-encoded — not a 13-digit epoch timestamp.
    expect(salt1, hasLength(32));
    expect(salt1, isNot(salt2));
  });

  test('legacy record verifies and is upgraded in place', () async {
    const pin = '1234';
    const salt = '1719999999999'; // timestamp-style legacy salt
    FlutterSecureStorage.setMockInitialValues({
      'privacy_pin_hash': legacyHash(pin, salt),
      'privacy_pin_salt': salt,
      // no privacy_pin_iterations key → legacy scheme
    });
    const storage = FlutterSecureStorage();
    final service = PinService();

    expect(await service.verifyPin(pin), isTrue);

    // Upgrade happened: iterations marker written, hash and salt rewritten.
    expect(await storage.read(key: 'privacy_pin_iterations'), isNotNull);
    expect(await storage.read(key: 'privacy_pin_salt'), isNot(salt));
    expect(await storage.read(key: 'privacy_pin_hash'),
        isNot(legacyHash(pin, salt)));

    // And the upgraded record still verifies (iterated path).
    expect(await service.verifyPin(pin), isTrue);
    expect(await service.verifyPin('0000'), isFalse);
  });

  test('legacy record with wrong PIN is rejected, not upgraded', () async {
    const salt = '1719999999999';
    FlutterSecureStorage.setMockInitialValues({
      'privacy_pin_hash': legacyHash('1234', salt),
      'privacy_pin_salt': salt,
    });
    const storage = FlutterSecureStorage();
    final service = PinService();

    expect(await service.verifyPin('9999'), isFalse);
    expect(await storage.read(key: 'privacy_pin_iterations'), isNull);
  });

  test('5 failures lock out even the correct PIN', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final service = PinService();
    await service.setPin('1234');

    for (var i = 0; i < 5; i++) {
      expect(await service.verifyPin('0000'), isFalse);
    }
    expect(await service.verifyPin('1234'), isFalse,
        reason: 'lockout window must reject the correct PIN too');
  });

  test('resetPin clears the iterations marker with the record', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    final service = PinService();

    await service.setPin('1234');
    await service.resetPin();

    expect(await service.hasPinSet(), isFalse);
    expect(await storage.read(key: 'privacy_pin_iterations'), isNull);
  });
}
