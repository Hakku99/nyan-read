import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../models/book.dart';
import '../utils/book_import_fingerprint.dart';
import 'database_service.dart';

/// Incrementally computes and stores `content_signature` for legacy books that
/// were imported before the signature field existed.
///
/// Runs a single background sweep on startup (after a 15s grace period to let
/// the UI settle). Processes one book at a time using Isolate.run() for the
/// SHA-256 computation. Stops when disposed.
class SignatureBackfillService {
  final DatabaseService _db;

  SignatureBackfillService(this._db);

  bool _disposed = false;
  Timer? _startupTimer;

  /// Call once after DI is ready. Delays start by [delay] to avoid racing
  /// cold-start I/O.
  void scheduleBackfill({Duration delay = const Duration(seconds: 15)}) {
    _startupTimer = Timer(delay, _runBackfillSweep);
  }

  Future<void> _runBackfillSweep() async {
    if (_disposed) return;

    List<Map<String, dynamic>> legacy;
    try {
      legacy = await BookImportFingerprint.fetchLegacyBooksNeedingSignature(_db);
    } catch (e) {
      debugPrint('[SignatureBackfill] Failed to query legacy books: $e');
      return;
    }

    if (legacy.isEmpty) {
      debugPrint('[SignatureBackfill] No legacy books need backfill.');
      return;
    }

    debugPrint('[SignatureBackfill] Starting backfill for ${legacy.length} books.');
    int count = 0;

    for (final row in legacy) {
      if (_disposed) break;

      final bookId = row['id'] as String?;
      final sourceLocator = row['file_path'] as String?;
      final sourceType =
          BookSourceType.normalize(row['source_type'] as String?);

      if (bookId == null || sourceLocator == null || sourceLocator.isEmpty) {
        continue;
      }

      // Android content:// URIs require platform channels — cannot go to isolate.
      // File paths can be fully computed in an isolate.
      final String? signature;
      if (sourceType == BookSourceType.filePath) {
        try {
          // Offload file read + SHA-256 to a background isolate.
          signature = await Isolate.run(
            () => BookImportFingerprint.computeSync(sourceLocator),
          );
        } catch (e) {
          debugPrint('[SignatureBackfill] Isolate error for $bookId: $e');
          continue;
        }
      } else {
        // content:// and other URI types: compute on main isolate (platform channel).
        try {
          signature = await BookImportFingerprint.computeForSource(
            sourceType: sourceType,
            sourceLocator: sourceLocator,
            locatorHint: sourceLocator,
          );
        } catch (e) {
          debugPrint('[SignatureBackfill] Platform compute error for $bookId: $e');
          continue;
        }
      }

      if (_disposed) break;

      if (signature != null) {
        try {
          await _db.updateBookContentSignature(bookId, signature);
          count++;
          debugPrint('[SignatureBackfill] Backfilled book $bookId ($count/${legacy.length})');
        } catch (e) {
          debugPrint('[SignatureBackfill] DB update error for $bookId: $e');
        }
      }

      // Yield to the event loop between books so we don't starve the UI.
      await Future<void>.delayed(Duration.zero);
    }

    debugPrint('[SignatureBackfill] Sweep complete. Backfilled $count/${legacy.length} books.');
  }

  void dispose() {
    _disposed = true;
    _startupTimer?.cancel();
    _startupTimer = null;
  }
}
