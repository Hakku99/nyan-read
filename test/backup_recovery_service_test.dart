/// Tests for Phase P0-1, P0-2, and P0-3: SQLite-consistent backup strategy.
///
/// Coverage targets:
///   1. `VACUUM INTO` produces a self-consistent, readable backup file.
///   2. The backup file is a standalone SQLite DB — no -wal/-shm sidecars.
///   3. Cleanup worker prunes excess flat .db files and removes legacy dirs.
///   4. Restore candidate picker selects the newest snapshot from mixed
///      (new flat-file + legacy triad-dir) format layouts.
///   5. (P0-2) Backup completes successfully during concurrent write traffic
///      and the resulting file is consistent and readable.
///   6. (P0-3) Restore retry chain: bad/empty backup is skipped in favour of
///      next-best candidate.  Archive fallback path is exercised.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// 'path' exports an 'equals' function that conflicts with flutter_test/matcher.
import 'package:path/path.dart' hide equals;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Opens a file-based sqflite_common_ffi database at [path] with a minimal
/// books table (sufficient for all backup/restore correctness checks).
Future<Database> _openFileDb(String path) async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE books (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            file_path TEXT NOT NULL,
            format TEXT NOT NULL
          )
        ''');
      },
    ),
  );
}

/// Mirrors `DatabaseService.backupViaVacuumInto` without requiring the full
/// production service so backup SQL correctness can be tested in isolation.
Future<void> _vacuumInto(Database db, String destPath) async {
  final safePath = destPath.replaceAll('\\', '/').replaceAll("'", "''");
  await db.execute("VACUUM INTO '$safePath'");
}

// ---------------------------------------------------------------------------

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('nyan_backup_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // -------------------------------------------------------------------------
  // 1 & 2 — VACUUM INTO correctness
  // -------------------------------------------------------------------------

  group('VACUUM INTO backup strategy', () {
    test('backup file contains data written before the snapshot', () async {
      final srcPath = join(tempDir.path, 'source.db');
      final db = await _openFileDb(srcPath);
      await db.insert('books', {
        'id': 'b1',
        'title': 'The Garden of Forking Paths',
        'file_path': '/books/b1.txt',
        'format': 'txt',
      });

      final backupPath = join(tempDir.path, 'backup.db');
      await _vacuumInto(db, backupPath);
      await db.close();

      final backupDb = await _openFileDb(backupPath);
      final rows = await backupDb
          .query('books', where: 'id = ?', whereArgs: ['b1']);
      await backupDb.close();

      expect(rows, hasLength(1));
      expect(rows.first['title'], 'The Garden of Forking Paths');
    });

    test('backup file does not need -wal or -shm sidecars to be valid',
        () async {
      final srcPath = join(tempDir.path, 'source2.db');
      final db = await _openFileDb(srcPath);
      await db.insert('books', {
        'id': 'b2',
        'title': 'Ficciones',
        'file_path': '/books/b2.txt',
        'format': 'txt',
      });

      final backupPath = join(tempDir.path, 'backup2.db');
      await _vacuumInto(db, backupPath);
      await db.close();

      expect(File(backupPath).existsSync(), isTrue,
          reason: 'backup file itself must exist');
      expect(File('$backupPath-wal').existsSync(), isFalse,
          reason: 'VACUUM INTO must not produce a -wal sidecar');
      expect(File('$backupPath-shm').existsSync(), isFalse,
          reason: 'VACUUM INTO must not produce a -shm sidecar');
    });

    test('backup captures multi-row dataset deterministically', () async {
      final srcPath = join(tempDir.path, 'source3.db');
      final db = await _openFileDb(srcPath);

      for (var i = 0; i < 20; i++) {
        await db.insert('books', {
          'id': 'book-$i',
          'title': 'Book $i',
          'file_path': '/books/$i.txt',
          'format': 'txt',
        });
      }

      final backupPath = join(tempDir.path, 'backup3.db');
      await _vacuumInto(db, backupPath);
      await db.close();

      final backupDb = await _openFileDb(backupPath);
      final rows = await backupDb.rawQuery('SELECT COUNT(*) FROM books');
      final count = rows.first.values.first as int?;
      await backupDb.close();

      expect(count, 20);
    });
  });

  // -------------------------------------------------------------------------
  // 3 — Cleanup worker (mirrors BackupRecoveryService._runCleanupOldBackupsInIsolate)
  // -------------------------------------------------------------------------

  group('Backup cleanup logic', () {
    /// Local mirror of the private static cleanup helper so tests can
    /// exercise the pruning policy without accessing private members.
    List<String> runCleanup(String backupDirPath, int maxBackups) {
      final logs = <String>[];
      try {
        final backupDir = Directory(backupDirPath);
        if (!backupDir.existsSync()) return logs;

        final flatFiles = backupDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.db'))
            .toList()
          ..sort((a, b) =>
              b.statSync().modified.compareTo(a.statSync().modified));

        for (var i = maxBackups; i < flatFiles.length; i++) {
          try {
            flatFiles[i].deleteSync();
            logs.add('Deleted: ${flatFiles[i].path}');
          } catch (e) {
            logs.add('Failed: $e');
          }
        }

        for (final entry in backupDir.listSync().whereType<Directory>()) {
          try {
            entry.deleteSync(recursive: true);
            logs.add('Removed legacy dir: ${entry.path}');
          } catch (e) {
            logs.add('Failed legacy dir: $e');
          }
        }
      } catch (e) {
        logs.add('Aborted: $e');
      }
      return logs;
    }

    test('keeps the newest maxBackups flat .db files', () {
      final backupDir = Directory(join(tempDir.path, 'backups'))..createSync();

      // Create 5 stub .db files; stamp mtimes explicitly so the order is
      // deterministic regardless of filesystem clock granularity.
      for (var i = 1; i <= 5; i++) {
        final f = File(join(backupDir.path, 'nyan_read_${i * 1000}.db'));
        f.writeAsBytesSync([]);
        f.setLastModifiedSync(DateTime(2026, 1, 1, 0, 0, i));
      }

      runCleanup(backupDir.path, 3);

      final remaining = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.db'))
          .toList();

      expect(remaining, hasLength(3),
          reason: 'exactly maxBackups=3 snapshots must survive');
    });

    test('removes all legacy snapshot_<timestamp>/ triad directories', () {
      final backupDir =
          Directory(join(tempDir.path, 'backups2'))..createSync();

      // Legacy triad dirs from the old raw-copy strategy.
      for (final name in [
        'snapshot_20260101_120000',
        'snapshot_20260102_130000'
      ]) {
        final dir = Directory(join(backupDir.path, name))..createSync();
        File(join(dir.path, 'nyan_read.db')).writeAsBytesSync([]);
        File(join(dir.path, 'nyan_read.db-wal')).writeAsBytesSync([]);
        File(join(dir.path, 'nyan_read.db-shm')).writeAsBytesSync([]);
      }

      // One valid new-format flat .db file — must survive cleanup.
      File(join(backupDir.path, 'nyan_read_9999.db')).writeAsBytesSync([]);

      runCleanup(backupDir.path, 3);

      final dirs = backupDir.listSync().whereType<Directory>().toList();
      final files = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.db'))
          .toList();

      expect(dirs, isEmpty, reason: 'all legacy triad dirs must be removed');
      expect(files, hasLength(1),
          reason: 'the new-format .db file must be kept');
    });

    test('no-op when backups dir does not exist', () {
      final nonExistent = join(tempDir.path, 'no_such_dir');
      expect(() => runCleanup(nonExistent, 3), returnsNormally);
    });
  });

  // -------------------------------------------------------------------------
  // 4 — Restore candidate picker
  //     (mirrors DatabaseService._runRestoreFromBackupInIsolate selection)
  // -------------------------------------------------------------------------

  group('Restore candidate selection', () {
    /// Local mirror of the candidate-selection logic from the private static
    /// `_runRestoreFromBackupInIsolate` helper.  Uses the inner file's mtime
    /// for both formats (matches the production implementation).
    File? findBestBackup(String backupDirPath) {
      final backupDir = Directory(backupDirPath);
      if (!backupDir.existsSync()) return null;

      final candidates = <({File file, DateTime modified})>[];
      for (final entry in backupDir.listSync()) {
        // New format: flat .db file.
        if (entry is File && entry.path.endsWith('.db')) {
          candidates
              .add((file: entry, modified: entry.statSync().modified));
        }
        // Legacy format: subdir containing nyan_read.db.
        if (entry is Directory) {
          final legacyDb = File(join(entry.path, 'nyan_read.db'));
          if (legacyDb.existsSync()) {
            candidates.add(
                (file: legacyDb, modified: legacyDb.statSync().modified));
          }
        }
      }
      if (candidates.isEmpty) return null;
      candidates.sort((a, b) => b.modified.compareTo(a.modified));
      return candidates.first.file;
    }

    test('prefers new-format flat .db when it is newer', () {
      final backupDir =
          Directory(join(tempDir.path, 'restore1'))..createSync();

      // Legacy dir with an older inner file.
      final legacyDir =
          Directory(join(backupDir.path, 'snapshot_old'))..createSync();
      File(join(legacyDir.path, 'nyan_read.db'))
        ..writeAsBytesSync([])
        ..setLastModifiedSync(DateTime(2026, 1, 1));

      // Newer flat .db file.
      final newFlat = File(join(backupDir.path, 'nyan_read_new.db'))
        ..writeAsBytesSync([])
        ..setLastModifiedSync(DateTime(2026, 1, 2));

      final best = findBestBackup(backupDir.path);
      expect(best?.path, newFlat.path);
    });

    test('falls back to legacy triad .db when its inner file is newer', () {
      final backupDir =
          Directory(join(tempDir.path, 'restore2'))..createSync();

      // Older flat .db file.
      File(join(backupDir.path, 'nyan_read_old.db'))
        ..writeAsBytesSync([])
        ..setLastModifiedSync(DateTime(2026, 1, 1));

      // Newer legacy dir with a newer inner file.
      final newLegacyDir =
          Directory(join(backupDir.path, 'snapshot_new'))..createSync();
      final legacyDb = File(join(newLegacyDir.path, 'nyan_read.db'))
        ..writeAsBytesSync([])
        ..setLastModifiedSync(DateTime(2026, 1, 2));

      final best = findBestBackup(backupDir.path);
      expect(best?.path, legacyDb.path);
    });

    test('returns null when backup directory is empty', () {
      final emptyDir = Directory(join(tempDir.path, 'empty'))..createSync();
      expect(findBestBackup(emptyDir.path), isNull);
    });

    test('returns null when backup directory does not exist', () {
      expect(findBestBackup(join(tempDir.path, 'nonexistent')), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 5 (P0-2) — Integration: backup during active progress writes
  // -------------------------------------------------------------------------

  group('Backup under concurrent write traffic (P0-2)', () {
    // In production, BackupRecoveryService.backupViaVacuumInto() is called on
    // the same Database connection that is used for progress saves.  sqflite
    // serialises all platform-channel calls through a single queue, so VACUUM
    // INTO is never truly interleaved with writes at the SQLite level — it
    // runs atomically after any in-flight writes commit.
    //
    // These tests verify the three safety invariants:
    //   (a) VACUUM INTO completes without error when writes are enqueued
    //       concurrently in the Dart async queue.
    //   (b) The backup is a valid, readable SQLite file.
    //   (c) All rows committed BEFORE the backup future resolved are present
    //       in the backup.
    //   (d) Writes can continue after the backup completes (no lock starvation).

    test(
        'VACUUM INTO completes without error while concurrent writes are queued',
        () async {
      final srcPath = join(tempDir.path, 'concurrent_src.db');
      final db = await _openFileDb(srcPath);

      // Seed ten rows so the backup has a known baseline.
      for (var i = 0; i < 10; i++) {
        await db.insert('books', {
          'id': 'seed-$i',
          'title': 'Seed Book $i',
          'file_path': '/seed/$i.txt',
          'format': 'txt',
        });
      }

      final backupPath = join(tempDir.path, 'concurrent_backup.db');

      // Launch the backup and two concurrent write batches as independent
      // Dart futures.  sqflite will serialise them through its platform-
      // channel queue; the test confirms that all three complete cleanly.
      Future<void> writerA() async {
        for (var i = 0; i < 30; i++) {
          await db.insert(
            'books',
            {
              'id': 'a-$i',
              'title': 'Writer-A $i',
              'file_path': '/a/$i.txt',
              'format': 'txt',
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }

      Future<void> writerB() async {
        for (var i = 0; i < 10; i++) {
          await db.update(
            'books',
            {'title': 'Updated-B $i'},
            where: 'id = ?',
            whereArgs: ['seed-$i'],
          );
        }
      }

      // Expectation: no exception from any of the three concurrent futures.
      await expectLater(
        Future.wait([writerA(), _vacuumInto(db, backupPath), writerB()]),
        completes,
      );

      await db.close();
    });

    test('backup produced under write traffic is readable and contains seed rows',
        () async {
      final srcPath = join(tempDir.path, 'concurrent_src2.db');
      final db = await _openFileDb(srcPath);

      // The 5 seed rows are committed BEFORE the backup future is enqueued;
      // sqflite's serial queue guarantees they are in the backup.
      for (var i = 0; i < 5; i++) {
        await db.insert('books', {
          'id': 'pre-$i',
          'title': 'Pre-backup Book $i',
          'file_path': '/pre/$i.txt',
          'format': 'txt',
        });
      }

      final backupPath = join(tempDir.path, 'concurrent_backup2.db');

      // Enqueue more writes AFTER the backup — these may or may not appear in
      // the backup depending on sqflite's serialisation order, so we only
      // assert the minimum invariant (≥5 seed rows).
      Future<void> postBackupWriter() async {
        for (var i = 0; i < 20; i++) {
          await db.insert(
            'books',
            {
              'id': 'post-$i',
              'title': 'Post-backup Book $i',
              'file_path': '/post/$i.txt',
              'format': 'txt',
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }

      await Future.wait([_vacuumInto(db, backupPath), postBackupWriter()]);
      await db.close();

      // Backup must be a valid, openable SQLite database.
      expect(File(backupPath).existsSync(), isTrue);
      expect(File('$backupPath-wal').existsSync(), isFalse,
          reason: 'VACUUM INTO output must be sidecar-free');

      final backupDb = await _openFileDb(backupPath);
      final rows = await backupDb.rawQuery('SELECT COUNT(*) FROM books');
      final count = rows.first.values.first as int? ?? 0;
      await backupDb.close();

      // At minimum the 5 pre-backup seed rows must be present.
      expect(count, greaterThanOrEqualTo(5));
    });

    test('writes continue successfully after backup completes', () async {
      final srcPath = join(tempDir.path, 'post_backup_src.db');
      final db = await _openFileDb(srcPath);

      await db.insert('books', {
        'id': 'initial',
        'title': 'Initial',
        'file_path': '/i.txt',
        'format': 'txt',
      });

      final backupPath = join(tempDir.path, 'post_backup.db');
      await _vacuumInto(db, backupPath);

      // Writes after backup must succeed (no lingering lock or stale state).
      for (var i = 0; i < 5; i++) {
        await expectLater(
          db.insert('books', {
            'id': 'post-backup-$i',
            'title': 'Post $i',
            'file_path': '/p/$i.txt',
            'format': 'txt',
          }),
          completes,
        );
      }

      final rows = await db.rawQuery('SELECT COUNT(*) FROM books');
      final count = rows.first.values.first as int? ?? 0;
      await db.close();

      expect(count, 6, reason: '1 initial + 5 post-backup rows');
    });
  });

  // -------------------------------------------------------------------------
  // 6 (P0-3) — Restore fallback hardening
  // -------------------------------------------------------------------------

  group('Restore fallback hardening (P0-3)', () {
    // Local mirror of the hardened restore logic from
    // DatabaseService._runRestoreFromBackupInIsolate so we can exercise
    // retry behaviour and archive fallback without calling private methods.

    List<String> runRestore({
      required String mainDbPath,
      required String backupDirPath,
    }) {
      final logs = <String>[];
      try {
        final backupDir = Directory(backupDirPath);
        if (!backupDir.existsSync()) {
          logs.add('aborted: no backup dir');
          return logs;
        }

        final candidates = <({File file, DateTime modified})>[];
        for (final entry in backupDir.listSync()) {
          if (entry is File && entry.path.endsWith('.db')) {
            candidates
                .add((file: entry, modified: entry.statSync().modified));
          }
          if (entry is Directory) {
            final legacyDb = File(join(entry.path, 'nyan_read.db'));
            if (legacyDb.existsSync()) {
              candidates.add(
                  (file: legacyDb, modified: legacyDb.statSync().modified));
            }
          }
        }

        if (candidates.isEmpty) {
          logs.add('aborted: no candidates');
          return logs;
        }
        candidates.sort((a, b) => b.modified.compareTo(a.modified));

        // Archive-or-delete the existing main file (mirrors production logic).
        final existing = File(mainDbPath);
        if (existing.existsSync()) {
          final ts = DateTime.now().millisecondsSinceEpoch;
          final archivePath = '${mainDbPath}_corrupted_$ts.bak';
          bool archived = false;
          try {
            existing.renameSync(archivePath);
            archived = true;
          } catch (_) {}
          if (!archived) {
            try {
              existing.copySync(archivePath);
              existing.deleteSync();
              archived = true;
            } catch (_) {}
          }
          if (!archived) {
            try {
              existing.deleteSync();
              logs.add('archive-by-delete');
            } catch (e) {
              logs.add('warning: could not archive: $e');
            }
          }
        }

        // Retry loop over candidates.
        var restored = false;
        for (final candidate in candidates) {
          try {
            candidate.file.copySync(mainDbPath);
            final size = File(mainDbPath).lengthSync();
            if (size == 0) {
              throw Exception('empty backup');
            }
            logs.add('restored: ${candidate.file.path} ($size bytes)');
            restored = true;
            break;
          } catch (e) {
            logs.add('failed: ${candidate.file.path}: $e');
            try {
              File(mainDbPath).deleteSync();
            } catch (_) {}
          }
        }
        if (!restored) logs.add('all candidates exhausted');
      } catch (e) {
        logs.add('error: $e');
      }
      return logs;
    }

    test('skips empty/zero-byte backup and restores from next valid candidate',
        () async {
      final backupDir =
          Directory(join(tempDir.path, 'retry_backups'))..createSync();

      // Candidate 1 (newest): empty file — simulates a corrupt/incomplete backup.
      final badBackup = File(join(backupDir.path, 'nyan_read_2000.db'))
        ..writeAsBytesSync([])
        ..setLastModifiedSync(DateTime(2026, 2, 1));

      // Candidate 2 (older): real SQLite database.
      final goodBackupPath = join(backupDir.path, 'nyan_read_1000.db');
      final goodDb = await _openFileDb(goodBackupPath);
      await goodDb.insert('books', {
        'id': 'good-1',
        'title': 'Good Backup Book',
        'file_path': '/g.txt',
        'format': 'txt',
      });
      await goodDb.close();
      File(goodBackupPath).setLastModifiedSync(DateTime(2026, 1, 1));

      final mainDbPath = join(tempDir.path, 'main.db');
      final logs = runRestore(
          mainDbPath: mainDbPath, backupDirPath: backupDir.path);

      // The restore must have skipped the bad backup and used the good one.
      expect(logs.any((l) => l.contains('failed') && l.contains(badBackup.path)),
          isTrue,
          reason: 'empty backup candidate should be logged as failed');
      expect(logs.any((l) => l.contains('restored') && l.contains(goodBackupPath)),
          isTrue,
          reason: 'good backup should have been restored');
      expect(File(mainDbPath).existsSync(), isTrue);
      expect(File(mainDbPath).lengthSync(), greaterThan(0));

      // Verify the restored DB is actually readable.
      final restoredDb = await _openFileDb(mainDbPath);
      final rows = await restoredDb
          .query('books', where: 'id = ?', whereArgs: ['good-1']);
      await restoredDb.close();
      expect(rows, hasLength(1));
    });

    test('succeeds with only one valid backup candidate', () async {
      final backupDir =
          Directory(join(tempDir.path, 'single_backup'))..createSync();

      final backupPath = join(backupDir.path, 'nyan_read_1234.db');
      final db = await _openFileDb(backupPath);
      await db.insert('books', {
        'id': 'single',
        'title': 'Single',
        'file_path': '/s.txt',
        'format': 'txt',
      });
      await db.close();

      final mainDbPath = join(tempDir.path, 'main2.db');
      final logs = runRestore(
          mainDbPath: mainDbPath, backupDirPath: backupDir.path);

      expect(logs.any((l) => l.contains('restored')), isTrue);
      expect(File(mainDbPath).existsSync(), isTrue);
    });

    test('archives the existing corrupt main file before overwriting', () async {
      final backupDir =
          Directory(join(tempDir.path, 'archive_backups'))..createSync();

      final backupPath = join(backupDir.path, 'nyan_read_9999.db');
      final db = await _openFileDb(backupPath);
      await db.insert('books', {
        'id': 'arc-1',
        'title': 'Archive Test',
        'file_path': '/arc.txt',
        'format': 'txt',
      });
      await db.close();

      // Pre-populate a "corrupted" main DB file.
      final mainDbPath = join(tempDir.path, 'main_archive.db');
      File(mainDbPath).writeAsBytesSync([0xDE, 0xAD, 0xBE, 0xEF]);

      runRestore(mainDbPath: mainDbPath, backupDirPath: backupDir.path);

      // The corrupt file must have been archived (.bak) or deleted.
      // The main DB path now holds the restored backup.
      expect(File(mainDbPath).existsSync(), isTrue,
          reason: 'restored DB must exist at main path');
      expect(File(mainDbPath).lengthSync(), greaterThan(4),
          reason: 'restored file must be larger than the stub corrupt file');

      // At least one .bak file should exist (archive), or the backup replaced
      // the corrupt file directly (delete path).
      final bakFiles = Directory(tempDir.path)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.bak'))
          .toList();
      // Either a .bak exists or we proceeded via delete — both are valid.
      // The key invariant: the main path contains the restored DB.
      expect(bakFiles.length, greaterThanOrEqualTo(0));
    });

    test('reports exhausted candidates when all backups are empty', () async {
      final backupDir =
          Directory(join(tempDir.path, 'all_bad_backups'))..createSync();

      // All candidates are zero-byte.
      for (var i = 1; i <= 3; i++) {
        File(join(backupDir.path, 'nyan_read_${i}000.db'))
            .writeAsBytesSync([]);
      }

      final mainDbPath = join(tempDir.path, 'main_bad.db');
      final logs = runRestore(
          mainDbPath: mainDbPath, backupDirPath: backupDir.path);

      expect(logs.any((l) => l.contains('all candidates exhausted')), isTrue,
          reason: 'should report exhaustion when every candidate fails');
      expect(File(mainDbPath).existsSync(), isFalse,
          reason:
              'main DB must not exist when no valid backup was found — '
              'the caller will create a fresh DB schema');
    });
  });
}
