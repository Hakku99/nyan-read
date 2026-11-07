import 'dart:convert';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/reader/reader_engine/epub/epub_reader.dart';
import 'package:nyan_read/modules/reader/reader_engine/page_turn_request.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';

import '../tool/reader_baseline/baseline_support.dart';

void main() {
  for (final withImage in [false, true]) {
    testWidgets(
        'EPUB reuses the painted ${withImage ? 'illustrated' : 'text'} frame',
        (tester) async {
      const target = 3;
      final file = (await tester.runAsync(() async {
        final paragraphs = baselineParagraphs();
        paragraphs[target] = 'Target paragraph with visibly different text.';
        final file = await writeFixture('epub', paragraphs);
        if (withImage) {
          final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
          final body = archive.findFile('body.xhtml')!;
          final source = utf8.decode(body.content).replaceFirst(
              '${paragraphs[target]}</p>',
              '${paragraphs[target]}</p><img src="target.png"/>');
          final bytes = utf8.encode(source);
          archive.addFile(ArchiveFile(body.name, bytes.length, bytes));
          final image = img.Image(width: 120, height: 96)
            ..clear(img.ColorRgb8(240, 20, 180));
          final png = img.encodePng(image);
          archive.addFile(ArchiveFile('target.png', png.length, png));
          await file.writeAsBytes(ZipEncoder().encode(archive));
        }
        return file;
      }))!;
      final engine = EpubReaderEngine(Book(
          id: 'painted-frame',
          title: 'Fixture',
          author: '',
          filePath: file.path,
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

      final reader = GlobalKey<SmoothPageReaderState>();
      final body = GlobalKey();
      final request = PageTurnRequest();
      var frame = 0;
      int? readyFrame;
      int? capturedFrame;
      Object? captureFailure;
      ui.Image? outgoing;
      ui.Image? incoming;
      Future<ui.Image> captureBody() =>
          (body.currentContext!.findRenderObject()! as RenderRepaintBoundary)
              .toImage();
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
            body: Builder(
                builder: (context) => SmoothPageReader(
                      key: reader,
                      prepareTimeout: const Duration(seconds: 2),
                      captureTimeout: const Duration(seconds: 2),
                      captureFrame: () async {
                        if (readyFrame != null) capturedFrame = frame;
                        final ui.Image image;
                        try {
                          image = await captureBody();
                        } catch (error) {
                          captureFailure = error;
                          rethrow;
                        }
                        if (capturedFrame == null) {
                          outgoing = image.clone();
                        } else {
                          incoming = image.clone();
                        }
                        return image;
                      },
                      onPreviousTap: () {},
                      onNextTap: () {},
                      onCenterTap: () {},
                      child: RepaintBoundary(
                          key: body, child: engine.buildReader(context)),
                    ))),
      ));
      addTearDown(() {
        outgoing?.dispose();
        incoming?.dispose();
      });
      Future<void> tick() async {
        frame++;
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
      }

      for (var i = 0; i < 100 && tester.binding.hasScheduledFrame; i++) {
        await tick();
      }
      expect(tester.binding.hasScheduledFrame, isFalse);
      if (withImage) {
        // Visit the illustration once so this case measures a stable image
        // slot. The pending-image path is exercised separately.
        await perform(
            tester,
            () => engine
                .goToPosition(const ReadingPosition(paragraphIndex: target)));
        for (var i = 0; i < 100 && find.byType(Image).evaluate().isEmpty; i++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(find.byType(Image), findsOneWidget);
        await tester.pumpAndSettle();
        await perform(
            tester,
            () =>
                engine.goToPosition(const ReadingPosition(paragraphIndex: 0)));
      }
      final before = engine.getCurrentPosition()!;
      final turn = reader.currentState!.playTurn(
        forward: true,
        request: request,
        dispatchTurn: engine.nextPage,
        waitForReady: () async {
          final ready = await engine.waitForPagePresentation(request);
          if (ready) readyFrame = frame;
          return ready;
        },
        readyIncludesPaint: true,
      );
      for (var i = 0; i < 100 && incoming == null; i++) {
        await tick();
      }
      expect(incoming, isNotNull,
          reason:
              'Ready frame $readyFrame, captured $capturedFrame: $captureFailure');
      expect(capturedFrame, readyFrame);
      await tester.pumpAndSettle();
      await turn;
      expect(advanced(before, engine.getCurrentPosition()!), isTrue);
      final visible = visibleItems(tester).map((item) => item.index).toList();

      await tester.runAsync(() async {
        final finalBody = await captureBody();
        try {
          final finalBytes = (await finalBody.toByteData())!;
          final pixels = (await incoming!.toByteData())!.buffer.asUint8List();
          expect(pixels, finalBytes.buffer.asUint8List());
          expect(pixels,
              isNot((await outgoing!.toByteData())!.buffer.asUint8List()));
          if (withImage) {
            // A solid fixture color distinguishes the decoded image from its loader.
            var paintedImage = false;
            for (var i = 0; i < pixels.length; i += 4) {
              if (pixels[i] == 240 &&
                  pixels[i + 1] == 20 &&
                  pixels[i + 2] == 180) {
                paintedImage = true;
                break;
              }
            }
            expect(paintedImage, isTrue, reason: 'Visible slots: $visible');
          }
        } finally {
          finalBody.dispose();
        }
      });
    });
  }
}
