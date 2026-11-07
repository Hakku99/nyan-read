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
}) async {
  final file = (await tester.runAsync(() async {
    final fixture = await writeFixture('epub', []);
    final archive = ZipDecoder().decodeBytes(await fixture.readAsBytes());
    final paragraphs = baselineParagraphs().first;
    final body = StringBuffer('<html><body>');
    for (final group in [...groups, <String>[]]) {
      for (final src in group) {
        body.write('<img src="$src"/>');
      }
      for (var i = group.length; i < _groupLength; i++) {
        body.write('<p>$paragraphs</p>');
      }
    }
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
        format: 'epub'),
    (_, src) => load(src),
  );
  await tester.runAsync(engine.initialize);
  engine.setConfig(baselineConfig(PageTurnMode.tap));
  await engine.goToPosition(
      ReadingPosition(paragraphIndex: groups.length * _groupLength));
  tester.view.physicalSize = baselineViewport;
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
      final body = engine.buildReader(context);
      if (reader == null) return body;
      return SmoothPageReader(
        key: reader,
        captureFrame: () async {
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
  await tester.pumpAndSettle();
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

Future<void> _waitForImage(WidgetTester tester) async {
  final painted = find.byWidgetPredicate(
      (widget) => widget is RawImage && widget.image != null);
  await _pumpUntil(tester, () => painted.evaluate().isNotEmpty);
  expect(painted, findsOneWidget);
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
