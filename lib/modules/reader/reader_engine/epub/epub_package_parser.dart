// Minimal, tolerant EPUB package parser (P3c, 2026-07) — replaces epubx.
//
// Reads exactly what nyan-read needs and nothing else:
//   • container.xml → OPF path
//   • OPF manifest/spine + cover reference
//   • TOC: EPUB3 nav document, falling back to EPUB2 NCX, falling back to
//     spine order (synthetic titles)
// No resource is ever eagerly decompressed — callers read entries on demand
// through [readZipText] / [readZipBytes], which keeps peak memory at "one
// entry" instead of "the whole book" (the epubx readBook failure mode).
//
// Tolerance rules learned from real books:
//   • hrefs may use backslashes (Windows-authored) — separators normalized
//   • hrefs may be percent-encoded — decoded before lookup
//   • missing TOC targets resolve to zero-paragraph chapters, never throws

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';

class EpubTocEntry {
  EpubTocEntry({
    required this.title,
    required this.fileName,
    required this.anchor,
    this.children = const [],
  });

  final String? title;

  /// Zip entry path of the chapter document (already resolved against the
  /// OPF directory and separator-normalized). Null for label-only entries.
  final String? fileName;
  final String? anchor;
  final List<EpubTocEntry> children;
}

class EpubPackage {
  EpubPackage({
    required this.archive,
    required this.toc,
    required this.coverPath,
    this.spinePaths = const [],
    this.title,
    this.author,
  });

  /// OPF `dc:title` (first non-empty), whitespace-collapsed; null if absent.
  final String? title;

  /// OPF `dc:creator` entries joined with ", "; null if absent.
  final String? author;

  final Archive archive;
  final List<EpubTocEntry> toc;

  /// Resolved zip paths of spine itemrefs in spine order — the authoritative
  /// linear reading order. Content enumeration follows this (the TOC only
  /// maps titles/anchors into it); empty only for hand-built packages,
  /// which then degrade to TOC-driven enumeration.
  final List<String> spinePaths;

  /// Resolved zip path of the cover image, or null when undeclared.
  final String? coverPath;
}

/// Parses the EPUB container/OPF/TOC structure from raw bytes.
/// Throws [FormatException] only when the file is not an EPUB at all
/// (unreadable zip / no container / no OPF); everything else degrades.
EpubPackage parseEpubPackage(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (e) {
    throw FormatException('Not a readable zip archive: $e');
  }
  return parseEpubPackageFromArchive(archive);
}

