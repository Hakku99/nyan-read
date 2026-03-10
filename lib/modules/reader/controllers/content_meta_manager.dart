import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/book.dart';
import '../../../core/models/highlight.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/anchor_healer.dart';
import '../reader_engine/reader_engine.dart';
import '../reader_engine/txt/txt_reader.dart';
import '../reader_engine/epub/epub_position.dart';
import '../reader_engine/pdf/pdf_position.dart';
import '../reader_engine/txt/txt_position.dart';

class ContentMetaManager {
  final ReaderEngine engine;
  final Book book;
  final VoidCallback onMetaChanged;

  List<dynamic> _chapters = [];
  int? _currentChapterIndex;
  List<Highlight> _highlights = [];

  // DI: 通过 get_it 获取 DatabaseService，禁止直接 new DatabaseService()
  DatabaseService get _db => GetIt.instance<DatabaseService>();

  ContentMetaManager({
    required this.engine,
    required this.book,
    required this.onMetaChanged,
  });

  List<dynamic> get chapters => _chapters;
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

  /// 加载高亮 + 前置状态自愈 (State Pre-processing)
  ///
  /// 遵循单向数据流原则：此方法是唯一的"自愈流水线"。
  /// UI 层 (TxtReaderEngine) 只会收到坐标绝对健康的 List<Highlight>。
  Future<void> loadHighlights() async {
    try {
      final rawData = await _db.getHighlights(book.id);
      final rawHighlights = rawData.map((m) => Highlight.fromMap(m)).toList();

      List<Highlight> healthyHighlights;
      if (engine is TxtReaderEngine) {
        healthyHighlights = await _healHighlights(
          rawHighlights,
          engine as TxtReaderEngine,
        );
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
    if (engine is TxtReaderEngine) {
      (engine as TxtReaderEngine).setHighlights(_highlights);
    }
  }

  /// 单次章节高亮自愈管线 (内部)
  ///
  /// Fast-Path: offset 比对即可，0 I/O。
  /// Slow-Path: AnchorHealer 双向权重仲裁 + 即发即弃(fire-and-forget)回写 DB。
  Future<List<Highlight>> _healHighlights(
    List<Highlight> raw,
    TxtReaderEngine txtEngine,
  ) async {
    final healedList = <Highlight>[];

    for (final h in raw) {
      // 1. 取出段落原文
      final paragraphText = txtEngine.getParagraphText(h.paragraphIndex);
      if (paragraphText == null) {
        // 段落不存在，保留原样（防止崩溃）
        healedList.add(h);
        continue;
      }

      // 2. Fast-Path：用原始 offset 截取并与 selectedText 比对
      final start = h.startOffset;
      final end = h.endOffset;
      final isOffsetValid = start >= 0 &&
          end <= paragraphText.length &&
          start < end &&
          paragraphText.substring(start, end) == h.selectedText;

      if (isOffsetValid) {
        // 坐标健康，直接入队
        healedList.add(h);
        continue;
      }

      // 如果 preContext 为空（v4 旧数据），跳过自愈，透传原始值
      if (h.preContext.isEmpty && h.postContext.isEmpty) {
        debugPrint('[ContentMetaManager] 旧数据无锚点信息，跳过自愈: ${h.selectedText}');
        healedList.add(h);
        continue;
      }

      // 3. Slow-Path：AnchorHealer 搜救
      final newStart = AnchorHealer.findHealedOffset(
        paragraphText,
        h.preContext,
        h.selectedText,
        h.postContext,
      );

      if (newStart != null) {
        final newEnd = newStart + h.selectedText.length;
        debugPrint(
            '[ContentMetaManager] 高亮坐标自愈成功: "${h.selectedText}" $start→$newStart');

        final healed = h.copyWith(
          startOffset: newStart,
          endOffset: newEnd,
          isHealed: 1,
        );
        healedList.add(healed);

        // 即发即弃：异步回写 DB，绝对不阻塞 UI 渲染帧
        _db.updateHighlightHealedOffset(h.id, newStart, newEnd);
      } else {
        debugPrint(
            '[ContentMetaManager] 高亮坐标搜救失败，丢弃渲染（不崩溃）: ${h.selectedText}');
        // 搜救失败：丢弃，不加入健康列表，防止错误渲染
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

    int newIndex = preferredIndex ?? 0;

    if ((position is TxtReadingPosition && book.format == 'txt') ||
        (book.format == 'txt')) {
      final currentPara =
          (position is TxtReadingPosition) ? position.paragraphIndex : -1;
      int maxStartPara = -1;

      for (int i = 0; i < _chapters.length; i++) {
        final chapterPara = _chapters[i]['paragraphIndex'] as int? ?? -1;
        if (chapterPara != -1 && chapterPara <= currentPara) {
          if (chapterPara > maxStartPara) {
            maxStartPara = chapterPara;
            newIndex = i;
          } else if (chapterPara == maxStartPara) {
            newIndex = i;
          }
        }
      }
    } else if (position is PdfReadingPosition && book.format == 'pdf') {
      final currentPage = position.pageNumber;
      int maxStartPage = -1;

      for (int i = 0; i < _chapters.length; i++) {
        final chapterPage = _chapters[i]['pageNumber'] as int? ?? -1;
        if (chapterPage != -1 && chapterPage <= currentPage) {
          if (chapterPage > maxStartPage) {
            maxStartPage = chapterPage;
            newIndex = i;
          }
        }
      }
    } else if (_currentChapterIndex != null) {
      newIndex = preferredIndex ?? _currentChapterIndex!;
    }

    if (_currentChapterIndex != newIndex) {
      _currentChapterIndex = newIndex;
      onMetaChanged();
    }
  }

  Future<void> jumpToChapter(int index, dynamic chapterData,
      Future<void> Function() saveProgressFn) async {
    try {
      if (book.format == 'epub' && chapterData['anchor'] != null) {
        await engine
            .goToPosition(EpubReadingPosition(cfi: chapterData['anchor']));
      } else if (book.format == 'txt' &&
          chapterData['paragraphIndex'] != null) {
        await engine.goToPosition(
            TxtReadingPosition(paragraphIndex: chapterData['paragraphIndex']));
      } else if (book.format == 'pdf' && chapterData['pageNumber'] != null) {
        await engine.goToPosition(
            PdfReadingPosition(pageNumber: chapterData['pageNumber']));
      }

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
    if (_currentChapterIndex == null || _currentChapterIndex! <= 0) return;
    await jumpToChapter(_currentChapterIndex! - 1,
        _chapters[_currentChapterIndex! - 1], saveProgressFn);
  }

  Future<void> jumpToNextChapter(Future<void> Function() saveProgressFn) async {
    if (_currentChapterIndex == null ||
        _currentChapterIndex! >= _chapters.length - 1) return;
    await jumpToChapter(_currentChapterIndex! + 1,
        _chapters[_currentChapterIndex! + 1], saveProgressFn);
  }

  Future<void> restoreBookmarkPosition(Map<String, dynamic> bookmarkData) async {
    final type =
        (bookmarkData['position_type'] ?? book.format).toString().toLowerCase();
    final payload = bookmarkData['position_payload'];

    if (payload == null) return;

    try {
      ReadingPosition? position;
      if (type == 'epub') {
        position = EpubReadingPosition.fromJson(payload);
      } else if (type == 'pdf') {
        position = PdfReadingPosition.fromJson(payload);
      } else if (type == 'txt') {
        position = TxtReadingPosition.fromJson(payload);
      }

      if (position != null) {
        await engine.goToPosition(position);
      }
    } catch (e) {
      debugPrint('[ContentMetaManager] Error restoring bookmark position: $e');
    }
  }

  Future<bool> addBookmark() async {
    final position = engine.getCurrentPosition();
    if (position == null) return false;

    final snippet = await engine.getSnippet();
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
            ReadingPosition? pos;
            if (type == 'txt') {
              pos = TxtReadingPosition.fromJson(payload);
            } else if (type == 'epub') {
              pos = EpubReadingPosition.fromJson(payload);
            } else if (type == 'pdf') {
              pos = PdfReadingPosition.fromJson(payload);
            }

            if (pos != null) {
              final text = await engine.getTextAtPosition(pos);
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
      if (book.format == 'txt') {
        await engine.goToPosition(
          TxtReadingPosition(paragraphIndex: highlight.paragraphIndex),
        );
      }
    } catch (e) {
      debugPrint('[ContentMetaManager] Error opening highlight: $e');
    }
  }

  /// 新增高亮时，同步采样 pre/post context 锚点，存入 DB
  Future<void> addHighlight(int paragraphIndex, int start, int end, String text,
      String colorCode, String paragraphText) async {
    // 采样阶段：提取前后15字符特征
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
    await loadHighlights();
  }

  Future<void> updateHighlight(String highlightId,
      {String? note, String? colorCode}) async {
    await _db.updateHighlight(highlightId, note: note, colorCode: colorCode);
    await loadHighlights();
  }

  Future<void> deleteHighlight(String highlightId) async {
    await _db.deleteHighlight(highlightId);
    await loadHighlights();
  }
}
