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

  /// 閸旂姾娴囨妯瑰瘨 + 閸撳秶鐤嗛悩鑸碘偓浣藉殰閹?(State Pre-processing)
  ///
  /// 闁潧鎯婇崡鏇炴倻閺佺増宓佸ù浣稿斧閸掓瑱绱板銈嗘煙濞夋洘妲搁崬顖欑閻?閼奉亝鍓ゅù浣规寜缁?閵?
  /// UI 鐏?(TxtReaderEngine) 閸欘亙绱伴弨璺哄煂閸ф劖鐖ｇ紒婵嗩嚠閸嬨儱鎮嶉惃?`List<Highlight>`閵?
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

  /// 閸楁洘顐肩粩鐘哄Ν妤傛ü瀵掗懛顏呭墹缁狅紕鍤?(閸愬懘鍎?
  ///
  /// Fast-Path: offset 濮ｆ柨顕崡鍐插讲閿? I/O閵?
  /// Slow-Path: AnchorHealer 閸欏苯鎮滈弶鍐櫢娴犺尪顥?+ 閸楀啿褰傞崡鍐茬磾(fire-and-forget)閸ョ偛鍟?DB閵?
  Future<List<Highlight>> _healHighlights(
    List<Highlight> raw,
    TextReaderCapability textCapability,
  ) async {
    final healedList = <Highlight>[];

    for (final h in raw) {
      // 1. 閸欐牕鍤▓浣冩儰閸樼喐鏋?
      final paragraphText = textCapability.getParagraphText(h.paragraphIndex);
      if (paragraphText == null) {
        // 濞堜絻鎯ゆ稉宥呯摠閸︻煉绱濇穱婵堟殌閸樼喐鐗遍敍鍫ユЩ濮濄垹绌垮┃鍐跨礆
        healedList.add(h);
        continue;
      }

      // 2. Fast-Path閿涙氨鏁ら崢鐔奉潗 offset 閹搭亜褰囬獮鏈电瑢 selectedText 濮ｆ柨顕?
      final start = h.startOffset;
      final end = h.endOffset;
      final isOffsetValid = start >= 0 &&
          end <= paragraphText.length &&
          start < end &&
          paragraphText.substring(start, end) == h.selectedText;

      if (isOffsetValid) {
        // 閸ф劖鐖ｉ崑銉ユ倣閿涘瞼娲块幒銉ュ弳闂?
        healedList.add(h);
        continue;
      }

      // 婵″倹鐏?preContext 娑撹櫣鈹栭敍鍧? 閺冄勬殶閹诡噯绱氶敍宀冪儲鏉╁洩鍤滈幇鍫礉闁繋绱堕崢鐔奉潗閸?
      if (h.preContext.isEmpty && h.postContext.isEmpty) {
        debugPrint('[ContentMetaManager] 閺冄勬殶閹诡喗妫ら柨姘卞仯娣団剝浼呴敍宀冪儲鏉╁洩鍤滈幇? ${h.selectedText}');
        healedList.add(h);
        continue;
      }

      // 3. Slow-Path閿涙nchorHealer 閹兼粍鏅?
      final newStart = AnchorHealer.findHealedOffset(
        paragraphText,
        h.preContext,
        h.selectedText,
        h.postContext,
      );

      if (newStart != null) {
        final newEnd = newStart + h.selectedText.length;
        debugPrint(
            '[ContentMetaManager] 妤傛ü瀵掗崸鎰垼閼奉亝鍓ら幋鎰: "${h.selectedText}" $start閳?newStart');

        final healed = h.copyWith(
          startOffset: newStart,
          endOffset: newEnd,
          isHealed: 1,
        );
        healedList.add(healed);

        // 閸楀啿褰傞崡鍐茬磾閿涙艾绱撳銉ユ礀閸?DB閿涘瞼绮风€甸€涚瑝闂冭顢?UI 濞撳弶鐓嬬敮?
        _db.updateHighlightHealedOffset(h.id, newStart, newEnd);
      } else {
        debugPrint(
            '[ContentMetaManager] 妤傛ü瀵掗崸鎰垼閹兼粍鏅虫径杈Е閿涘奔娑鍐╄閺屾搫绱欐稉宥呯┛濠у喛绱? ${h.selectedText}');
        // 閹兼粍鏅虫径杈Е閿涙矮娑鍐跨礉娑撳秴濮為崗銉ヤ淮鎼村嘲鍨悰顭掔礉闂冨弶顒涢柨娆掝嚖濞撳弶鐓?
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

  /// 閺傛澘顤冩妯瑰瘨閺冭绱濋崥灞绢劄闁插洦鐗?pre/post context 闁挎氨鍋ｉ敍灞界摠閸?DB
  Future<void> addHighlight(int paragraphIndex, int start, int end, String text,
      String colorCode, String paragraphText) async {
    // 闁插洦鐗遍梼鑸殿唽閿涙碍褰侀崣鏍у閸?5鐎涙顑侀悧鐟扮窙
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


