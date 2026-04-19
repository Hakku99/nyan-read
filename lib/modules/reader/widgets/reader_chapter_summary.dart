import 'package:nyan_read/core/utils/chapter_heading_display.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../reader_engine/reader_engine.dart';

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
      chapters[currentChapterIndex].title,
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
