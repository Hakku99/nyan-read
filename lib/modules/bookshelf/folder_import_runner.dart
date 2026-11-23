/// Sequential loop behind library-folder import, split out so the cancel and
/// progress rules can be tested without the shelf screen.
library;

enum ImportOutcome { imported, skipped, failed }

class FolderImportResult {
  const FolderImportResult({
    required this.imported,
    required this.skipped,
    required this.stoppedEarly,
  });

  final int imported;
  final int skipped;

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
  }
  return FolderImportResult(
    imported: imported,
    skipped: skipped,
    stoppedEarly: stoppedEarly,
  );
}
