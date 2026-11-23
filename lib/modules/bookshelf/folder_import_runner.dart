/// Sequential loop behind library-folder import, split out so the cancel and
/// progress rules can be tested without the shelf screen.
library;

/// `relinked`: the file matched an existing book whose source had gone
/// unreadable, so that book now points at the new source (no new row).
enum ImportOutcome { imported, skipped, relinked, failed }

class FolderImportResult {
  const FolderImportResult({
    required this.imported,
    required this.skipped,
    required this.stoppedEarly,
    this.relinked = 0,
  });

  final int imported;
  final int skipped;
  final int relinked;

  /// True only when a cancel actually left documents unprocessed; a cancel
  /// that arrives while the last book is in flight is not "early".
  final bool stoppedEarly;
}

/// Imports [docs] one by one. [isCancelled] is checked before each document,
/// so the one in flight always finishes and earlier imports are kept.
/// Documents without a usable uri/name are skipped without a progress call.
Future<FolderImportResult> importFolderDocs(
  List<Map<Object?, Object?>> docs, {
  required bool Function() isCancelled,
  required void Function(int current, String name) onProgress,
  required Future<ImportOutcome> Function(String uri, String name) importOne,
}) async {
  var imported = 0;
  var skipped = 0;
  var relinked = 0;
  var stoppedEarly = false;
  for (var i = 0; i < docs.length; i++) {
    if (isCancelled()) {
      stoppedEarly = true;
      break;
    }
    final uri = docs[i]['uri'] as String?;
    final name = docs[i]['name'] as String?;
    if (uri == null || uri.isEmpty || name == null || name.isEmpty) continue;
    onProgress(i + 1, name);
    final outcome = await importOne(uri, name);
    if (outcome == ImportOutcome.imported) imported++;
    if (outcome == ImportOutcome.skipped) skipped++;
    if (outcome == ImportOutcome.relinked) relinked++;
  }
  return FolderImportResult(
    imported: imported,
    skipped: skipped,
    relinked: relinked,
    stoppedEarly: stoppedEarly,
  );
}
