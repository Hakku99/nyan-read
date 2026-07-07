import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/book.dart';
import '../../../core/models/highlight.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/anchor_healer.dart';
import '../reader_engine/reader_engine.dart';

class ContentMetaManager {
  final ReaderEngine engine;
  final Book book;
  final VoidCallback onMetaChanged;
  final DatabaseService databaseService;

  List<ReaderChapter> _chapters = const [];
  int? _currentChapterIndex;
  List<Highlight> _highlights = [];

  DatabaseService get _db => databaseService;
  TextReaderCapability? get _textCapability => engine.textCapability;
  TextExtractionCapability? get _textExtractionCapability =>
      engine.textExtractionCapability;

  ContentMetaManager({
    required this.engine,
    required this.book,
    required this.onMetaChanged,
    required this.databaseService,
  });

  List<ReaderChapter> get chapters => _chapters;
  int? get currentChapterIndex => _currentChapterIndex;
  List<Highlight> get highlights => List<Highlight>.unmodifiable(_highlights);

  Highlight? findHighlightById(String highlightId) {
    for (final highlight in _highlights) {
      if (highlight.id == highlightId) return highlight;
    }
    return null;
  }

  Future<void> loadChapters() async {
    _chapters = await engine.getChapters();
    onMetaChanged();
  }

  /// Loads persisted highlights and heals stale anchors *before* handing the
  /// list to the render layer (TxtReaderEngine), so the UI only ever sees
  /// highlights whose offsets are valid for the current text.
  Future<void> loadHighlights() async {
    try {
      final rawData = await _db.getHighlights(book.id);
      final rawHighlights = rawData.map((m) => Highlight.fromMap(m)).toList();

      List<Highlight> healthyHighlights;
      if (engine.capabilities.supportsHighlights && _textCapability != null) {
        healthyHighlights = await _healHighlights(rawHighlights, _textCapability!);
      } else {
        healthyHighlights = rawHighlights;
      }

      _replaceSessionHighlights(healthyHighlights);
    } catch (e) {
      debugPrint('[ContentMetaManager] Error loading highlights: $e');
    }
  }

  void _replaceSessionHighlights(List<Highlight> highlights) {
    _highlights = List<Highlight>.unmodifiable(highlights);
    _syncTxtRenderHighlights();
    onMetaChanged();
  }

  void _syncTxtRenderHighlights() {
    _textCapability?.setHighlights(_highlights);
  }

  /// Heals highlight anchors whose stored offsets no longer select the
  /// original text (e.g. after a decode or parse change shifted paragraph
  /// offsets).
  ///
  /// Fast-Path: stored offsets still match [Highlight.selectedText] — no I/O.
  /// Slow-Path: AnchorHealer re-locates the anchor off the UI thread, then
  /// writes the healed offsets back to DB fire-and-forget.
  Future<List<Highlight>> _healHighlights(
    List<Highlight> raw,
    TextReaderCapability textCapability,
  ) async {
    final healedList = <Highlight>[];

    for (final h in raw) {
      final paragraphText = textCapability.getParagraphText(h.paragraphIndex);
      if (paragraphText == null) {
        // Paragraph unavailable (out of range / not loaded); keep as-is.
        healedList.add(h);
        continue;
      }

      // Fast-Path: stored offsets still select the original text.
      final start = h.startOffset;
      final end = h.endOffset;
      final isOffsetValid = start >= 0 &&
          end <= paragraphText.length &&
          start < end &&
          paragraphText.substring(start, end) == h.selectedText;

      if (isOffsetValid) {
        healedList.add(h);
        continue;
      }

      // Legacy rows persisted before context capture have nothing to heal
      // against; keep them unchanged rather than guessing.
      if (h.preContext.isEmpty && h.postContext.isEmpty) {
        debugPrint(
            '[ContentMetaManager] Highlight has no pre/post context to heal against; keeping as-is: ${h.selectedText}');
        healedList.add(h);
        continue;
      }

      // Slow-Path: AnchorHealer re-locates the anchor.
      // Offload to isolate to keep string matching off UI thread.
      final newStart = await Isolate.run(
        () => AnchorHealer.findHealedOffset(
          paragraphText,
          h.preContext,
          h.selectedText,
          h.postContext,
        ),
      );

      if (newStart != null) {
        final newEnd = newStart + h.selectedText.length;
        debugPrint(
            '[ContentMetaManager] Healed highlight anchor: "${h.selectedText}" $start -> $newStart');

        final healed = h.copyWith(
          startOffset: newStart,
          endOffset: newEnd,
          isHealed: 1,
        );
        healedList.add(healed);

        // Fire-and-forget write-back: a lost write only means healing
        // re-runs on the next open, so blocking the load loop is not worth it.
        unawaited(_db.updateHighlightHealedOffset(h.id, newStart, newEnd));
      } else {
        debugPrint(
            '[ContentMetaManager] Anchor healing failed; keeping stale offsets (may not render): ${h.selectedText}');
        // Keep the row so the user's note text survives even if the
        // highlight can no longer be painted at the right spot.
      }
    }

    return healedList;
  }

