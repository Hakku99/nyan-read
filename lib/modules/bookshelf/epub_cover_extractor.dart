import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../reader/reader_engine/epub/epub_package_parser.dart';

/// Thumbnail cap keeps isolate work and [Image.memory] decode bounded for a
/// small hero tile (64×84 logical); larger assets still look sharp at 3x.
const int _kCoverMaxSide = 360;

/// Opens [epubBytes] in a worker isolate, reads the OPF cover reference, and
/// returns lossy-compressed JPEG bytes for display, or `null` if missing or
/// on any parse error.
///
/// P3c: uses the own package parser (epubx dropped) — only the cover entry
/// is decompressed, never the whole book.
Future<Uint8List?> extractEpubCoverAsJpeg(Uint8List epubBytes) {
  return Isolate.run(() => _extractEpubCoverJpegInIsolate(epubBytes));
}

Uint8List? _extractEpubCoverJpegInIsolate(Uint8List epubBytes) {
  try {
    final package = parseEpubPackage(epubBytes);
    final coverPath = package.coverPath;
    if (coverPath == null) return null;
    final coverBytes = readZipBytes(package.archive, coverPath);
    if (coverBytes == null) return null;

    var cover = img.decodeImage(coverBytes);
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
