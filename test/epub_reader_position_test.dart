import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/reader/reader_engine/epub/epub_reader.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../tool/reader_baseline/baseline_support.dart';

void main() {
  for (final mode in [PageTurnMode.tap, PageTurnMode.swipe]) {
    testWidgets(
        '${mode.name}: long paragraph crosses its tail and roundtrips 20 turns',
        (tester) async {
      final engine = await mountFixture(tester, 'epub', mode, oversized: true);
      final anchors = <ReadingPosition>[engine.getCurrentPosition()!];
      final progress = <double>[engine.getProgress()!];
      for (var i = 0; i < 20; i++) {
        await perform(tester, engine.nextPage);
        final current = engine.getCurrentPosition()!;
        expect(advanced(anchors.last, current), isTrue);
        anchors.add(current);
        expect(engine.getProgress(), greaterThan(progress.last));
        progress.add(engine.getProgress()!);
      }
      expect(anchors.last.paragraphIndex!, greaterThan(20));
      for (var i = 19; i >= 0; i--) {
        await perform(tester, engine.previousPage);
        expectSameViewport(anchors[i], engine.getCurrentPosition()!);
        expect(engine.getProgress(), closeTo(progress[i], .0002));
      }
    });

    testWidgets('${mode.name}: repeated EOF turns do not trap previous',
        (tester) async {
      final file = await tester.runAsync(() => writeFixture('epub', [
            '中文与 emoji 🌿 remain together. ' * 1200,
          ]));
      final engine = await mountFixture(tester, 'epub', mode,
          path: file!.path, initialIndex: 0);
      expect(engine.getProgress(), 0);
      var steps = 0;
      while (steps++ < 200) {
        final before = engine.getCurrentPosition()!;
        final previousProgress = engine.getProgress()!;
        await perform(tester, engine.nextPage);
        if (!advanced(before, engine.getCurrentPosition()!)) break;
        expect(engine.getProgress(), greaterThan(previousProgress));
      }
      expect(steps, greaterThan(20));
      expect(steps, lessThan(200));
      final end = engine.getCurrentPosition()!;
      expect(end.paragraphTrailingEdge, closeTo(1, .004));
      expect(engine.getProgress(), 1);
      for (var i = 0; i < 3; i++) {
        await perform(tester, engine.nextPage);
        expectSameViewport(end, engine.getCurrentPosition()!);
      }
      await perform(tester, engine.previousPage);
      expect(engine.getProgress(), lessThan(1));
      expect(engine.getCurrentPosition()!.paragraphLeadingEdge!,
          greaterThan(end.paragraphLeadingEdge!));
    });

    testWidgets(
        '${mode.name}: restore is authoritative before and during layout',
        (tester) async {
      final engine = await mountFixture(tester, 'epub', mode);
      await tester.drag(
          find.byType(ScrollablePositionedList), const Offset(0, -90));
      await tester.pumpAndSettle();
      final saved = engine.getCurrentPosition()!;
      await perform(tester,
          () => engine.goToPosition(const ReadingPosition(paragraphIndex: 70)));
      final restore = engine.goToPosition(saved);
      expectSameViewport(saved, engine.getCurrentPosition()!);
      await tester.pump();
      expectSameViewport(saved, engine.getCurrentPosition()!);
      await tester.pumpAndSettle();
      await restore;
      expectSameViewport(saved, engine.getCurrentPosition()!);
    });

    testWidgets(
        '${mode.name}: chapter and progress navigation replace a pending turn',
        (tester) async {
      final engine = await mountFixture(tester, 'epub', mode, oversized: true);
      final oldTurn = engine.nextPage();
      await tester.pump(const Duration(milliseconds: 50));
      await perform(tester,
          () => engine.goToChapter(const ChapterLocator(contentIndex: 60)));
      await oldTurn;
      final chapter = engine.getCurrentPosition()!;
      expect(chapter.paragraphIndex, 60);
      await tester.pump(const Duration(milliseconds: 500));
      expectSameViewport(chapter, engine.getCurrentPosition()!);
      await perform(tester, () => engine.seekToProgress(.8));
      expect(engine.getCurrentPosition()!.paragraphIndex, 79);
      final before = engine.getCurrentPosition()!;
      await perform(tester, engine.nextPage);
      expect(advanced(before, engine.getCurrentPosition()!), isTrue);
    });

    testWidgets('${mode.name}: pre-attach restore retains the full target',
        (tester) async {
      final first = await mountFixture(tester, 'epub', mode, oversized: true);
      await perform(tester, first.nextPage);
      final saved = ReadingPosition.fromJson(
          'epub', first.getCurrentPosition()!.toJson());
      await tester.pumpWidget(const SizedBox.shrink());
      final second = await mountFixture(tester, 'epub', mode,
          oversized: true, beforeAttachPosition: saved);
      expectSameViewport(saved, second.getCurrentPosition()!);
    });

    testWidgets('${mode.name}: manual scroll discards turn history',
        (tester) async {
      final engine = await mountFixture(tester, 'epub', mode);
      await perform(tester, engine.nextPage);
      await tester.drag(
          find.byType(ScrollablePositionedList), const Offset(0, -1600));
      await tester.pumpAndSettle();
      final scroll =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      final before = scroll.pixels;
      await perform(tester, engine.previousPage);
      expect(
          before - scroll.pixels, closeTo(.92 * scroll.viewportDimension, 2));
    });

    testWidgets('${mode.name}: competing restores keep only the newest target',
        (tester) async {
      final engine = await mountFixture(tester, 'epub', mode);
      final first =
          engine.goToPosition(const ReadingPosition(paragraphIndex: 30));
      final second = engine.goToPosition(const ReadingPosition(
          paragraphIndex: 70,
          paragraphLeadingEdge: -.1,
          paragraphTrailingEdge: .296875));
      expect(engine.getCurrentPosition()!.paragraphIndex, 70);
      await tester.pumpAndSettle();
      await Future.wait([first, second]);
      expect(engine.getCurrentPosition()!.paragraphIndex, 70);
      expect(engine.getCurrentPosition()!.paragraphLeadingEdge,
          closeTo(-.1, 2 / 640));
    });

    testWidgets('${mode.name}: shortened boundary turn roundtrips exactly',
        (tester) async {
      final engine = await mountFixture(tester, 'epub', mode);
      await perform(tester, () => engine.seekToProgress(1));
      final scroll =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      scroll.jumpTo(scroll.pixels - 100);
      await tester.pumpAndSettle();
      final before = engine.getCurrentPosition()!;
      await perform(tester, engine.nextPage);
      final end = engine.getCurrentPosition()!;
      await perform(tester, engine.nextPage);
      expectSameViewport(end, engine.getCurrentPosition()!);
      await perform(tester, engine.previousPage);
      expectSameViewport(before, engine.getCurrentPosition()!);
    });
  }

  testWidgets('empty EPUB permits navigation without inventing a position',
      (tester) async {
    final file = await tester.runAsync(() => writeFixture('epub', ['']));
    final engine = await mountFixture(tester, 'epub', PageTurnMode.tap,
        path: file!.path, initialIndex: 0);
    await perform(tester, engine.nextPage);
    await perform(tester, engine.previousPage);
    expect(engine.getCurrentPosition(), isNull);
    expect(engine.getProgress(), 0);
  });

  testWidgets('long final paragraph reaches 100% only at scroll end',
      (tester) async {
    final file = await tester.runAsync(() => writeFixture('epub', [
          ...List.filled(100, 'Opening paragraph.'),
          'The final paragraph takes many screens to read. ' * 180,
        ]));
    final engine = await mountFixture(tester, 'epub', PageTurnMode.tap,
        path: file!.path, initialIndex: 0);
    await perform(tester, () => engine.seekToProgress(1));
    expect(engine.getCurrentPosition()!.paragraphIndex, 100);
    expect(engine.getProgress(), closeTo(100 / 101, .00001));
    final scroll =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    scroll.jumpTo(scroll.maxScrollExtent - 1);
    await tester.pumpAndSettle();
    final almostFinished = engine.getProgress()!;
    final position = engine.getCurrentPosition()!;
    final leading = position.paragraphLeadingEdge!;
    final trailing = position.paragraphTrailingEdge!;
    final uncapped = (100 - leading / (trailing - leading)) / 101;
    expect((uncapped * 100).round(), 100);
    expect(almostFinished, greaterThan(100 / 101));
    expect((almostFinished * 100).round(), lessThan(100));

    await perform(tester, engine.nextPage);
    expect(engine.getProgress(), 1);
    await perform(tester, engine.previousPage);
    expect(engine.getProgress(), closeTo(almostFinished, .0002));
  });

  testWidgets('one-screen EPUB does not start at 100%', (tester) async {
    final file = await tester
        .runAsync(() => writeFixture('epub', ['One short paragraph.']));
    final engine = await mountFixture(tester, 'epub', PageTurnMode.tap,
        path: file!.path, initialIndex: 0);
    expect(engine.getProgress(), 0);
    await perform(tester, engine.nextPage);
    expect(engine.getProgress(), 0);
  });

  test('progress uses the accepted restore target before geometry is mounted',
      () async {
    final file = await writeFixture('epub', baselineParagraphs());
    final engine = EpubReaderEngine(Book(
      id: 'progress-restore',
      title: 'Fixture',
      author: '',
      filePath: file.path,
      format: 'epub',
    ));
    addTearDown(engine.dispose);
    await engine.initialize();
    expect(engine.getProgress(), 0);
    await engine.goToPosition(const ReadingPosition(paragraphIndex: 40));
    expect(engine.getProgress(), .4);
    await engine.goToPosition(const ReadingPosition(
      paragraphIndex: 40,
      paragraphLeadingEdge: -.5,
      paragraphTrailingEdge: 1.5,
    ));
    expect(engine.getProgress(), closeTo(.4025, .00001));
    await engine.goToPosition(const ReadingPosition(
      paragraphIndex: 99,
      paragraphLeadingEdge: .1,
      paragraphTrailingEdge: .1,
    ));
    expect(engine.getProgress(), .99);
  });

  testWidgets(
      'book metadata restores clipped geometry on the first visible frame',
      (tester) async {
    final file = await tester.runAsync(
        () => writeFixture('epub', baselineParagraphs(oversized: true)));
    final first =
        await mountFixture(tester, 'epub', PageTurnMode.tap, path: file!.path);
    await perform(tester, first.nextPage);
    final saved = first.getCurrentPosition()!;
    await tester.pumpWidget(const SizedBox.shrink());
    final engine = EpubReaderEngine(Book(
        id: 'metadata-restore',
        title: 'Fixture',
        author: '',
        filePath: file.path,
        format: 'epub',
        lastPositionType: 'epub',
        lastPositionPayload: saved.toJson()));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      engine.dispose();
    });
    await tester.runAsync(engine.initialize);
    engine.setConfig(baselineConfig(PageTurnMode.tap));
    expectSameViewport(saved, engine.getCurrentPosition()!);
    await pumpReader(tester, engine, PageTurnMode.tap);
    final visible = visibleItems(tester).first;
    expect(visible.index, saved.paragraphIndex);
    expect(
        visible.itemLeadingEdge, closeTo(saved.paragraphLeadingEdge!, 2 / 640));
  });

  testWidgets('restored target is laid out before its first target paint',
      (tester) async {
    final engine =
        await mountFixture(tester, 'epub', PageTurnMode.tap, oversized: true);
    await perform(tester, engine.nextPage);
    final saved = engine.getCurrentPosition()!;
    await perform(tester, () => engine.seekToProgress(.7));
    final restore = engine.goToPosition(saved);
    await tester.pump();
    final visible = visibleItems(tester).first;
    expect(visible.index, saved.paragraphIndex);
    expect(
        visible.itemLeadingEdge, closeTo(saved.paragraphLeadingEdge!, 2 / 640));
    await tester.pumpAndSettle();
    await restore;
  });

  testWidgets(
      'late image layout invalidates motion without trapping navigation',
      (tester) async {
    final file = await tester.runAsync(() async {
      final file = await writeFixture('epub', baselineParagraphs());
      final original = ZipDecoder().decodeBytes(await file.readAsBytes());
      final archive = Archive();
      for (final item in original.files) {
        if (item.name == 'body.xhtml') {
          final text = utf8
              .decode(item.content)
              .replaceFirst('<body>', '<body><img src="image.png"/>');
          final bytes = utf8.encode(text);
          archive.addFile(ArchiveFile(item.name, bytes.length, bytes));
        } else {
          archive.addFile(item);
        }
      }
      final png = img.encodePng(img.Image(width: 1, height: 1));
      archive.addFile(ArchiveFile('image.png', png.length, png));
      await file.writeAsBytes(ZipEncoder().encode(archive));
      return file;
    });
    final engine = EpubReaderEngine(Book(
        id: 'image-fixture',
        title: 'Fixture',
        author: '',
        filePath: file!.path,
        format: 'epub'));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      engine.dispose();
    });
    await tester.runAsync(engine.initialize);
    engine.setConfig(baselineConfig(PageTurnMode.swipe));
    // Image extraction and decoding need real async time, not only the
    // widget test clock used by pumpAndSettle.
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: engine.buildReader)));
    });
    await tester.pump();
    final turn = engine.nextPage();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    await turn;
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
    await perform(tester,
        () => engine.goToPosition(const ReadingPosition(paragraphIndex: 30)));
    final before = engine.getCurrentPosition()!;
    await perform(tester, engine.nextPage);
    await perform(tester, engine.previousPage);
    expectSameViewport(before, engine.getCurrentPosition()!);
  });

  for (final evictBitmap in [false, true]) {
    testWidgets('image remount preserves geometry (evicted: $evictBitmap)',
        (tester) async {
      final file = await tester.runAsync(() async {
        final file = await writeFixture('epub', baselineParagraphs());
        final original = ZipDecoder().decodeBytes(await file.readAsBytes());
        final archive = Archive();
        for (final item in original.files) {
          if (item.name == 'body.xhtml') {
            final text = utf8
                .decode(item.content)
                .replaceFirst('<body>', '<body><img src="image.png"/>');
            final bytes = utf8.encode(text);
            archive.addFile(ArchiveFile(item.name, bytes.length, bytes));
          } else {
            archive.addFile(item);
          }
        }
        final png = img.encodePng(img.Image(width: 120, height: 240));
        archive.addFile(ArchiveFile('image.png', png.length, png));
        await file.writeAsBytes(ZipEncoder().encode(archive));
        return file;
      });
      final engine = EpubReaderEngine(Book(
          id: 'remount',
          title: 'Fixture',
          author: '',
          filePath: file!.path,
          format: 'epub'));
      await tester.runAsync(engine.initialize);
      engine.setConfig(baselineConfig(PageTurnMode.tap));
      tester.view.physicalSize = baselineViewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        engine.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: engine.buildReader)));
      for (var i = 0; i < 30 && find.byType(Image).evaluate().isEmpty; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      final height = tester.getSize(find.byType(Image)).height;
      expect(height, greaterThan(120));
      final start = engine.getCurrentPosition()!;
      await perform(tester,
          () => engine.goToPosition(const ReadingPosition(paragraphIndex: 70)));
      expect(find.byType(Image), findsNothing);
      if (evictBitmap) {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }
      // Inspect the first remounted frame, before a completed Future can cause
      // a second build. A settled-only assertion misses the placeholder flash.
      final restore = engine.goToPosition(start);
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(tester.getSize(find.byType(Image)).height, closeTo(height, .01));
      await tester.pumpAndSettle();
      await restore;
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expectSameViewport(start, engine.getCurrentPosition()!);
      await perform(tester, engine.nextPage);
      await perform(tester, engine.previousPage);
      expectSameViewport(start, engine.getCurrentPosition()!);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('gesture interruption cannot create a stale completed turn',
      (tester) async {
    final engine = await mountFixture(tester, 'epub', PageTurnMode.swipe);
    final turn = engine.nextPage();
    await tester.pump(const Duration(milliseconds: 40));
    await tester.drag(
        find.byType(ScrollablePositionedList), const Offset(0, -300));
    await tester.pumpAndSettle();
    await turn;
    final scroll =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    final before = scroll.pixels;
    await perform(tester, engine.previousPage);
    expect(before - scroll.pixels, closeTo(.92 * scroll.viewportDimension, 2));
  });

  for (final ratio in [.99, 1.0, 1.01, 2.0, 10.0]) {
    testWidgets('paragraph height $ratio viewports advances without skipping',
        (tester) async {
      final engine = await mountFixture(tester, 'epub', PageTurnMode.tap);
      final first = engine.getCurrentPosition()!;
      final height =
          (first.paragraphTrailingEdge! - first.paragraphLeadingEdge!) * 640;
      tester.view.physicalSize = Size(360, height / ratio);
      await tester.pumpAndSettle();
      await perform(tester,
          () => engine.goToPosition(const ReadingPosition(paragraphIndex: 20)));
      final before = engine.getCurrentPosition()!;
      await perform(tester, engine.nextPage);
      final after = engine.getCurrentPosition()!;
      expect(advanced(before, after), isTrue);
      if (ratio > 1) {
        expect(after.paragraphIndex, before.paragraphIndex);
        expect(before.paragraphLeadingEdge! - after.paragraphLeadingEdge!,
            lessThanOrEqualTo(1.01));
      }
    });
  }

  testWidgets('invalid geometry and out-of-range indices recover safely',
      (tester) async {
    final engine = await mountFixture(tester, 'epub', PageTurnMode.tap);
    for (final edges in [
      (double.nan, 1.0),
      (-double.infinity, 1.0),
      (-1e308, 1e308),
      (-1e308, 1.0),
      (-.2, -.3),
      (2.0, 3.0)
    ]) {
      await perform(
          tester,
          () => engine.goToPosition(ReadingPosition(
              paragraphIndex: 20,
              paragraphLeadingEdge: edges.$1,
              paragraphTrailingEdge: edges.$2)));
      expect(engine.getCurrentPosition()!.paragraphIndex, 20);
      expect(
          engine.getCurrentPosition()!.paragraphLeadingEdge, closeTo(0, .004));
    }
    await perform(tester,
        () => engine.goToPosition(const ReadingPosition(paragraphIndex: -100)));
    expect(engine.getCurrentPosition()!.paragraphIndex, 0);
    await perform(
        tester,
        () => engine
            .goToPosition(const ReadingPosition(paragraphIndex: 1000000)));
    expect(
        engine.getCurrentPosition()!.paragraphIndex!, inInclusiveRange(97, 99));
  });

  for (final text in ['Short book.', '\r\n\r\n中文🌿\r\n\r\n']) {
    testWidgets(
        'short and empty inputs have stable boundaries (${text.length})',
        (tester) async {
      final file = await tester.runAsync(() => writeFixture('epub', [text]));
      final engine = EpubReaderEngine(Book(
          id: 'remount',
          title: 'Fixture',
          author: '',
          filePath: file!.path,
          format: 'epub'));
      await tester.runAsync(engine.initialize);
      engine.setConfig(baselineConfig(PageTurnMode.tap));
      tester.view.physicalSize = baselineViewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        engine.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: engine.buildReader)));
      final before = engine.getCurrentPosition()!;
      await perform(tester, engine.nextPage);
      await perform(tester, engine.previousPage);
      expectSameViewport(before, engine.getCurrentPosition()!);
    });
  }

  testWidgets('layout changes and disposal cancel outstanding motion',
      (tester) async {
    final engine =
        await mountFixture(tester, 'epub', PageTurnMode.swipe, oversized: true);
    final turn = engine.nextPage();
    await tester.pump(const Duration(milliseconds: 60));
    engine.setConfig(baselineConfig(PageTurnMode.swipe, fontSize: 24));
    tester.view.physicalSize = const Size(640, 360);
    await tester.pumpAndSettle();
    await turn;
    final stable = engine.getCurrentPosition()!.toJson();
    await tester.pump(const Duration(milliseconds: 600));
    expect(engine.getCurrentPosition()!.toJson(), stable);
    final pending = engine.nextPage();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pending;
    expect(tester.takeException(), isNull);
  });
}
