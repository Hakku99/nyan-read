/// importFolderDocs: cancel is checked before each document, the one in
/// flight finishes, and only a cancel that left files behind counts as early.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/modules/bookshelf/folder_import_runner.dart';

List<Map<Object?, Object?>> _docs(int n) => [
      for (var i = 0; i < n; i++) {'uri': 'content://d/$i', 'name': 'b$i.txt'},
    ];

void main() {
  test('imports everything and reports progress 1..n', () async {
    final progress = <int>[];
    final r = await importFolderDocs(
      _docs(3),
      isCancelled: () => false,
      onProgress: (c, _) => progress.add(c),
      importOne: (_, __) async => ImportOutcome.imported,
    );
    expect((r.imported, r.skipped, r.stoppedEarly), (3, 0, false));
    expect(progress, [1, 2, 3]);
  });

  test('cancel before the first book imports nothing', () async {
    var calls = 0;
    final r = await importFolderDocs(
      _docs(3),
      isCancelled: () => true,
      onProgress: (_, __) {},
      importOne: (_, __) async {
        calls++;
        return ImportOutcome.imported;
      },
    );
    expect(calls, 0);
    expect((r.imported, r.stoppedEarly), (0, true));
  });

  test('cancel mid-run keeps earlier books and lets the in-flight one finish',
      () async {
    var cancelled = false;
    final r = await importFolderDocs(
      _docs(5),
      isCancelled: () => cancelled,
      onProgress: (_, __) {},
      importOne: (_, name) async {
        if (name == 'b1.txt') cancelled = true; // tapped while b1 is running
        return ImportOutcome.imported;
      },
    );
    expect((r.imported, r.stoppedEarly), (2, true));
  });

  test('cancel while the last book runs is not an early stop', () async {
    var cancelled = false;
    final r = await importFolderDocs(
      _docs(2),
      isCancelled: () => cancelled,
      onProgress: (_, __) {},
      importOne: (_, name) async {
        if (name == 'b1.txt') cancelled = true;
        return ImportOutcome.imported;
      },
    );
    expect((r.imported, r.stoppedEarly), (2, false));
  });

  test('counts skipped, ignores failed, skips unusable docs silently',
      () async {
    final progress = <int>[];
    final docs = <Map<Object?, Object?>>[
      {'uri': 'content://d/0', 'name': 'a.txt'},
      {'uri': '', 'name': 'broken'},
      {'uri': 'content://d/2', 'name': null},
      {'uri': 'content://d/3', 'name': 'dup.txt'},
      {'uri': 'content://d/4', 'name': 'bad.txt'},
    ];
    final r = await importFolderDocs(
      docs,
      isCancelled: () => false,
      onProgress: (c, _) => progress.add(c),
      importOne: (_, name) async => switch (name) {
        'a.txt' => ImportOutcome.imported,
        'dup.txt' => ImportOutcome.skipped,
        _ => ImportOutcome.failed,
      },
    );
    expect((r.imported, r.skipped, r.stoppedEarly), (1, 1, false));
    expect(progress, [1, 4, 5]);
  });

  test('joinToastDescription keeps both the relink and cancel notes', () {
    expect(joinToastDescription(['Re-linked 2', null]), 'Re-linked 2');
    expect(joinToastDescription([null, 'Import cancelled']),
        'Import cancelled');
    expect(joinToastDescription(['Re-linked 2', 'Import cancelled']),
        'Re-linked 2 Import cancelled');
    expect(joinToastDescription([null, null]), isNull);
    expect(joinToastDescription(['', null]), isNull);
  });

  test('relinked outcomes are counted apart from imported and skipped',
      () async {
    final r = await importFolderDocs(
      [
        {'uri': 'content://d/0', 'name': 'a.txt'},
        {'uri': 'content://d/1', 'name': 'b.txt'},
        {'uri': 'content://d/2', 'name': 'c.txt'},
      ],
      isCancelled: () => false,
      onProgress: (_, __) {},
      importOne: (_, name) async => switch (name) {
        'a.txt' => ImportOutcome.relinked,
        'b.txt' => ImportOutcome.relinked,
        _ => ImportOutcome.imported,
      },
    );
    expect((r.imported, r.skipped, r.relinked), (1, 0, 2));
  });
}
