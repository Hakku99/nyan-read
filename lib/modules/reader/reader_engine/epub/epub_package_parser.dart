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
  });

  final Archive archive;
  final List<EpubTocEntry> toc;

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
  final opfDir = _parentDir(opfPath);

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

  // 3. TOC: EPUB3 nav → EPUB2 NCX → spine order.
  List<EpubTocEntry> toc = const [];
  final navItem = manifest.values
      .where((m) => m.props.split(' ').contains('nav'))
      .toList();
  if (navItem.isNotEmpty) {
    final navPath = resolveHref(opfDir, navItem.first.href).path;
    final navXml = readZipText(archive, navPath);
    if (navXml != null) {
      toc = _parseEpub3Nav(navXml, _parentDir(navPath));
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
        toc = _parseNcx(ncxXml, _parentDir(ncxPath));
      }
    }
  }
  if (toc.isEmpty) {
    // Synthetic TOC from spine order — a book with no navigation is still
    // readable front to back.
    final spineRefs = opf
        .findAllElements('itemref')
        .map((e) => e.getAttribute('idref'))
        .whereType<String>();
    toc = [
      for (final idref in spineRefs)
        if (manifest[idref] != null)
          EpubTocEntry(
            title: null,
            fileName: resolveHref(opfDir, manifest[idref]!.href).path,
            anchor: null,
          ),
    ];
  }

  // 4. Cover: EPUB3 properties="cover-image", else EPUB2
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

  return EpubPackage(archive: archive, toc: toc, coverPath: coverPath);
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
        ? li.findElements('span').map((s) => s.innerText.trim()).firstWhere(
            (t) => t.isNotEmpty,
            orElse: () => '')
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

String _parentDir(String path) {
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

Uint8List? readZipBytes(Archive archive, String path) {
  try {
    final entry = findZipEntry(archive, path);
    if (entry == null) return null;
    // archive 4.x: content is a typed Uint8List (lazy-decompressed on
    // first access).
    final content = entry.content;
    return content.isEmpty ? null : Uint8List.fromList(content);
  } catch (_) {
    return null;
  }
}

String? readZipText(Archive archive, String path) {
  final bytes = readZipBytes(archive, path);
  if (bytes == null) return null;
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return utf8.decode(bytes, allowMalformed: true);
  }
}
