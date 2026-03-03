import 'package:flutter/foundation.dart';
import '../../lib/core/models/book.dart';
import '../../lib/core/models/highlight.dart';
import '../../lib/modules/reader/reader_engine/reader_engine.dart';
import '../../lib/modules/reader/controllers/content_meta_manager.dart';

class MockContentMetaManager implements ContentMetaManager {
  @override
  final ReaderEngine engine;
  @override
  final Book book;
  @override
  final VoidCallback onMetaChanged;

  MockContentMetaManager({
    required this.engine,
    required this.book,
    required this.onMetaChanged,
  });

  @override
  List<dynamic> get chapters => [];

  @override
  int? get currentChapterIndex => 0;

  @override
  List<Highlight> get highlights => [];

  @override
  Future<void> addHighlight(int paragraphIndex, int start, int end, String text,
      String colorCode, String paragraphText) async {}

  @override
  Future<void> deleteHighlight(String highlightId) async {}

  @override
  Future<void> jumpToChapter(int index, dynamic chapterData,
      Future<void> Function() saveProgressFn) async {}

  @override
  Future<void> jumpToNextChapter(
      Future<void> Function() saveProgressFn) async {}

  @override
  Future<void> jumpToPreviousChapter(
      Future<void> Function() saveProgressFn) async {}

  @override
  Future<void> loadChapters() async {}

  @override
  Future<void> loadHighlights() async {}

  @override
  Future<void> updateCurrentChapterIndex() async {}

  @override
  Future<void> updateHighlight(String highlightId,
      {String? note, String? colorCode}) async {}
}
