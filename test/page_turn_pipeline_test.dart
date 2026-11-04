import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/modules/reader/reader_engine/page_turn_request.dart';
import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';

Future<ui.Image> snapshot() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.red, BlendMode.src);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(100, 200);
  } finally {
    picture.dispose();
  }
}

Future<GlobalKey<SmoothPageReaderState>> mount(WidgetTester tester,
    {required Future<ui.Image?> Function() capture,
    Object? layout = 1,
    bool snapshotIncoming = false,
    GlobalKey<SmoothPageReaderState>? key}) async {
  final actual = key ?? GlobalKey<SmoothPageReaderState>();
  await tester.pumpWidget(MaterialApp(
      home: SizedBox(
    width: 100,
    height: 200,
    child: SmoothPageReader(
        key: actual,
        layoutIdentity: layout,
        snapshotIncoming: snapshotIncoming,
        captureFrame: capture,
        captureTimeout: const Duration(milliseconds: 50),
        prepareTimeout: const Duration(milliseconds: 150),
        onPreviousTap: () {},
        onNextTap: () {},
        onCenterTap: () {},
        child: const ColoredBox(color: Colors.blue)),
  )));
  return actual;
}

Offset liveOffset(WidgetTester tester) {
  final translation = tester
      .widget<Transform>(find.byKey(const ValueKey('live-reader')))
      .transform
      .getTranslation();
  return Offset(translation.x, translation.y);
}

