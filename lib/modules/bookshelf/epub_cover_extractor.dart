import 'dart:isolate';

// archive_io re-exports archive.dart and adds InputFileStream (random-access
// zip reads from disk without loading the whole file).
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../reader/reader_engine/epub/epub_package_parser.dart';

/// Thumbnail cap keeps isolate work and [Image.memory] decode bounded for a
/// small hero tile (64×84 logical); larger assets still look sharp at 3x.
const int _kCoverMaxSide = 360;

/// Opens the EPUB at [path] in a worker isolate, reads the OPF cover
/// reference, and returns lossy-compressed JPEG bytes for display, or `null`
/// if missing or on any parse error.
///
/// Streams the zip central directory from disk ([InputFileStream]) and
/// inflates ONLY the cover entry — peak memory is the decoded image, not the
/// whole book (same pattern as `extractEpubImageBytesFromFile`). The old
/// bytes-based variant made the details page read a 100MB+ illustrated EPUB
/// fully into memory on every uncached visit.
Future<Uint8List?> extractEpubCoverAsJpegFromFile(String path) {
  return Isolate.run(() => _extractEpubCoverJpegInIsolate(path));
}

Uint8List? _extractEpubCoverJpegInIsolate(String path) {
  InputFileStream? input;
  try {
    input = InputFileStream(path);
    final archive = ZipDecoder().decodeStream(input);
    final package = parseEpubPackageFromArchive(archive);
    final coverPath = package.coverPath;
    if (coverPath == null) return null;
    final coverBytes = readZipBytes(archive, coverPath);
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
  } finally {
    input?.close();
  }
}
