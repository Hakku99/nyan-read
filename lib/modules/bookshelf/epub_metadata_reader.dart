import 'dart:io';
import 'dart:isolate';

// archive_io adds InputFileStream (random-access zip reads from disk).
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';

import '../../core/models/book.dart';
import '../../core/utils/book_source_platform.dart';
import '../reader/reader_engine/epub/epub_package_parser.dart';

/// Title/author read from an EPUB's OPF. Either may be null.
typedef EpubMetadata = ({String? title, String? author});

// Keeps a pathological OPF from putting a novel into the title column.
const int _kMaxFieldLength = 200;

// Titles that converters write when they have none; the filename is better.
const Set<String> _kPlaceholderTitles = {
  'untitled',
  'unknown',
  'unnamed',
  'no title',
  'title',
  'book',
  'document',
  '未命名',
  '无标题',
  '無標題',
  '未知',
};
final RegExp _kUuidLike = RegExp(
    r'^(urn:uuid:)?[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

bool _isPlaceholderTitle(String title) {
  final t = title.trim().toLowerCase();
  return _kPlaceholderTitles.contains(t) || _kUuidLike.hasMatch(t);
}

/// Reads OPF metadata from the EPUB at [path] in a worker isolate; null on any
/// error. Streams the zip from disk, so memory stays at the OPF/nav size.
Future<EpubMetadata?> readEpubMetadataFromFile(String path) =>
    Isolate.run(() => _readInIsolate(path));

EpubMetadata? _readInIsolate(String path) {
  InputFileStream? input;
  try {
    input = InputFileStream(path);
    final package =
        parseEpubPackageFromArchive(ZipDecoder().decodeStream(input));
    String? cap(String? s) => s != null && s.length > _kMaxFieldLength
        ? s.substring(0, _kMaxFieldLength)
        : s;
    final title = package.title;
    return (
      title: title != null && _isPlaceholderTitle(title) ? null : cap(title),
      author: cap(package.author),
    );
  } catch (e) {
    debugPrint('Epub metadata read: ${e.runtimeType}');
    return null;
  } finally {
    input?.close();
  }
}

/// Import-time wrapper: finds a readable file for the source being imported
/// and reads its metadata. Never throws; null means "keep the filename".
///
/// [transientFilePath] is the picker's cached copy when there is one.
/// Content/tree URIs without it (library-folder import) are materialized to a
/// temp file that is deleted before returning.
// ponytail: folder import copies each EPUB a second time here (the
// fingerprint step already reads it through its own temp copy); share one
// copy if large-library import time ever matters.
Future<EpubMetadata?> readEpubMetadataForImport({
  required String sourceType,
  required String sourceLocator,
  String? transientFilePath,
}) async {
  String? tempPath;
  try {
    var path = transientFilePath;
    if (path == null || path.isEmpty) {
      switch (BookSourceType.normalize(sourceType)) {
        case BookSourceType.filePath:
          path = sourceLocator;
        case BookSourceType.androidContentUri:
        case BookSourceType.androidTreeUri:
          tempPath = await BookSourcePlatform.copyUriToTempFile(
            sourceLocator,
            extension: '.epub',
          );
          path = tempPath;
        default:
          return null;
      }
    }
    return await readEpubMetadataFromFile(path);
  } catch (e) {
    debugPrint('Epub metadata import read: ${e.runtimeType}');
    return null;
  } finally {
    if (tempPath != null) {
      try {
        await File(tempPath).delete();
      } catch (_) {
        // Leftovers age out via the 24h cache scavenger.
      }
    }
  }
}