void main() {
  for (final cancel in [false, true]) {
    testWidgets(
        'ready frame captures fresh pixels and ${cancel ? 'cancels' : 'slides'}',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final key = GlobalKey<SmoothPageReaderState>();
      final screenKey = GlobalKey();
      final bodyKey = GlobalKey();
      final color = ValueNotifier(Colors.red);
      final ready = Completer<bool>();
      final request = PageTurnRequest();
      Map<String, num>? measured;
      await tester.pumpWidget(MaterialApp(
        home: RepaintBoundary(
          key: screenKey,
          child: SmoothPageReader(
            key: key,
            prepareTimeout: const Duration(seconds: 2),
            onTurnMeasured: (value) => measured = value,
            onPreviousTap: () {},
            onNextTap: () {},
            onCenterTap: () {},
            child: RepaintBoundary(
              key: bodyKey,
              child: ValueListenableBuilder<Color>(
                valueListenable: color,
                builder: (context, value, child) => ColoredBox(color: value),
              ),
            ),
          ),
        ),
      ));
      final body = bodyKey.currentContext;
      final initialOffset = tester.getTopLeft(find.byKey(bodyKey));
      var dispatched = false;
      final turn = key.currentState!.playTurn(
        forward: true,
        request: request,
        dispatchTurn: () async {
          color.value = Colors.blue;
          dispatched = true;
        },
        waitForReady: () => ready.future,
      );
      // Real toImage completes outside the fake widget-test clock.
      Future<void> tick() async {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
      }

      for (var i = 0; i < 30 && !dispatched; i++) {
        await tick();
      }
      expect(dispatched, isTrue);
      await tick();
      expect(bodyKey.currentContext, same(body));
      expect(tester.getTopLeft(find.byKey(bodyKey)), initialOffset);

      Future<List<int>> pixel(ui.Image image) async {
        final bytes = await image.toByteData();
        return bytes!.buffer.asUint8List(bytes.offsetInBytes, 4).toList();
      }

      Future<List<int>> capturePixel(GlobalKey target) async {
        final boundary =
            target.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        try {
          return await pixel(image);
        } finally {
          image.dispose();
        }
      }

      List<int> rgba(Color value) => [
            (value.r * 255).round(),
            (value.g * 255).round(),
            (value.b * 255).round(),
            (value.a * 255).round(),
          ];
      final oldPixel = rgba(Colors.red);
      final newPixel = rgba(Colors.blue);
      expect(await tester.runAsync(() => capturePixel(screenKey)), oldPixel);
      expect(await tester.runAsync(() => capturePixel(bodyKey)), newPixel);
      final finalPixel = cancel ? newPixel : rgba(Colors.green);
      if (cancel) {
        request.cancel();
      } else {
        // Readiness may publish a final visual update in the same turn.
        color.value = Colors.green;
        ready.complete(true);
        for (var i = 0;
            i < 30 && find.byType(RawImage).evaluate().length < 2;
            i++) {
          await tick();
        }
        final images =
            tester.widgetList<RawImage>(find.byType(RawImage)).toList();
        expect(images, hasLength(2), reason: 'Turn metrics: $measured');
        expect(
            await tester.runAsync(() => pixel(images.first.image!)), finalPixel);
      }
      await tester.pumpAndSettle();
      await turn;
      if (cancel) ready.complete(true);
      expect(bodyKey.currentContext, same(body));
      expect(tester.getTopLeft(find.byKey(bodyKey)), initialOffset);
      expect(await tester.runAsync(() => capturePixel(screenKey)), finalPixel);
      await tester.pumpWidget(const SizedBox.shrink());
      color.dispose();
    });
  }
  testWidgets(
      'cancelling the incoming capture frees both images without another turn',
      (tester) async {
    final outgoing = await tester.runAsync(snapshot);
    final incoming = Completer<ui.Image?>();
    var captures = 0;
    var calls = 0;
    final request = PageTurnRequest();
    final key = await mount(tester,
        snapshotIncoming: true,
        capture: () =>
            captures++ == 0 ? Future.value(outgoing) : incoming.future);
    final turn = key.currentState!.playTurn(
        forward: true,
        request: request,
        dispatchTurn: () async {
          calls++;
        });
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump();
    }
    expect(captures, 2);
    expect(calls, 1);
    request.cancel();
    await tester.pump();
    await turn;
    expect(outgoing!.debugDisposed, isTrue);
    final late = await tester.runAsync(snapshot);
    incoming.complete(late);
    await tester.pump();
    expect(late!.debugDisposed, isTrue);
    expect(calls, 1);
    expect(key.currentState!.isAnimating, isFalse);
  });
  testWidgets('both page images release after a text slide without remounting',
      (tester) async {
    final outgoing = await tester.runAsync(snapshot);
    final incoming = await tester.runAsync(snapshot);
    var captures = 0;
    final key = await mount(tester,
        snapshotIncoming: true,
        capture: () async => captures++ == 0 ? outgoing : incoming);
    final body = tester.element(find.byType(ColoredBox).last);
    final turn =
        key.currentState!.playTurn(forward: true, dispatchTurn: () async {});
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(captures, 2);
    expect(find.byType(RawImage), findsNWidgets(2));
    expect(tester.element(find.byType(ColoredBox).last), same(body));
    expect(tester.widget<Opacity>(find.byType(Opacity).last).opacity, 0);
    await tester.pumpAndSettle();
    await turn;
    expect(outgoing!.debugDisposed, isTrue);
    expect(incoming!.debugDisposed, isTrue);
    expect(find.byType(RawImage), findsNothing);
    expect(tester.element(find.byType(ColoredBox).last), same(body));
  });
  testWidgets('old page covers navigation until target is ready',
      (tester) async {
    final image = await tester.runAsync(snapshot);
    final key = await mount(tester, capture: () async => image);
    final ready = Completer<bool>();
    var calls = 0;
    final turn = key.currentState!.playTurn(
        forward: true,
        dispatchTurn: () async {
          calls++;
        },
        waitForReady: () => ready.future);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(calls, 1);
    expect(liveOffset(tester), Offset.zero);
    final raw = find.byType(RawImage);
    expect(raw, findsOneWidget);
    final stack = tester.widget<Stack>(
        find.ancestor(of: raw, matching: find.byType(Stack)).first);
    expect(stack.children.last, isA<Transform>());
    await tester.pump(const Duration(milliseconds: 60));
    expect(liveOffset(tester), Offset.zero);
    ready.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump(const Duration(milliseconds: 16));
    expect(liveOffset(tester).dx, greaterThan(0));
    expect(calls, 1);
    await tester.pumpAndSettle();
    await turn;
    expect(find.byType(RawImage), findsNothing);
    expect(liveOffset(tester), Offset.zero);
    expect(image!.debugDisposed, isTrue);
  });

  testWidgets('timed-out capture is single-flight and late image is released',
      (tester) async {
    final late = Completer<ui.Image?>();
    var captures = 0;
    var calls = 0;
    final key = await mount(tester, capture: () {
      captures++;
      return late.future;
    });
    Future<void> turn() => key.currentState!.playTurn(
        forward: true,
        dispatchTurn: () async {
          calls++;
        });
    final first = turn();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
    await first;
    expect(calls, 1);
    final second = turn();
    await tester.pumpAndSettle();
    await second;
    expect(calls, 2);
    expect(captures, 1);
    final image = await tester.runAsync(snapshot);
    late.complete(image);
    await tester.pump();
    expect(image!.debugDisposed, isTrue);
    expect(calls, 2);
  });

  testWidgets('capture cancellation cannot dispatch late navigation',
      (tester) async {
    final capture = Completer<ui.Image?>();
    final key = await mount(tester, capture: () => capture.future);
    final request = PageTurnRequest();
    var calls = 0;
    final turn = key.currentState!.playTurn(
        forward: true,
        request: request,
        dispatchTurn: () async {
          calls++;
        });
    request.cancel();
    await tester.pump();
    await turn;
    final image = await tester.runAsync(snapshot);
    capture.complete(image);
    await tester.pump();
    expect(calls, 0);
    expect(image!.debugDisposed, isTrue);
    expect(key.currentState!.isAnimating, isFalse);
  });

  for (final changeLayout in [false, true]) {
    testWidgets(
        'pending target ${changeLayout ? 'layout cancellation' : 'timeout'} reveals committed page',
        (tester) async {
      final image = await tester.runAsync(snapshot);
      final key = await mount(tester, capture: () async => image);
      final ready = Completer<bool>();
      var calls = 0;
      final turn = key.currentState!.playTurn(
          forward: true,
          dispatchTurn: () async {
            calls++;
          },
          waitForReady: () => ready.future);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(calls, 1);
      if (changeLayout) {
        await mount(tester, key: key, layout: 2, capture: () async => null);
      } else {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pumpAndSettle();
      await turn;
      ready.complete(true);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(RawImage), findsNothing);
      expect(liveOffset(tester), Offset.zero);
      expect(image!.debugDisposed, isTrue);
    });
  }

  testWidgets('no-op navigation does not slide a duplicate page',
      (tester) async {
    final image = await tester.runAsync(snapshot);
    final key = await mount(tester, capture: () async => image);
    var checks = 0;
    final turn = key.currentState!.playTurn(
        forward: true,
        dispatchTurn: () async {},
        didMove: () => false,
        waitForReady: () async {
          checks++;
          return true;
        });
    await tester.pumpAndSettle();
    await turn;
    expect(checks, 0);
    expect(liveOffset(tester), Offset.zero);
    expect(image!.debugDisposed, isTrue);
  });
}
