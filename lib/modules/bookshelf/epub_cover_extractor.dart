import 'dart:isolate';

import 'package:epubx/epubx.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Thumbnail cap keeps isolate work and [Image.memory] decode bounded for a
/// small hero tile (64×84 logical); larger assets still look sharp at 3x.
const int _kCoverMaxSide = 360;

/// Opens [epubBytes] in a worker isolate, reads the OPF cover reference, and
/// returns lossy-compressed JPEG bytes for display, or `null` if missing or
/// on any parse error.
Future<Uint8List?> extractEpubCoverAsJpeg(Uint8List epubBytes) {
  return Isolate.run(() => _extractEpubCoverJpegInIsolate(epubBytes));
}

Future<Uint8List?> _extractEpubCoverJpegInIsolate(Uint8List epubBytes) async {
  try {
    final ref = await EpubReader.openBook(epubBytes);
    var cover = await ref.readCover();
    if (cover == null) return null;

    if (cover.width > _kCoverMaxSide || cover.height > _kCoverMaxSide) {
      if (cover.width >= cover.height) {
        cover = img.copyResize(cover, width: _kCoverMaxSide);
      } else {
        cover = img.copyResize(cover, height: _kCoverMaxSide);
      }
    }

    return Uint8List.fromList(img.encodeJpg(cover, quality: 88));
  } catch (e) {
    debugPrint('Epub cover extract: $e');
    return null;
  }
}