EpubPackage parseEpubPackageFromArchive(Archive archive) {
  // 1. container.xml → rootfile (OPF path).
  final containerXml = readZipText(archive, 'META-INF/container.xml');
  if (containerXml == null) {
    throw const FormatException('EPUB has no META-INF/container.xml');
  }
  final String opfPath;
  try {
    final container = XmlDocument.parse(containerXml);
    final rootfile = container
        .findAllElements('rootfile')
        .map((e) => e.getAttribute('full-path'))
        .firstWhere((p) => p != null && p.isNotEmpty, orElse: () => null);
    if (rootfile == null) {
      throw const FormatException('container.xml has no rootfile');
    }
    opfPath = rootfile;
  } on FormatException {
    rethrow;
  } catch (e) {
    throw FormatException('Malformed container.xml: $e');
  }

  final opfXml = readZipText(archive, opfPath);
  if (opfXml == null) {
    throw FormatException('EPUB OPF missing: $opfPath');
  }
  final XmlDocument opf;
  try {
    opf = XmlDocument.parse(opfXml);
  } catch (e) {
    throw FormatException('Malformed OPF: $e');
  }
  final opfDir = zipParentDir(opfPath);

  // 2. Manifest: id → (href, media-type, properties).
  final manifest = <String, ({String href, String mediaType, String props})>{};
  for (final item in opf.findAllElements('item')) {
    final id = item.getAttribute('id');
    final href = item.getAttribute('href');
    if (id == null || href == null) continue;
    manifest[id] = (
      href: href,
      mediaType: item.getAttribute('media-type') ?? '',
      props: item.getAttribute('properties') ?? '',
    );
  }

  // 3. Spine: the authoritative linear reading order, as resolved zip paths.
  final spinePaths = <String>[
    for (final idref in opf
        .findAllElements('itemref')
        .map((e) => e.getAttribute('idref'))
        .whereType<String>())
      if (manifest[idref] != null)
        resolveHref(opfDir, manifest[idref]!.href).path,
  ];

  // 4. TOC: EPUB3 nav → EPUB2 NCX → spine order.
  List<EpubTocEntry> toc = const [];
  final navItem =
      manifest.values.where((m) => m.props.split(' ').contains('nav')).toList();
  if (navItem.isNotEmpty) {
    final navPath = resolveHref(opfDir, navItem.first.href).path;
    final navXml = readZipText(archive, navPath);
    if (navXml != null) {
      toc = _parseEpub3Nav(navXml, zipParentDir(navPath));
    }
  }
  if (toc.isEmpty) {
    final ncxItem = manifest.values
        .where((m) => m.mediaType == 'application/x-dtbncx+xml')
        .toList();
    if (ncxItem.isNotEmpty) {
      final ncxPath = resolveHref(opfDir, ncxItem.first.href).path;
      final ncxXml = readZipText(archive, ncxPath);
      if (ncxXml != null) {
        toc = _parseNcx(ncxXml, zipParentDir(ncxPath));
      }
    }
  }
  if (toc.isEmpty) {
    // Synthetic TOC from spine order — a book with no navigation is still
    // readable front to back.
    toc = [
      for (final path in spinePaths)
        EpubTocEntry(title: null, fileName: path, anchor: null),
    ];
  }

  // 5. Cover: EPUB3 properties="cover-image", else EPUB2
  //    <meta name="cover" content="<manifest-id>">.
  String? coverPath;
  final coverItem = manifest.values
      .where((m) => m.props.split(' ').contains('cover-image'))
      .toList();
  if (coverItem.isNotEmpty) {
    coverPath = resolveHref(opfDir, coverItem.first.href).path;
  } else {
    for (final meta in opf.findAllElements('meta')) {
      if (meta.getAttribute('name') == 'cover') {
        final coverId = meta.getAttribute('content');
        final item = coverId == null ? null : manifest[coverId];
        if (item != null) {
          coverPath = resolveHref(opfDir, item.href).path;
        }
        break;
      }
    }
  }

  // 6. Metadata: dc:title / dc:creator. namespace '*' matches the local name,
  //    since the elements carry a `dc:` prefix.
  String? clean(XmlElement e) {
    final text = e.innerText.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? null : text;
  }

  // EPUB3 refinements: <meta refines="#id" property="title-type|role">value.
  String? refinement(XmlElement e, String property) {
    final id = e.getAttribute('id');
    if (id == null || id.isEmpty) return null;
    for (final meta in opf.findAllElements('meta', namespace: '*')) {
      if (meta.getAttribute('refines') == '#$id' &&
          meta.getAttribute('property') == property) {
        return meta.innerText.trim().toLowerCase();
      }
    }
    return null;
  }

  // Main title: an explicit title-type "main" wins; otherwise the first
  // untyped title (the common case); otherwise the first non-empty one, so a
  // subtitle/series entry listed first is not mistaken for the book title.
  final titleEntries = [
    for (final e in opf.findAllElements('title', namespace: '*'))
      if (clean(e) != null)
        (text: clean(e)!, type: refinement(e, 'title-type')),
  ];
  final title = (titleEntries.where((t) => t.type == 'main').firstOrNull ??
          titleEntries.where((t) => t.type == null).firstOrNull ??
          titleEntries.firstOrNull)
      ?.text;

  // Authors: a creator with no role is an author by spec; drop the ones
  // explicitly marked as something else (illustrator, translator, editor...)
  // via EPUB2 opf:role or EPUB3 refines role. If that leaves nobody (e.g. an
  // anthology with only an editor), fall back to everyone listed.
  final creatorEntries = [
    for (final e in opf.findAllElements('creator', namespace: '*'))
      if (clean(e) != null)
        (
          text: clean(e)!,
          role: (e.attributes
                      .where((a) => a.name.local == 'role')
                      .firstOrNull
                      ?.value ??
                  refinement(e, 'role'))
              ?.trim()
              .toLowerCase(),
        ),
  ];
  final authors = creatorEntries
      .where((c) => c.role == null || c.role!.isEmpty || c.role == 'aut')
      .toList();
  final creators =
      (authors.isEmpty ? creatorEntries : authors).map((c) => c.text).toList();

  return EpubPackage(
    archive: archive,
    toc: toc,
    coverPath: coverPath,
    spinePaths: spinePaths,
    title: title,
    author: creators.isEmpty ? null : creators.join(', '),
  );
}

