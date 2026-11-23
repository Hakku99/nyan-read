import 'dart:math' as math;

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

  /// Reads only the size plus the first and last [sampleBytes] of a
  /// `content://` document (no whole-book copy): `head` is the first
  /// min(size, sampleBytes) bytes, `tail` the last [sampleBytes] when
  /// size > sampleBytes and empty otherwise.
  ///
  /// Returns null whenever that is not possible — non-Android, stale APK
  /// without the handler, provider without a known size or random access, or a
  /// reply whose lengths do not match the contract — and the caller must use
  /// its whole-file path instead.
  static Future<({int size, Uint8List head, Uint8List tail})?> sampleUri(
    String uri, {
    required int sampleBytes,
  }) async {
    if (!_isAndroid) return null;
    try {
      final reply = await _channel.invokeMapMethod<String, Object?>(
        'sampleUri',
        {'uri': uri, 'sampleBytes': sampleBytes},
      );
      if (reply == null) return null;
      final size = (reply['size'] as num).toInt();
      final head = reply['head'] as Uint8List;
      final tail = reply['tail'] as Uint8List;
      // Guard against a provider that answered with the wrong amount of
      // data: a bad sample would silently produce a different signature.
      if (head.length != math.min(size, sampleBytes) ||
          tail.length != (size > sampleBytes ? sampleBytes : 0)) {
        return null;
      }
      return (size: size, head: head, tail: tail);
    } catch (e) {
      // MissingPluginException (stale APK) and provider errors both land here.
      debugPrint('sampleUri fell back to full read: ${e.runtimeType}');
      return null;
    }
  }

  // ── Library folders (docs/DESIGN_LIBRARY_FOLDERS.md) ────────────────────

  /// Launches the system directory picker (ACTION_OPEN_DOCUMENT_TREE) and
  /// persists the tree grant. Returns `{uri, name}`, or null when the user
  /// cancels.
  static Future<Map<String, dynamic>?> pickLibraryFolder() async {
    if (!_isAndroid) return null;
    return await _channel
        .invokeMapMethod<String, dynamic>('pickLibraryFolder');
  }

  /// Recursively enumerates book files (txt/epub/pdf) under a persisted
  /// tree grant. Returns `{documents: [{uri,name,size,lastModified}],
  /// truncated, elapsedMs}`.
  static Future<Map<String, dynamic>> listTreeDocuments(String treeUri) async {
    if (!_isAndroid) {
      throw UnsupportedError('Tree enumeration is Android-only.');
    }
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'listTreeDocuments',
      {'uri': treeUri},
    );
    if (result == null) {
      throw StateError('Failed to enumerate tree: $treeUri');
    }
    return result;
  }

  /// Returns `{totalCount, trees: [{uri, name}]}` — the system's persisted
  /// grant table IS the library-folder registry (no app-side copy).
  static Future<Map<String, dynamic>> listPersistedPermissions() async {
    if (!_isAndroid) return const {'totalCount': 0, 'trees': []};
    final result = await _channel
        .invokeMapMethod<String, dynamic>('listPersistedPermissions');
    return result ?? const {'totalCount': 0, 'trees': []};
  }

  /// Number of persisted grants the app holds (0 off Android or on failure).
  /// Android caps these per app, so a high count means new per-file imports
  /// will start evicting older books' grants.
  static Future<int> persistedGrantCount() async {
    try {
      final result = await listPersistedPermissions();
      return (result['totalCount'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('persistedGrantCount failed: ${e.runtimeType}');
      return 0;
    }
  }

  /// Releases a persisted grant (folder removal; also quota give-back when
  /// deleting legacy per-file books). True only if the app's persisted-grant
  /// count actually dropped. The system may record a grant under a different
  /// URI form than the picker returned (Downloads: `msf:` vs `raw:`), so the
  /// release is attempted even without an exact URI match.
  static Future<bool> releasePersistedPermission(String uri) async {
    if (!_isAndroid) return false;
    final released = await _channel.invokeMethod<bool>(
      'releasePersistedPermission',
      {'uri': uri},
    );
    return released ?? false;
  }

  /// SAF-probe cleanup only: releases every persisted grant. Returns the
  /// number released.
  static Future<int> releaseAllPersistedPermissions() async {
    if (!_isAndroid) return 0;
    final released =
        await _channel.invokeMethod<int>('releaseAllPersistedPermissions');
    return released ?? 0;
  }

  /// SAF-probe only: multi-select picker that persists every picked uri, to
  /// observe real quota-limit behavior. Returns
  /// `{attempted, persisted, failed, firstError, grantCountAfter}` or null
  /// on cancel.
  static Future<Map<String, dynamic>?> pickAndPersistManyFiles() async {
    if (!_isAndroid) return null;
    return await _channel
        .invokeMapMethod<String, dynamic>('pickAndPersistManyFiles');
  }

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
