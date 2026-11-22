import 'package:flutter/foundation.dart';

import '../../core/models/highlight.dart';
import '../../core/services/database_service.dart';
import '../reader/reader_engine/reader_engine.dart';

/// Read/write path for the per-book highlights and bookmarks *pages*
/// (§3.2: Widgets must not touch [DatabaseService] directly).
///
/// This is deliberately NOT the reader's source of truth for highlights —
/// that stays [ContentMetaManager]. A reader that opens these pages reloads
/// its in-memory list when they pop (see `_openHighlightsPage`).
///
/// Every load method lets DB errors propagate: the pages must be able to tell
/// "read failed" apart from "nothing saved", otherwise a transient failure
/// looks like lost notes.
class BookAnnotationsController {
  const BookAnnotationsController(this._db);

  final DatabaseService _db;

  /// Newest first.
  Future<List<Highlight>> loadHighlights(String bookId) async {
    final rows = await _db.getHighlights(bookId);
    return rows.map(Highlight.fromMap).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<Map<String, dynamic>>> loadBookmarks(String bookId) async {
    final rows = await _db.getBookmarks(bookId);
    return sortBookmarksForDisplay(rows);
  }

  Future<void> updateHighlight(String id, {String? note, String? colorCode}) =>
      _db.updateHighlight(id, note: note, colorCode: colorCode);

  Future<void> deleteHighlight(String id) => _db.deleteHighlight(id);

  Future<void> deleteBookmark(String id) => _db.deleteBookmark(id);
}

/// Orders bookmarks to match the page's date-grouped layout: days newest
/// first, and inside a day by position in the book.
///
/// The DB's `page_index` column cannot do this — new bookmarks always write 0
/// there (the real location lives in `position_payload`), so it sorts as
/// physical row order. Rows whose payload cannot be parsed sort after the
/// located ones of the same day, oldest first.
List<Map<String, dynamic>> sortBookmarksForDisplay(
  List<Map<String, dynamic>> rows,
) {
  // Decode each payload once, not once per comparison.
  final keyed = [
    for (final row in rows)
      (
        row: Map<String, dynamic>.from(row),
        day: _dayKey(row['created_at']),
        pos: _positionKey(row),
        created: row['created_at'] is int ? row['created_at'] as int : 0,
      ),
  ];

  keyed.sort((a, b) {
    final byDay = b.day.compareTo(a.day);
    if (byDay != 0) return byDay;

    final ap = a.pos;
    final bp = b.pos;
    if (ap != null && bp != null) {
      final byMajor = ap.major.compareTo(bp.major);
      if (byMajor != 0) return byMajor;
      final byMinor = ap.minor.compareTo(bp.minor);
      if (byMinor != 0) return byMinor;
    } else if (ap != null) {
      return -1;
    } else if (bp != null) {
      return 1;
    }

    final byCreated = a.created.compareTo(b.created);
    if (byCreated != 0) return byCreated;
    // List.sort is not stable; the id keeps the order deterministic.
    return '${a.row['id']}'.compareTo('${b.row['id']}');
  });

  return [for (final k in keyed) k.row];
}

/// Local-calendar day as yyyymmdd, matching the page's date headers.
int _dayKey(Object? createdAt) {
  if (createdAt is! int) return 0;
  final d = DateTime.fromMillisecondsSinceEpoch(createdAt);
  return d.year * 10000 + d.month * 100 + d.day;
}

/// TXT/EPUB locate by paragraph, PDF by page; a book has one format, so the
/// two never mix inside one list.
({int major, int minor})? _positionKey(Map<String, dynamic> row) {
  final payload = row['position_payload'];
  if (payload is! String) return null;
  try {
    final type = (row['position_type'] ?? '').toString().toLowerCase();
    final position = ReadingPosition.fromJson(type, payload);
    final major = position.paragraphIndex ?? position.pageNumber;
    if (major == null) return null;
    return (major: major, minor: position.textOffset ?? 0);
  } catch (e) {
    debugPrint('[BookAnnotationsController] Unparseable bookmark position: $e');
    return null;
  }
}
