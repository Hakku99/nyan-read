import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BookSourcePlatform {
  static const MethodChannel _channel =
      MethodChannel('com.example.nyan_read/book_source');

  static Future<bool> persistReadPermission(String uri) async {
    if (!_isAndroid) return false;
    final granted = await _channel.invokeMethod<bool>(
      'persistReadPermission',
      {'uri': uri},
    );
    return granted ?? false;
  }

  static Future<bool> isUriReadable(String uri) async {
    if (!_isAndroid) return false;
    final readable = await _channel.invokeMethod<bool>(
      'isUriReadable',
      {'uri': uri},
    );
    return readable ?? false;
  }

  static Future<Uint8List> readUriBytes(String uri) async {
    if (!_isAndroid) {
      throw UnsupportedError('Android content Uri reading is unsupported.');
    }
    final bytes = await _channel.invokeMethod<Uint8List>(
      'readUriBytes',
      {'uri': uri},
    );
    if (bytes == null) {
      throw StateError('Failed to read bytes for Uri: $uri');
    }
    return bytes;
  }

  /// Deletes a document exposed via a persisted `content://` Uri (SAF).
  ///
  /// Returns false on non-Android, invalid Uri, or when the provider denies
  /// delete (e.g. missing persistable write permission).
  static Future<bool> deletePersistedUriDocument(String uri) async {
    if (!_isAndroid) return false;
    final trimmed = uri.trim();
    if (!trimmed.toLowerCase().startsWith('content://')) return false;
    try {
      final deleted = await _channel.invokeMethod<bool>(
        'deletePersistedUriDocument',
        {'uri': trimmed},
      );
      return deleted ?? false;
    } on MissingPluginException catch (_) {
      // Hot reload / hot restart does not pick up MainActivity.kt changes.
      debugPrint(
        'deletePersistedUriDocument: MissingPluginException — the Android '
        'native handler is missing from the running APK. Stop the app and '
        'install a full debug/release build (`flutter run` or rebuild APK), '
        'not hot reload.',
      );
      return false;
    } catch (e, stackTrace) {
      debugPrint('deletePersistedUriDocument failed: $e\n$stackTrace');
      return false;
    }
  }

  static Future<String> copyUriToTempFile(
    String uri, {
    required String extension,
  }) async {
    if (!_isAndroid) {
      throw UnsupportedError('Android content Uri temp copy is unsupported.');
    }
    final tempPath = await _channel.invokeMethod<String>(
      'copyUriToTempFile',
      {
        'uri': uri,
        'extension': extension,
      },
    );
    if (tempPath == null || tempPath.isEmpty) {
      throw StateError('Failed to materialize temp file for Uri: $uri');
    }
    return tempPath;
  }

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