  Future<void> updateCurrentChapterIndex() async {
    await syncCurrentChapterFromPosition(engine.getCurrentPosition());
  }

  Future<void> syncCurrentChapterFromPosition(
    ReadingPosition? position, {
    int? preferredIndex,
  }) async {
    if (_chapters.isEmpty || position == null) return;

    final preferredValid = preferredIndex != null &&
        preferredIndex >= 0 &&
        preferredIndex < _chapters.length;

    // After [jumpToChapter], the viewport anchor can still sit on text that
    // resolves to the *previous* TOC entry; paragraph-based sync would then
    // overwrite [preferredIndex] and break prev/next chapter navigation.
    if (preferredValid) {
      final newIndex = preferredIndex;
      if (_currentChapterIndex != newIndex) {
        _currentChapterIndex = newIndex;
        onMetaChanged();
      }
      return;
    }

    int newIndex = 0;

    if (position.paragraphIndex != null) {
      final currentPara = position.paragraphIndex!;
      int maxStartPara = -1;

      for (int i = 0; i < _chapters.length; i++) {
        // TXT uses [ChapterLocator.chapterIndex] (paragraph line); EPUB uses
        // [ChapterLocator.contentIndex] (flat paragraph index in the spine).
        final loc = _chapters[i].locator;
        final chapterPara =
            loc.contentIndex ?? loc.chapterIndex ?? -1;
        if (chapterPara != -1 && chapterPara <= currentPara) {
          if (chapterPara > maxStartPara) {
            maxStartPara = chapterPara;
            newIndex = i;
          } else if (chapterPara == maxStartPara) {
            newIndex = i;
          }
        }
      }
    } else if (position.pageNumber != null) {
      final currentPage = position.pageNumber!;
      int maxStartPage = -1;

      for (int i = 0; i < _chapters.length; i++) {
        final chapterPage = _chapters[i].locator.pageNumber ?? -1;
        if (chapterPage != -1 && chapterPage <= currentPage) {
          if (chapterPage > maxStartPage) {
            maxStartPage = chapterPage;
            newIndex = i;
          }
        }
      }
    } else if (_currentChapterIndex != null) {
      newIndex = _currentChapterIndex!;
    }

    if (_currentChapterIndex != newIndex) {
      _currentChapterIndex = newIndex;
      onMetaChanged();
    }
  }

  Future<void> jumpToChapter(
    int index,
    ChapterLocator locator,
    Future<void> Function() saveProgressFn,
  ) async {
    try {
      await engine.goToChapter(locator);

      await syncCurrentChapterFromPosition(
        engine.getCurrentPosition(),
        preferredIndex: index,
      );
      await saveProgressFn();
    } catch (e) {
      debugPrint('[ContentMetaManager] Error jumping to chapter: $e');
    }
  }

  Future<void> jumpToPreviousChapter(
      Future<void> Function() saveProgressFn) async {
    await syncCurrentChapterFromPosition(engine.getCurrentPosition());
    if (_currentChapterIndex == null || _currentChapterIndex! <= 0) return;
    await jumpToChapter(
      _currentChapterIndex! - 1,
      _chapters[_currentChapterIndex! - 1].locator,
      saveProgressFn,
    );
  }

  Future<void> jumpToNextChapter(Future<void> Function() saveProgressFn) async {
    await syncCurrentChapterFromPosition(engine.getCurrentPosition());
    if (_currentChapterIndex == null ||
        _currentChapterIndex! >= _chapters.length - 1) {
      return;
    }
    await jumpToChapter(
      _currentChapterIndex! + 1,
      _chapters[_currentChapterIndex! + 1].locator,
      saveProgressFn,
    );
  }

