import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
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

const _groupLength = 21;
const _mib = 1024 * 1024;
final _imageRow = find.byWidgetPredicate((widget) =>
    widget is SizeChangedLayoutNotifier && widget.child?.key is ValueKey<int>);

void main() {
  final binding = _ImageCacheBinding();
  final cache = binding.imageCache as _CountingImageCache;

  for (final keepAlive in [true, false]) {
    testWidgets('first image frame decodes once (cache admits: $keepAlive)',
        (tester) async {
      final bytes = img.encodePng(
          img.Image(width: 32, height: 48)..clear(img.ColorRgb8(210, 30, 90)));
      const decodedBytes = 32 * 48 * 4;
      _observeDecodes(
          cache, bytes, keepAlive ? decodedBytes : decodedBytes - 1);
      final engine = await _mount(
          tester,
          [
            ['cover'],
          ],
          (_) async => bytes);
      await _jump(tester, engine, 0);
      final imageWidget =
          find.descendant(of: _imageRow, matching: find.byType(Image));
      await _pumpUntil(tester, () => imageWidget.evaluate().isNotEmpty);
      expect(tester.getSize(imageWidget), const Size(328, 48));
      expect(_paintedImage, findsOneWidget);
      expect(cache.decodes, hasLength(1));
      final image = tester.widget<RawImage>(_paintedImage).image!;
      expect((image.width, image.height), (32, 48));
      final pixels = await tester.runAsync(image.toByteData);
      expect(pixels!.buffer.asUint8List(pixels.offsetInBytes, 4),
          [210, 30, 90, 255]);

      final request = PageTurnRequest();
      addTearDown(request.cancel);
      bool? ready;
      final presentation =
          engine.waitForPagePresentation(request).then((value) {
        ready = value;
      });
      await _pumpUntil(tester, () => ready != null);
      await presentation;
      expect(ready, isTrue);
      expect(cache.decodes, hasLength(1));
      expect(cache.statusForKey(MemoryImage(bytes)).keepAlive, keepAlive);

      await _jump(tester, engine, _groupLength);
      expect(_imageRow, findsNothing);
      expect(cache.statusForKey(MemoryImage(bytes)).live, isFalse);
      expect(cache.decodes.single.hasListeners, isFalse);
    });
  }

  testWidgets('pending turn readiness shares the uncached probe decode',
      (tester) async {
    final bytes = _png();
    _observeDecodes(cache, bytes, 1);
    final pending = Completer<Uint8List?>();
    final engine = await _mount(
        tester,
        [
          ['cover'],
        ],
        (_) => pending.future);
    await _jump(tester, engine, 0);
    final request = PageTurnRequest();
    addTearDown(request.cancel);
    bool? ready;
    var paintedAtReady = false;
    final presentation = engine.waitForPagePresentation(request).then((value) {
      ready = value;
      paintedAtReady = _paintedImage.evaluate().isNotEmpty;
    });
    await tester.pump();
    expect(ready, isNull);
    pending.complete(bytes);
    await _pumpUntil(tester, () => ready != null);
    await presentation;
    expect(ready, isTrue);
    expect(paintedAtReady, isTrue);
    expect(cache.decodes, hasLength(1));
    await _jump(tester, engine, _groupLength);
    expect(cache.decodes.single.hasListeners, isFalse);
  });

  testWidgets('a deferred Image does not keep the uncached probe alive',
      (tester) async {
    final bytes = _png();
    _observeDecodes(cache, bytes, 1);
    final engine = await _mount(
        tester,
        [
          ['cover'],
        ],
        (_) async => bytes,
        tickersEnabled: false);
    await _jump(tester, engine, 0);
    final imageWidget =
        find.descendant(of: _imageRow, matching: find.byType(Image));
    await _pumpUntil(tester, () => imageWidget.evaluate().isNotEmpty);
    expect(_paintedImage, findsNothing);
    expect(cache.decodes, hasLength(1));
    expect(cache.decodes.single.hasListeners, isFalse);
    expect(cache.statusForKey(MemoryImage(bytes)).untracked, isTrue);
  });

  testWidgets('idle cache retains 32 images and evicts the least recent key',
      (tester) async {
    final sources = List.generate(33, (index) => 'image-$index.png');
    final loads = <String, List<Uint8List>>{};
    final engine =
        await _mount(tester, sources.map((src) => [src]).toList(), (src) async {
      final bytes = _png();
      loads.putIfAbsent(src, () => []).add(bytes);
      return bytes;
    });
    for (var index = 0; index < 32; index++) {
      await _visit(tester, engine, index);
    }
    await _visit(tester, engine, 0);
    expect(loads[sources[0]], hasLength(1));
    await _visit(tester, engine, 32);
    await _jump(tester, engine, sources.length * _groupLength);
    expect(_kept(loads[sources[0]]!.single), isTrue);
    expect(_kept(loads[sources[1]]!.single), isFalse);
    expect(_kept(loads[sources[2]]!.single), isTrue);

    await _visit(tester, engine, 0);
    expect(loads[sources[0]], hasLength(1));
    await _visit(tester, engine, 1);
    expect(loads[sources[1]], hasLength(2));
  });

  testWidgets('16 MiB idle budget evicts by bytes and skips oversized images',
      (tester) async {
    final lengths = {
      'a': 9 * _mib,
      'b': 7 * _mib,
      'c': 0,
      'big': 16 * _mib + 1
    };
    final loads = <String, List<Uint8List>>{};
    final engine = await _mount(
        tester, lengths.keys.map((src) => [src]).toList(), (src) async {
      final bytes = _png(lengths[src]!);
      loads.putIfAbsent(src, () => []).add(bytes);
      return bytes;
    });
    await _visit(tester, engine, 0);
    await _visit(tester, engine, 1);
    await _jump(tester, engine, 4 * _groupLength);
    expect(_kept(loads['a']!.single), isTrue);
    expect(_kept(loads['b']!.single), isTrue);

    await _visit(tester, engine, 2);
    await _jump(tester, engine, 4 * _groupLength);
    expect(_kept(loads['a']!.single), isFalse);
    expect(_kept(loads['b']!.single), isTrue);

    await _visit(tester, engine, 3);
    final large = loads['big']!.single;
    expect(_kept(large), isTrue,
        reason: 'The oversized image is still in use.');
    await _jump(tester, engine, 4 * _groupLength);
    expect(_kept(large), isFalse);
    expect(_kept(loads['b']!.single), isTrue,
        reason: 'An oversized image must not flush eligible idle images.');
  });

  testWidgets('same href shares in-flight work across mounts and close',
      (tester) async {
    final pending = Completer<Uint8List>();
    final bytes = _png();
    var loads = 0;
    final engine = await _mount(tester, [
      ['shared', 'shared'],
      ['shared'],
    ], (_) {
      loads++;
      return pending.future;
    }, closeInTest: true);
    await _jump(tester, engine, 0);
    expect(_imageRow, findsNWidgets(2));
    await _pumpUntil(tester, () => loads > 0);
    expect(loads, 1);
    await _jump(tester, engine, 2 * _groupLength);
    expect(_imageRow, findsNothing);
    await _jump(tester, engine, _groupLength);
    expect(_imageRow, findsOneWidget);
    expect(loads, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    engine.dispose();
    pending.complete(bytes);
    await tester.pump();
    expect(
        PaintingBinding.instance.imageCache
            .statusForKey(MemoryImage(bytes))
            .untracked,
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('evicted image keeps its first frame and cancelled turn anchor',
      (tester) async {
    final reload = Completer<Uint8List?>();
    final failedReload = Completer<Uint8List?>();
    final original = _png(16 * _mib + 1);
    var loads = 0;
    final reader = GlobalKey<SmoothPageReaderState>();
    final engine = await _mount(tester, [
      ['cover'],
    ], (_) async {
      loads++;
      return switch (loads) {
        1 => original,
        2 => await reload.future,
        _ => await failedReload.future,
      };
    }, reader: reader);
    await _visit(tester, engine, 0);
    final initial = engine.getCurrentPosition()!;
    final size = tester.getSize(_imageRow);
    expect(size, const Size(328, 420));
    await _jump(tester, engine, _groupLength);
    expect(_imageRow, findsNothing);
    expect(_kept(original), isFalse);

    final restore = engine.goToPosition(initial);
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(tester.getSize(_imageRow), size);
    await _finish(tester, restore);
    await _pumpUntil(tester, () => loads > 1);
    expect(loads, 2);

    await _jump(tester, engine, 1);
    final before = engine.getCurrentPosition()!;
    final request = PageTurnRequest();
    ReadingPosition? accepted;
    var waiting = false;
    var ready = false;
    final turn = reader.currentState!.playTurn(
      forward: false,
      request: request,
      dispatchTurn: () async {
        await engine.previousPage();
        accepted = engine.getCurrentPosition();
      },
      waitForReady: () async {
        waiting = true;
        ready = await engine.waitForPagePresentation(request);
        return ready;
      },
      readyIncludesPaint: true,
    );
    for (var frame = 0; frame < 12 && !waiting; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump();
    expect(accepted, isNotNull);
    expect(advanced(accepted!, before), isTrue);
    expect(accepted!.paragraphIndex, 0);
    expect(reader.currentState!.isAnimating, isTrue);
    expect(waiting, isTrue);
    expect(ready, isFalse);
    request.cancel();
    await _finish(tester, turn);
    expectSameViewport(accepted!, engine.getCurrentPosition()!);

    reload.complete(_png(16 * _mib + 1));
    await _waitForImage(tester);
    expect(tester.getSize(_imageRow), size);
    expectSameViewport(accepted!, engine.getCurrentPosition()!);
    await perform(tester, engine.nextPage);
    expectSameViewport(before, engine.getCurrentPosition()!);

    await _jump(tester, engine, _groupLength);
    await _jump(tester, engine, 0);
    await _pumpUntil(tester, () => loads > 2);
    expect(loads, 3);
    expect(tester.getSize(_imageRow), size);
    failedReload.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    final l10n = AppLocalizations.of(tester.element(_imageRow))!;
    expect(find.text(l10n.readerImageLoadFailed(l10n.readerImageDefaultAlt)),
        findsOneWidget);
    expect(tester.getSize(_imageRow), size);
    expectSameViewport(initial, engine.getCurrentPosition()!);
  });

  testWidgets('clipped image keeps its row fraction after viewport reflow',
      (tester) async {
    final engine = await _mount(
        tester,
        [
          ['cover'],
        ],
        (_) async => _png(),
        viewport: const Size(640, 360));
    await _visit(tester, engine, 0);
    await perform(tester, () => engine.goToPosition(_clippedImage));
    _expectImageFraction(tester);
    tester.view.physicalSize = baselineViewport;
    await tester.pumpAndSettle();
    expect(engine.getCurrentPosition()!.paragraphIndex, 0);
    _expectImageFraction(tester);
    tester.view.physicalSize = const Size(640, 360);
    await tester.pumpAndSettle();
    _expectImageFraction(tester);
  });

  for (final fails in [false, true]) {
    testWidgets('cold image restore stays inside its row (fails: $fails)',
        (tester) async {
      final pending = Completer<Uint8List?>();
      final engine = await _mount(
          tester,
          [
            ['cover'],
          ],
          (_) => pending.future,
          saved: _clippedImage);
      // Cold restore lays out the target before committing its clipped offset.
      await _pumpUntil(
          tester,
          () => visibleItems(tester)
              .any((item) => item.index == 0 && item.itemLeadingEdge < 0));
      expect(engine.getCurrentPosition()!.paragraphIndex, 0);
      _expectImageFraction(tester);
      pending.complete(fails ? null : _png());
      if (!fails) await _waitForImage(tester);
      await tester.pumpAndSettle();
      expect(engine.getCurrentPosition()!.paragraphIndex, 0);
      _expectImageFraction(tester);
    });
  }

  testWidgets('late cold restore does not override a newer jump',
      (tester) async {
    final pending = Completer<Uint8List?>();
    final bytes = _png();
    var loading = false;
    final engine = await _mount(tester, [
      ['cover'],
    ], (_) {
      loading = true;
      return pending.future;
    }, saved: _clippedImage);
    await _pumpUntil(tester, () => loading);
    await _jump(tester, engine, _groupLength);
    final newer = engine.getCurrentPosition()!;
    pending.complete(bytes);
    await _pumpUntil(tester, () => _kept(bytes));
    await tester.pumpAndSettle();
    expectSameViewport(newer, engine.getCurrentPosition()!);
  });

  testWidgets('clipped image stays the reading anchor at the book boundary',
      (tester) async {
    final engine = await _mount(tester, [<String>[]], (_) async => _png(),
        viewport: const Size(360, 180), closingMarkup: '<img src="last"/>');
    const index = 2 * _groupLength;
    await _jump(tester, engine, index);
    await _waitForImage(tester);
    const saved = ReadingPosition(
      paragraphIndex: index,
      paragraphLeadingEdge: -1,
      paragraphTrailingEdge: 250.8 / 180,
    );
    await perform(tester, () => engine.goToPosition(saved));
    final before = engine.getCurrentPosition()!;
    expect(before.paragraphIndex, index);
    tester.view.physicalSize = baselineViewport;
    await tester.pumpAndSettle();
    expect(visibleItems(tester).map((item) => item.index), contains(index));
    expect(engine.getCurrentPosition()!.paragraphIndex, index);
    tester.view.physicalSize = const Size(360, 180);
    await tester.pumpAndSettle();
    expect(engine.getCurrentPosition()!.paragraphIndex, index);
    expect(engine.getCurrentPosition()!.paragraphLeadingEdge,
        closeTo(before.paragraphLeadingEdge!, 2 / 180));
  });

  for (final end in _ColdTurnEnd.values) {
    testWidgets('cold image shrink rechecks the viewport (${end.name})',
        (tester) async {
      final first = Completer<Uint8List?>();
      final second = Completer<Uint8List?>();
      final reader = GlobalKey<SmoothPageReaderState>();
      var captures = 0;
      var waiting = false;
      var bothImagesAtCapture = false;
      final engine = await _mount(tester, [<String>[]],
          (src) => src == 'first' ? first.future : second.future,
          reader: reader,
          viewport: const Size(360, 180),
          openingMarkup: '<img src="first"/><h2>Heading</h2><p>Text.</p>'
              '<figure><img src="second"/><figcaption>Caption</figcaption></figure>',
          onCapture: () {
        captures++;
        if (captures == 2) {
          bothImagesAtCapture = _paintedImage.evaluate().length == 2;
        }
      });
      final request = PageTurnRequest();
      addTearDown(request.cancel);
      final turn = reader.currentState!.playTurn(
        forward: false,
        request: request,
        dispatchTurn: () =>
            engine.goToPosition(const ReadingPosition(paragraphIndex: 0)),
        waitForReady: () {
          waiting = true;
          return engine.waitForPagePresentation(request);
        },
        readyIncludesPaint: true,
      );
      await _pumpUntil(tester, () => waiting);
      await tester.pump();
      expect(
          visibleItems(tester).map((item) => item.index), isNot(contains(3)));
      first.complete(img.encodePng(img.Image(width: 1, height: 1)));
      await _pumpUntil(
          tester, () => visibleItems(tester).any((item) => item.index == 3));
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(captures, 1, reason: 'The newly visible second image is pending.');
      final accepted = engine.getCurrentPosition()!;
      if (end == _ColdTurnEnd.paint) {
        second.complete(_png());
        await _pumpUntil(tester, () => captures == 2);
        expect(bothImagesAtCapture, isTrue);
        await tester.pumpAndSettle();
        await turn;
      } else {
        if (end == _ColdTurnEnd.cancel) {
          request.cancel();
        } else {
          await tester.pump(const Duration(seconds: 2));
        }
        await _finish(tester, turn);
        expect(captures, 1);
        second.complete(_png());
        await _pumpUntil(tester, () => _paintedImage.evaluate().length == 2);
        await tester.pumpAndSettle();
      }
      expect(accepted.paragraphIndex, 0);
      expectSameViewport(accepted, engine.getCurrentPosition()!);
    });
  }
}

class _ImageCacheBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  ImageCache createImageCache() => _CountingImageCache();
}

class _CountingImageCache extends ImageCache {
  Uint8List? observedBytes;
  final decodes = <ImageStreamCompleter>[];

  @override
  ImageStreamCompleter? putIfAbsent(
      Object key, ImageStreamCompleter Function() loader,
      {ImageErrorListener? onError}) {
    return super.putIfAbsent(key, () {
      final stream = loader();
      if (key is MemoryImage && identical(key.bytes, observedBytes)) {
        decodes.add(stream);
      }
      return stream;
    }, onError: onError);
  }
}

void _observeDecodes(_CountingImageCache cache, Uint8List bytes, int limit) {
  final previousLimit = cache.maximumSizeBytes;
  cache
    ..maximumSizeBytes = limit
    ..observedBytes = bytes;
  addTearDown(() {
    cache
      ..observedBytes = null
      ..decodes.clear()
      ..maximumSizeBytes = previousLimit;
  });
}

enum _ColdTurnEnd { paint, cancel, timeout }

const _clippedImage = ReadingPosition(
  paragraphIndex: 0,
  paragraphLeadingEdge: -300 / 360,
  paragraphTrailingEdge: 130.8 / 360,
);

void _expectImageFraction(WidgetTester tester) {
  final row = visibleItems(tester).first;
  expect(row.index, 0);
  expect(-row.itemLeadingEdge / (row.itemTrailingEdge - row.itemLeadingEdge),
      closeTo(300 / 430.8, .015));
}

bool _kept(Uint8List bytes) => PaintingBinding.instance.imageCache
    .statusForKey(MemoryImage(bytes))
    .keepAlive;

final _encodedPng = img.encodePng(img.Image(width: 500, height: 500));

Uint8List _png([int length = 0]) {
  if (length == 0) return Uint8List.fromList(_encodedPng);
  // Trailing bytes exercise encoded-byte accounting with a small bitmap.
  return Uint8List(length)..setAll(0, _encodedPng);
}

Future<EpubReaderEngine> _mount(
  WidgetTester tester,
  List<List<String>> groups,
  Future<Uint8List?> Function(String) load, {
  GlobalKey<SmoothPageReaderState>? reader,
  bool closeInTest = false,
  Size viewport = baselineViewport,
  ReadingPosition? saved,
  String? openingMarkup,
  String? closingMarkup,
  VoidCallback? onCapture,
  bool tickersEnabled = true,
}) async {
  final file = (await tester.runAsync(() async {
    final fixture = await writeFixture('epub', []);
    final archive = ZipDecoder().decodeBytes(await fixture.readAsBytes());
    final paragraphs = baselineParagraphs().first;
    final body = StringBuffer('<html><body>');
    if (openingMarkup != null) body.write(openingMarkup);
    for (final group in [...groups, <String>[]]) {
      for (final src in group) {
        body.write('<img src="$src"/>');
      }
      for (var i = group.length; i < _groupLength; i++) {
        body.write('<p>$paragraphs</p>');
      }
    }
    if (closingMarkup != null) body.write(closingMarkup);
    body.write('</body></html>');
    final bytes = utf8.encode(body.toString());
    archive.addFile(ArchiveFile('body.xhtml', bytes.length, bytes));
    return fixture.writeAsBytes(ZipEncoder().encode(archive));
  }))!;
  final engine = EpubReaderEngine.withImageLoader(
    Book(
        id: 'epub-image-cache',
        title: 'Fixture',
        author: '',
        filePath: file.path,
        format: 'epub',
        lastPositionType: saved == null ? null : 'epub',
        lastPositionPayload: saved?.toJson()),
    (_, src) => load(src),
  );
  await tester.runAsync(engine.initialize);
  engine.setConfig(baselineConfig(PageTurnMode.tap));
  if (saved == null) {
    await engine.goToPosition(
        ReadingPosition(paragraphIndex: groups.length * _groupLength));
  }
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    if (!closeInTest) engine.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Builder(builder: (context) {
      final body = TickerMode(
          enabled: tickersEnabled, child: engine.buildReader(context));
      if (reader == null) return body;
      return SmoothPageReader(
        key: reader,
        captureFrame: () async {
          onCapture?.call();
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawColor(Colors.red, BlendMode.src);
          final picture = recorder.endRecording();
          try {
            return picture.toImageSync(1, 1);
          } finally {
            picture.dispose();
          }
        },
        onPreviousTap: () {},
        onNextTap: () {},
        onCenterTap: () {},
        child: body,
      );
    })),
  ));
  if (saved == null) await tester.pumpAndSettle();
  return engine;
}

Future<void> _jump(WidgetTester tester, EpubReaderEngine engine, int index) =>
    _finish(
        tester, engine.goToPosition(ReadingPosition(paragraphIndex: index)));

Future<void> _finish(WidgetTester tester, Future<void> action) async {
  var complete = false;
  final observed = action.whenComplete(() => complete = true);
  for (var frame = 0; frame < 24 && !complete; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(complete, isTrue);
  await observed;
}

Future<void> _visit(
    WidgetTester tester, EpubReaderEngine engine, int group) async {
  await _jump(tester, engine, group * _groupLength);
  await _waitForImage(tester);
}

final _paintedImage = find.descendant(
  of: _imageRow,
  matching: find.byWidgetPredicate(
      (widget) => widget is RawImage && widget.image != null),
);

Future<void> _waitForImage(WidgetTester tester) async {
  await _pumpUntil(tester, () => _paintedImage.evaluate().isNotEmpty);
  expect(_paintedImage, findsOneWidget);
  await tester.pumpAndSettle();
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  // Source preparation and the image codec can complete outside fake time.
  for (var i = 0; i < 100 && !ready(); i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump();
  }
  expect(ready(), isTrue);
}
