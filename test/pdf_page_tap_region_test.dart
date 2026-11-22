import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';
import 'package:pdfx/pdfx.dart';

void main() {
  late PhotoViewController photo;
  late PageController pages;
  late List<String> taps;

  Future<void> mount(WidgetTester tester,
      {bool enabled = true,
      bool pdfTapZones = true,
      Size viewport = const Size(400, 300),
      ValueChanged<int>? onPageChanged,
      GestureDragEndCallback? onPanEnd}) async {
    final photoController = photo = PhotoViewController();
    final pageController = pages = PageController();
    taps = [];
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      photoController.dispose();
      pageController.dispose();
    });
    await tester.pumpWidget(MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: viewport.width,
          height: viewport.height,
          child: GestureDetector(
            onPanEnd: onPanEnd,
            child: SmoothPageReader(
              enabled: enabled,
              pdfTapZones: pdfTapZones,
              onPreviousTap: () => taps.add('previous'),
              onNextTap: () => taps.add('next'),
              onCenterTap: () => taps.add('center'),
              child: PhotoViewGallery(
                pageController: pages,
                onPageChanged: onPageChanged,
                scrollDirection: Axis.vertical,
                pageOptions: [
                  for (var i = 0; i < 3; i++)
                    PhotoViewGalleryPageOptions.customChild(
                      controller: i == 0 ? photo : null,
                      childSize: const Size(800, 900),
                      initialScale: PhotoViewComputedScale.contained,
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.contained * 3.0,
                      child: const SizedBox.expand(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final left in [true, false]) {
    final edge = Offset(left ? 79 : 321, 140);
    final boundary = Offset(left ? 80 : 320, 140);
    final turn = left ? 'previous' : 'next';
    for (final centerFirst in [true, false]) {
      testWidgets('boundary pair left=$left centerFirst=$centerFirst',
          (tester) async {
        await mount(tester);
        final initial = photo.scale;
        await tester.tapAt(centerFirst ? boundary : edge);
        expect(taps, centerFirst ? isEmpty : equals([turn]));
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tapAt(centerFirst ? edge : boundary);
        expect(taps, [turn]);
        await tester.pump(kDoubleTapTimeout);
        await tester.pumpAndSettle();
        expect(taps, [turn]);
        expect(photo.scale, initial);
      });
    }
  }

  testWidgets('center single opens controls and center double zooms',
      (tester) async {
    await mount(tester);
    const center = Offset(200, 140);
    await tester.tapAt(center);
    await tester.pump(kDoubleTapTimeout);
    expect(taps, ['center']);
    final initial = photo.scale!;
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(photo.scale, greaterThan(initial));
    expect(taps, ['center']);
  });

  testWidgets('cross-zone pinch zooms and an edge drag pans the zoomed page',
      (tester) async {
    await mount(tester);
    final initial = photo.scale!;
    final edge = await tester.startGesture(const Offset(65, 140));
    await edge.moveBy(const Offset(0, -4));
    final center = await tester.startGesture(const Offset(220, 140));
    await edge.moveBy(const Offset(-20, 0));
    await center.moveBy(const Offset(60, 0));
    await tester.pump();
    await center.moveBy(const Offset(45, 0));
    expect(pages.position.pixels, 0);
    await edge.up();
    await center.up();
    await tester.pumpAndSettle();
    expect(photo.scale, greaterThan(initial));
    final before = photo.position;
    final drag = await tester.startGesture(const Offset(65, 140));
    await drag.moveBy(const Offset(0, 40));
    await drag.moveBy(const Offset(0, 5));
    expect(photo.position, isNot(before));
    expect(pages.position.pixels, 0);
    await drag.up();
    await tester.pumpAndSettle();
    expect(photo.position, isNot(before));
    expect(pages.page, 0);
    expect(taps, isEmpty);
  });

  for (final edgeFirst in [true, false]) {
    testWidgets('stationary overlapping touches edgeFirst=$edgeFirst',
        (tester) async {
      await mount(tester);
      const edge = Offset(60, 140);
      const center = Offset(200, 140);
      final scale = photo.scale;
      final first = await tester.startGesture(edgeFirst ? edge : center);
      final second = await tester.startGesture(edgeFirst ? center : edge);
      await second.up();
      await first.up();
      await tester.pump(kDoubleTapTimeout);
      expect(taps, isEmpty);
      expect(photo.scale, scale);
      await tester.tapAt(edge);
      expect(taps, ['previous']);
    });
  }

  for (final tapMode in [true, false]) {
    testWidgets('HONOR 12-step swipe scrolls before release, tapMode=$tapMode',
        (tester) async {
      // The 13B-4 reading area, excluding the system bars.
      const viewport = Size(1256 / 3.5, 2536 / 3.5);
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final changes = <int>[];
      var readerSwipes = 0;
      await mount(tester,
          enabled: tapMode,
          viewport: viewport,
          onPageChanged: changes.add,
          onPanEnd: (_) => readerSwipes++);
      expect(pages.position.viewportDimension, closeTo(viewport.height, 1e-9));
      final startPixels = pages.position.pixels;
      final fit = photo.scale;
      final x = viewport.width * 0.85;
      final finger =
          await tester.startGesture(Offset(x, viewport.height * 0.8));
      const interval = Duration(milliseconds: 18);
      for (var step = 1; step <= 12; step++) {
        await tester.pump(interval);
        await finger.moveTo(
          Offset(x, viewport.height * (0.8 - 0.6 * step / 12)),
          timeStamp: interval * step,
        );
      }
      expect(pages.position.pixels, greaterThan(startPixels));
      expect(photo.scale, fit);
      expect(photo.position, Offset.zero);
      const hold = Duration(milliseconds: 60);
      await tester.pump(hold);
      await finger.up(timeStamp: interval * 12 + hold);
      await tester.pumpAndSettle();
      expect(pages.page, 1);
      expect(changes, [1]);
      expect(readerSwipes, 0);
      expect(taps, isEmpty);
    });
  }

  testWidgets('a second finger cannot take over an active gallery drag',
      (tester) async {
    await mount(tester);
    final fit = photo.scale;
    final first = await tester.startGesture(const Offset(340, 260));
    await first.moveBy(const Offset(0, -45));
    await first.moveBy(const Offset(0, -45));
    await tester.pump();
    final beforeSecond = pages.position.pixels;
    expect(beforeSecond, greaterThan(0));
    final second = await tester.startGesture(const Offset(180, 100));
    await second.moveBy(const Offset(-60, 0));
    await second.up();
    await first.moveBy(const Offset(0, -135));
    expect(pages.position.pixels, greaterThan(beforeSecond));
    expect(photo.scale, fit);
    await first.up();
    await tester.pumpAndSettle();
    expect(pages.page, 1);
    expect(taps, isEmpty);
  });

  testWidgets('cancel and gallery swipe leave no pending edge turn',
      (tester) async {
    await mount(tester);
    const edge = Offset(360, 200);
    final canceled = await tester.startGesture(edge);
    await canceled.moveBy(const Offset(0, -4));
    await canceled.cancel();
    await tester.pump(kDoubleTapTimeout);
    expect(pages.position.pixels, 0);
    expect(taps, isEmpty);
    await tester.dragFrom(edge, const Offset(0, -235));
    await tester.pumpAndSettle();
    await tester.pump(kDoubleTapTimeout);
    expect(pages.page, 1);
    expect(taps, isEmpty);
    await tester.tapAt(edge);
    expect(taps, ['next']);
  });

  testWidgets('cancel during a partial gallery drag clears the gesture',
      (tester) async {
    await mount(tester);
    const edge = Offset(360, 200);
    final fit = photo.scale;
    final finger = await tester.startGesture(edge);
    await finger.moveBy(const Offset(0, -40));
    await finger.moveBy(const Offset(0, -30));
    expect(pages.position.pixels, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 100));
    await finger.cancel();
    await tester.pumpAndSettle();
    expect(pages.page, 0);
    expect(photo.scale, fit);
    expect(taps, isEmpty);
    await tester.tapAt(edge);
    expect(taps, ['next']);
  });

  testWidgets('horizontal edge swipe keeps the existing gallery/reader owner',
      (tester) async {
    Future<(int, double?, Offset)> swipe(bool partition) async {
      await tester.pumpWidget(const SizedBox.shrink());
      var swipes = 0;
      await mount(tester, pdfTapZones: partition, onPanEnd: (_) => swipes++);
      await tester.dragFrom(const Offset(360, 140), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(taps, isEmpty);
      return (swipes, pages.page, photo.position);
    }

    final original = await swipe(false);
    expect(await swipe(true), original);
  });

  testWidgets('outside tap mode the edge keeps native double-tap zoom',
      (tester) async {
    await mount(tester, enabled: false);
    final initial = photo.scale!;
    const edge = Offset(360, 140);
    await tester.tapAt(edge);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(edge);
    await tester.pumpAndSettle();
    expect(photo.scale, greaterThan(initial));
    expect(taps, isEmpty);
  });
}