  Future<void> restoreBookmarkPosition(Map<String, dynamic> bookmarkData) async {
    final type =
        (bookmarkData['position_type'] ?? book.format).toString().toLowerCase();
    final payload = bookmarkData['position_payload'];

    if (payload == null) return;

    try {
      final position = ReadingPosition.fromJson(type, payload);
      if (position.hasLocation) {
        await engine.goToPosition(position);
      }
    } catch (e) {
      debugPrint('[ContentMetaManager] Error restoring bookmark position: $e');
    }
  }

  Future<bool> addBookmark() async {
    final position = engine.getCurrentPosition();
    if (position == null) return false;

    final snippet = await _textExtractionCapability?.getSnippet();
    final bookmark = {
      'id': const Uuid().v4(),
      'book_id': book.id,
      'page_index': 0,
      'position_type': book.format,
      'position_payload': position.toJson(),
      'content_snippet': snippet,
      'note': '',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };

    await _db.insertBookmark(bookmark);
    return true;
  }

  Future<void> backfillBookmarkSnippets() async {
    try {
      final bookmarks = await _db.getBookmarks(book.id);
      for (final bm in bookmarks) {
        if (bm['content_snippet'] == null ||
            (bm['content_snippet'] as String).isEmpty) {
          final payload = bm['position_payload'];
          final type = bm['position_type'] ?? book.format;

          if (payload != null) {
            final pos = ReadingPosition.fromJson(type.toString(), payload);
            if (pos.hasLocation) {
              final text = await _textExtractionCapability?.getTextAtPosition(pos);
              if (text != null && text.isNotEmpty) {
                await _db.updateBookmark(bm['id'], {
                  'content_snippet': text,
                });
                debugPrint('Backfilled snippet for bookmark ${bm['id']}');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error backfilling snippets: $e');
    }
  }

  Future<void> openHighlight(Highlight highlight) async {
    try {
      await engine.goToPosition(
        ReadingPosition(paragraphIndex: highlight.paragraphIndex),
      );
    } catch (e) {
      debugPrint('[ContentMetaManager] Error opening highlight: $e');
    }
  }

  /// Adds a highlight, capturing up to 15 chars of surrounding text on each
  /// side as [Highlight.preContext]/[Highlight.postContext] — the anchors
  /// [_healHighlights] needs if offsets ever go stale.
  Future<void> addHighlight(int paragraphIndex, int start, int end, String text,
      String colorCode, String paragraphText) async {
    final preContext = start > 0
        ? paragraphText.substring((start - 15).clamp(0, start), start)
        : '';
    final postContext = end < paragraphText.length
        ? paragraphText.substring(
            end, (end + 15).clamp(end, paragraphText.length))
        : '';

    final highlight = Highlight(
      id: const Uuid().v4(),
      bookId: book.id,
      paragraphIndex: paragraphIndex,
      startOffset: start,
      endOffset: end,
      selectedText: text,
      colorCode: colorCode,
      createdAt: DateTime.now(),
      preContext: preContext,
      postContext: postContext,
    );
    await _db.insertHighlight(highlight.toMap());
    _highlights = List<Highlight>.unmodifiable([..._highlights, highlight]);
    _syncTxtRenderHighlights();
    onMetaChanged();
  }

  Future<void> updateHighlight(String highlightId,
      {String? note, String? colorCode}) async {
    await _db.updateHighlight(highlightId, note: note, colorCode: colorCode);
    final now = DateTime.now();
    _highlights = List<Highlight>.unmodifiable(
      _highlights.map((h) {
        if (h.id != highlightId) return h;
        return h.copyWith(
          note: note ?? h.note,
          colorCode: colorCode ?? h.colorCode,
          updatedAt: now,
        );
      }),
    );
    _syncTxtRenderHighlights();
    onMetaChanged();
  }

  Future<void> deleteHighlight(String highlightId) async {
    await _db.deleteHighlight(highlightId);
    _highlights = List<Highlight>.unmodifiable(
      _highlights.where((h) => h.id != highlightId),
    );
    _syncTxtRenderHighlights();
    onMetaChanged();
  }
}
