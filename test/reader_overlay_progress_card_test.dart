import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/modules/reader/widgets/reader_settings/reader_settings_progress_card.dart';

void main() {
  testWidgets('ReaderSettingsProgressCard shows chapter nav when enabled',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ReaderSettingsProgressCard(
              chapterLabel: 'Chapter 1',
              progress: 0.42,
              showChapterNavigation: true,
              onSeek: (_) {},
              onPreviousChapter: () {},
              onNextChapter: () {},
              forOverlay: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('ReaderSettingsProgressCard hides chapter nav when disabled',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ReaderSettingsProgressCard(
              chapterLabel: 'No chapters',
              progress: 0.1,
              showChapterNavigation: false,
              onSeek: (_) {},
              onPreviousChapter: () {},
              onNextChapter: () {},
              forOverlay: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('ReaderSettingsProgressCard overlayWidth constrains card width',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ReaderSettingsProgressCard(
              chapterLabel: 'Chapter 2',
              progress: 0.3,
              showChapterNavigation: true,
              onSeek: (_) {},
              onPreviousChapter: () {},
              onNextChapter: () {},
              forOverlay: true,
              overlayWidth: 260,
            ),
          ),
        ),
      ),
    );

    final size =
        tester.getSize(find.byKey(const Key('reader-overlay-progress-card-surface')));
    expect(size.width, closeTo(260, 0.1));
  });
}
