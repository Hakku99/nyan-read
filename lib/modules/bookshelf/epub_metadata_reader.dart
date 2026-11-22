import 'dart:io';
import 'dart:isolate';

// archive_io adds InputFileStream (random-access zip reads from disk).
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

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

/// Title/author stored for an imported book: OPF values when present, else the
/// filename without extension and the 'Unknown' author placeholder.
({String title, String author}) resolveImportedTitleAuthor(
  String fileName,
  EpubMetadata? meta,
) =>
    (
      title: meta?.title ?? p.basenameWithoutExtension(fileName),
      author: meta?.author ?? 'Unknown',
    );

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
    // Cut on code points, not UTF-16 units: substring could split a surrogate
    // pair (emoji, CJK Extension B) and leave a lone surrogate in the title.
    String? cap(String? s) => s != null && s.runes.length > _kMaxFieldLength
        ? String.fromCharCodes(s.runes.take(_kMaxFieldLength))
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
// ponytail: folder import still copies each EPUB once here (the fingerprint
// step now samples head/tail without copying). Reading just the zip
// directory + OPF in place would need a range-reading zip reader; add it if
// large EPUB libraries import too slowly.
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
