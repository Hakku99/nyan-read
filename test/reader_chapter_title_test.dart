import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/widgets/reader_chapter_summary.dart';

void main() {
  const pdfChapter = ReaderChapter(
    title: '',
    locator: ChapterLocator(pageNumber: 11),
    isSynthetic: true,
  );
  const untitled = ReaderChapter(title: '', locator: ChapterLocator());

  for (final (locale, page, chapter) in [
    (const Locale('en'), 'Page 11', 'Chapter 3'),
    (const Locale('zh'), '第 11 页', '第 3 章'),
  ]) {
    testWidgets('chapter titles are localized for ${locale.languageCode}',
        (tester) async {
      late AppLocalizations loc;
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          loc = AppLocalizations.of(context)!;
          return const SizedBox();
        }),
      ));
      expect(readerChapterTitle(pdfChapter, 1, loc), page);
      expect(readerChapterTitle(untitled, 2, loc), chapter);
      expect(
          readerChapterTitle(
              const ReaderChapter(
                  title: 'Intro', locator: ChapterLocator(), index: 0),
              0,
              loc),
          'Intro');
      expect(
          readerChapterSummaryLabel(
              chapters: const [pdfChapter, pdfChapter],
              currentChapterIndex: 1,
              loc: loc),
          page);
    });
  }
}
