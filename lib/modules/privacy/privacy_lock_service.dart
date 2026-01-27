import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyLockService {
  static const String _prefKeyHash = 'privacy_password_hash';

  Future<bool> hasPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_prefKeyHash);
  }

  Future<bool> verifyPassword(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_prefKeyHash);
    if (storedHash == null) return false;

    final inputHash = sha256.convert(utf8.encode(input)).toString();
    return inputHash == storedHash;
  }

  Future<void> setPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = sha256.convert(utf8.encode(password)).toString();
    await prefs.setString(_prefKeyHash, hash);
  }
}