List<EpubTocEntry> _parseEpub3Nav(String navXml, String navDir) {
  try {
    final doc = XmlDocument.parse(navXml);
    // Prefer the nav flagged epub:type="toc"; fall back to the first <nav>.
    XmlElement? tocNav;
    for (final nav in doc.findAllElements('nav')) {
      final type = nav.attributes
          .where((a) => a.name.local == 'type')
          .map((a) => a.value)
          .toList();
      if (type.contains('toc')) {
        tocNav = nav;
        break;
      }
      tocNav ??= nav;
    }
    if (tocNav == null) return const [];
    final ol = tocNav.findElements('ol').toList();
    if (ol.isEmpty) return const [];
    return _parseNavList(ol.first, navDir);
  } catch (_) {
    return const [];
  }
}

List<EpubTocEntry> _parseNavList(XmlElement ol, String navDir) {
  final entries = <EpubTocEntry>[];
  for (final li in ol.findElements('li')) {
    final a = li.findElements('a').toList();
    final childOl = li.findElements('ol').toList();
    final href = a.isEmpty ? null : a.first.getAttribute('href');
    final title = a.isEmpty
        ? li
            .findElements('span')
            .map((s) => s.innerText.trim())
            .firstWhere((t) => t.isNotEmpty, orElse: () => '')
        : a.first.innerText.trim();
    final resolved = href == null ? null : resolveHref(navDir, href);
    entries.add(EpubTocEntry(
      title: title.isEmpty ? null : title,
      fileName: resolved?.path,
      anchor: resolved?.anchor,
      children:
          childOl.isEmpty ? const [] : _parseNavList(childOl.first, navDir),
    ));
  }
  return entries;
}

List<EpubTocEntry> _parseNcx(String ncxXml, String ncxDir) {
  try {
    final doc = XmlDocument.parse(ncxXml);
    final navMaps = doc.findAllElements('navMap').toList();
    if (navMaps.isEmpty) return const [];
    return _parseNavPoints(navMaps.first, ncxDir);
  } catch (_) {
    return const [];
  }
}

List<EpubTocEntry> _parseNavPoints(XmlElement parent, String ncxDir) {
  final entries = <EpubTocEntry>[];
  for (final navPoint in parent.findElements('navPoint')) {
    final label = navPoint
        .findElements('navLabel')
        .expand((l) => l.findElements('text'))
        .map((t) => t.innerText.trim())
        .firstWhere((t) => t.isNotEmpty, orElse: () => '');
    final src = navPoint
        .findElements('content')
        .map((c) => c.getAttribute('src'))
        .firstWhere((s) => s != null && s.isNotEmpty, orElse: () => null);
    final resolved = src == null ? null : resolveHref(ncxDir, src);
    entries.add(EpubTocEntry(
      title: label.isEmpty ? null : label,
      fileName: resolved?.path,
      anchor: resolved?.anchor,
      children: _parseNavPoints(navPoint, ncxDir),
    ));
  }
  return entries;
}

