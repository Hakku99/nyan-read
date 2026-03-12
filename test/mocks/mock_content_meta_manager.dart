import 'package:flutter/foundation.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/models/highlight.dart';
import 'package:nyan_read/modules/reader/controllers/content_meta_manager.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';

class MockContentMetaManager implements ContentMetaManager {
  MockContentMetaManager({
    required this.engine,
    required this.book,
    required this.onMetaChanged,
  });

  @override
  final ReaderEngine engine;

  @override
  final Book book;

  @override
  final VoidCallback onMetaChanged;

  @override
  List<ReaderChapter> get chapters => const [];

  @override
  int? get currentChapterIndex => 0;

  @override
  List<Highlight> get highlights => [];

  @override
  Highlight? findHighlightById(String highlightId) => null;

  @override
  Future<bool> addBookmark() async => true;

  @override
  Future<void> backfillBookmarkSnippets() async {}

  @override
  Future<void> addHighlight(
    int paragraphIndex,
    int start,
    int end,
    String text,
    String colorCode,
    String paragraphText,
  ) async {}

  @override
  Future<void> deleteHighlight(String highlightId) async {}

  @override
  Future<void> jumpToChapter(
    int index,
    ChapterLocator locator,
    Future<void> Function() saveProgressFn,
  ) async {}

  @override
  Future<void> jumpToNextChapter(
    Future<void> Function() saveProgressFn,
  ) async {}

  @override
  Future<void> jumpToPreviousChapter(
    Future<void> Function() saveProgressFn,
  ) async {}

  @override
  Future<void> loadChapters() async {}

  @override
  Future<void> loadHighlights() async {}

  @override
  Future<void> openHighlight(Highlight highlight) async {}

  @override
  Future<void> restoreBookmarkPosition(Map<String, dynamic> bookmarkData) async {}

  @override
  Future<void> syncCurrentChapterFromPosition(
    ReadingPosition? position, {
    int? preferredIndex,
  }) async {}

  @override
  Future<void> updateCurrentChapterIndex() async {}

  @override
  Future<void> updateHighlight(
    String highlightId, {
    String? note,
    String? colorCode,
  }) async {}
}
