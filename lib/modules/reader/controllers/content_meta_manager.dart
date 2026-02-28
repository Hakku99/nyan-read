import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/book.dart';
import '../../../core/models/highlight.dart';
import '../../../core/services/database_service.dart';
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

  ContentMetaManager({
    required this.engine,
    required this.book,
    required this.onMetaChanged,
  });

  List<dynamic> get chapters => _chapters;
  int? get currentChapterIndex => _currentChapterIndex;
  List<Highlight> get highlights => _highlights;

  Future<void> loadChapters() async {
    _chapters = await engine.getChapters();
    onMetaChanged();
  }

  Future<void> loadHighlights() async {
    try {
      final data = await DatabaseService().getHighlights(book.id);
      _highlights = data.map((m) => Highlight.fromMap(m)).toList();
      if (engine is TxtReaderEngine) {
        (engine as TxtReaderEngine).setHighlights(_highlights);
      }
      onMetaChanged();
    } catch (e) {
      debugPrint("Error loading highlights: $e");
    }
  }

  Future<void> updateCurrentChapterIndex() async {
    if (_chapters.isEmpty) return;

    final position = engine.getCurrentPosition();
    if (position == null) return;

    int newIndex = 0;

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
    } else {
      if (_currentChapterIndex != null) {
        newIndex = _currentChapterIndex!;
      }
    }

    if (_currentChapterIndex != newIndex) {
      _currentChapterIndex = newIndex;
      onMetaChanged();
    }
  }

  Future<void> jumpToChapter(int index, dynamic chapterData,
      Future<void> Function() saveProgressFn) async {
    try {
      _currentChapterIndex = index;

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

      await saveProgressFn();
      onMetaChanged();
    } catch (e) {
      debugPrint('Error jumping to chapter: $e');
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

  Future<void> addHighlight(int paragraphIndex, int start, int end, String text,
      String colorCode) async {
    final highlight = Highlight(
      id: const Uuid().v4(),
      bookId: book.id,
      paragraphIndex: paragraphIndex,
      startOffset: start,
      endOffset: end,
      selectedText: text,
      colorCode: colorCode,
      createdAt: DateTime.now(),
    );
    await DatabaseService().insertHighlight(highlight.toMap());
    await loadHighlights();
  }

  Future<void> updateHighlight(String highlightId,
      {String? note, String? colorCode}) async {
    await DatabaseService()
        .updateHighlight(highlightId, note: note, colorCode: colorCode);
    await loadHighlights();
  }

  Future<void> deleteHighlight(String highlightId) async {
    await DatabaseService().deleteHighlight(highlightId);
    await loadHighlights();
  }
}
