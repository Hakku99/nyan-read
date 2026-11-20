import 'dart:async';
import 'package:flutter/widgets.dart';

import 'page_turn_request.dart';

/// Reuses the image provider's cache key; no second page rasterization is needed.
Future<bool> waitForImageFrame(
    ImageProvider provider, PageTurnRequest request) async {
  request.checkActive();
  final ready = Completer<bool>();
  final stream = provider.resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener((info, synchronous) {
    info.dispose();
    if (!ready.isCompleted) ready.complete(true);
  }, onError: (Object error, StackTrace? stack) {
    // The reader's normal image loader/error state is revealed on failure.
    debugPrint('Page image unavailable (${error.runtimeType}).');
    if (!ready.isCompleted) ready.complete(false);
  });
  stream.addListener(listener);
  try {
    return await request.wait(ready.future);
  } finally {
    stream.removeListener(listener);
  }
}
