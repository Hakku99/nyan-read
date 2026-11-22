import 'package:nyan_read/core/utils/chapter_heading_display.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../reader_engine/reader_engine.dart';

/// Display title for [chapter]; localizes untitled and synthetic entries.
String readerChapterTitle(
    ReaderChapter chapter, int index, AppLocalizations loc) {
  if (chapter.title.isNotEmpty) return chapter.title;
  final page = chapter.locator.pageNumber;
  return chapter.isSynthetic && page != null
      ? loc.pdfPageStart(page)
      : loc.chapterName(index + 1);
}

/// Human-readable chapter context for progress UI (menu overlay / sheet).
String readerChapterSummaryLabel({
  required List<ReaderChapter> chapters,
  required int? currentChapterIndex,
  required AppLocalizations loc,
}) {
  if (currentChapterIndex != null &&
      currentChapterIndex >= 0 &&
      currentChapterIndex < chapters.length) {
    final chapter = normalizeChapterHeadingForDisplay(
      readerChapterTitle(chapters[currentChapterIndex], currentChapterIndex, loc),
    ).trim();
    if (chapter.isNotEmpty) {
      return chapter;
    }
    return loc.chapterName(currentChapterIndex + 1);
  }

  if (chapters.isNotEmpty) {
    return loc.chapterCount(chapters.length);
  }

  return loc.noChaptersDetected;
}
