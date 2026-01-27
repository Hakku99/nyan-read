import 'dart:io';
import 'package:encrypt/encrypt.dart' as encrypt;

import 'package:shared_preferences/shared_preferences.dart';

// Stub interface for Privacy Logic
abstract class IPrivacyService {
  Future<File> encryptFile(File source);
  Future<List<int>> decryptFileToMemory(String encryptedPath);
  Future<bool> authenticate(String pin);
  Future<void> setPin(String pin);
}

class PrivacyService implements IPrivacyService {
  // In production, this key should be stored in Flutter Secure Storage
  // For prototype, we generate/store loosely or hardcode a dev key
  // AES-256 requires 32 bytes key
  final _key = encrypt.Key.fromUtf8('my32lengthsupersecretnooneknows1'); 
  final _iv = encrypt.IV.fromLength(16);

  @override
  Future<File> encryptFile(File source) async {
    final encrypter = encrypt.Encrypter(encrypt.AES(_key));
    final bytes = await source.readAsBytes();
    final encrypted = encrypter.encryptBytes(bytes, iv: _iv);

    // Save with a custom extension to hide from system scanners
    final newPath = '${source.parent.path}/${source.uri.pathSegments.last}.nyanlock';
    final dest = File(newPath);
    await dest.writeAsBytes(encrypted.bytes);
    
    // Original file should be deleted in real usage
    // await source.delete(); 
    
    return dest;
  }

  @override
  Future<List<int>> decryptFileToMemory(String encryptedPath) async {
    final file = File(encryptedPath);
    if (!await file.exists()) return [];

    final encrypter = encrypt.Encrypter(encrypt.AES(_key));
    final bytes = await file.readAsBytes();
    
    final decrypted = encrypter.decryptBytes(encrypt.Encrypted(bytes), iv: _iv);
    return decrypted;
  }

  @override
  Future<bool> authenticate(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString('privacy_pin');
    if (storedPin == null) return true; // No pin set yet
    
    // In real app, hash the pin input before comparing
    return storedPin == pin;
  }

  @override
  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('privacy_pin', pin);
  }
}