/// Resolved href: zip path + optional `#anchor`.
({String path, String? anchor}) resolveHref(String baseDir, String rawHref) {
  var href = rawHref.trim().replaceAll('\\', '/');
  String? anchor;
  final hash = href.indexOf('#');
  if (hash != -1) {
    anchor = href.substring(hash + 1);
    href = href.substring(0, hash);
    if (anchor.isEmpty) anchor = null;
  }
  href = Uri.decodeComponent(href);

  // Resolve against baseDir with ../ handling.
  final segments = <String>[
    if (baseDir.isNotEmpty) ...baseDir.split('/'),
  ];
  for (final part in href.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (segments.isNotEmpty) segments.removeLast();
      continue;
    }
    segments.add(part);
  }
  return (path: segments.join('/'), anchor: anchor);
}

/// Returns the parent of a ZIP path, including separator-mangled paths.
String zipParentDir(String path) {
  final normalized = path.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  return slash == -1 ? '' : normalized.substring(0, slash);
}

/// Tolerant zip entry lookup: exact match first, then separator-normalized
/// case-insensitive, then suffix match (handles books whose internal hrefs
/// disagree with entry paths about leading directories).
ArchiveFile? findZipEntry(Archive archive, String path) {
  final wanted = path.replaceAll('\\', '/');
  final lowerWanted = wanted.toLowerCase();
  ArchiveFile? suffixHit;
  for (final entry in archive.files) {
    if (!entry.isFile) continue;
    final name = entry.name.replaceAll('\\', '/');
    if (name == wanted) return entry;
    final lowerName = name.toLowerCase();
    if (lowerName == lowerWanted) return entry;
    if (suffixHit == null && lowerName.endsWith('/$lowerWanted')) {
      suffixHit = entry;
    }
  }
  return suffixHit;
}

/// Decompressed-size ceiling for a single zip entry (64 MB). A crafted EPUB
/// can deflate a tiny archive into multi-GB entries (zip bomb); inflating
/// one during parse OOMs the whole process — the Dart heap is process-wide,
/// so "it happens in an isolate" is no protection. Real chapter/image
/// entries sit far below this.
const int kMaxEpubEntryBytes = 64 * 1024 * 1024;

/// Throws [FormatException] when the entry's declared or actual decompressed
/// size exceeds [maxEntryBytes] — parse callers surface it as parseFailed,
/// image/cover callers catch and fall back to a placeholder.
Uint8List? readZipBytes(Archive archive, String path,
    {int maxEntryBytes = kMaxEpubEntryBytes}) {
  final ArchiveFile? entry;
  try {
    entry = findZipEntry(archive, path);
  } catch (_) {
    return null;
  }
  return entry == null
      ? null
      : readZipEntryBytes(entry, maxEntryBytes: maxEntryBytes);
}

/// Reads only the selected entry while enforcing the same bounds as lookup.
Uint8List? readZipEntryBytes(ArchiveFile entry,
    {int maxEntryBytes = kMaxEpubEntryBytes}) {
  // The central directory declares the uncompressed size — reject before
  // inflating anything.
  if (entry.size > maxEntryBytes) {
    throw FormatException(
        'EPUB entry too large: ${entry.name} (${entry.size} > $maxEntryBytes bytes)');
  }
  final Uint8List content;
  try {
    // archive 4.x: content is a typed Uint8List (lazy-decompressed on
    // first access).
    content = entry.content;
  } catch (_) {
    return null;
  }
  // ponytail: a header that lies about its size already inflated by the time
  // we can measure it; this check only turns the result into a loud failure.
  // A streaming decompress with a hard cap is the upgrade path if real bombs
  // show up in the wild.
  if (content.length > maxEntryBytes) {
    throw FormatException(
        'EPUB entry too large after inflate: ${entry.name} (${content.length} bytes)');
  }
  return content.isEmpty ? null : Uint8List.fromList(content);
}

String? readZipText(Archive archive, String path) =>
    _decodeZipText(readZipBytes(archive, path));

/// Decodes a chapter whose entry has already been selected.
String? readZipEntryText(ArchiveFile entry) =>
    _decodeZipText(readZipEntryBytes(entry));

String? _decodeZipText(Uint8List? bytes) {
  if (bytes == null) return null;
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return utf8.decode(bytes, allowMalformed: true);
  }
}
