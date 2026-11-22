import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/modules/reader/reader_engine/page_presentation.dart';
import 'package:nyan_read/modules/reader/reader_engine/page_turn_request.dart';

class _Completer extends ImageStreamCompleter {
  void publish(ImageInfo info) => setImage(info);
}

class _Provider extends ImageProvider<_Provider> {
  final _Completer completer = _Completer();

  @override
  Future<_Provider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_Provider key, ImageDecoderCallback decode) =>
      completer;
}

void main() {
  testWidgets('presentation waits for a frame and releases its listener',
      (tester) async {
    final provider = _Provider();
    final request = PageTurnRequest();
    var completed = false;
    final ready = waitForImageFrame(provider, request).then((value) {
      completed = true;
      return value;
    });
    await tester.pump();
    expect(completed, isFalse);
    final image = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(const Color(0xfff6f3ea), BlendMode.src);
      final picture = recorder.endRecording();
      try {
        return await picture.toImage(2, 2);
      } finally {
        picture.dispose();
      }
    });
    provider.completer.publish(ImageInfo(image: image!));
    await tester.pump();
    expect(await ready, isTrue);
    PaintingBinding.instance.imageCache.clear();
    expect(provider.completer.hasListeners, isFalse);
  });

  testWidgets('cancelled presentation removes its own pending listener',
      (tester) async {
    final provider = _Provider();
    final request = PageTurnRequest();
    final ready = waitForImageFrame(provider, request);
    // The shared image cache owns another listener until clear; cancellation
    // must release this wait without evicting a reader's in-flight decode.
    final rejected = expectLater(ready, throwsA(isA<PageTurnCancelled>()));
    await tester.pump();
    request.cancel();
    await tester.pump();
    await rejected;
    PaintingBinding.instance.imageCache.clear();
    expect(provider.completer.hasListeners, isFalse);
  });
}
