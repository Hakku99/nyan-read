/// Tests for BookSandboxCopier.copySync (analysis item #1): imported books
/// are copied into the app-owned library with readable names and
/// collision-safe suffixes.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/utils/book_sandbox_copier.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory tempRoot;
  late Directory libraryDir;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('nyan_copier_test');
    libraryDir = Directory(path.join(tempRoot.path, 'books'));
  });

  tearDown(() async {
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {
      // Windows can briefly hold handles; leftover temp dirs are harmless.
    }
  });

  File writeSource(String name, String content) {
    final f = File(path.join(tempRoot.path, name));
    f.writeAsStringSync(content);
    return f;
  }

  test('copies the file into the library keeping the original name', () {
    final source = writeSource('My Book.txt', 'hello');

    final result = BookSandboxCopier.copySync(
        source.path, libraryDir.path, 'My Book.txt');

    expect(path.basename(result), 'My Book.txt');
    expect(path.dirname(result), libraryDir.path);
    expect(File(result).readAsStringSync(), 'hello');
    // Source is untouched — deleting it is the picker/OS's business.
    expect(source.existsSync(), isTrue);
  });

  test('creates the library directory when missing', () {
    final source = writeSource('a.epub', 'x');
    expect(libraryDir.existsSync(), isFalse);

    BookSandboxCopier.copySync(source.path, libraryDir.path, 'a.epub');

    expect(libraryDir.existsSync(), isTrue);
  });

  test('appends (n) suffix on filename collision', () {
    final first = writeSource('dup.txt', 'first');
    final second = writeSource('other.txt', 'second');
    final third = writeSource('another.txt', 'third');

    final p1 =
        BookSandboxCopier.copySync(first.path, libraryDir.path, 'dup.txt');
    final p2 =
        BookSandboxCopier.copySync(second.path, libraryDir.path, 'dup.txt');
    final p3 =
        BookSandboxCopier.copySync(third.path, libraryDir.path, 'dup.txt');

    expect(path.basename(p1), 'dup.txt');
    expect(path.basename(p2), 'dup (1).txt');
    expect(path.basename(p3), 'dup (2).txt');
    expect(File(p1).readAsStringSync(), 'first');
    expect(File(p2).readAsStringSync(), 'second');
    expect(File(p3).readAsStringSync(), 'third');
  });

  test('throws when the source file does not exist', () {
    expect(
      () => BookSandboxCopier.copySync(
          path.join(tempRoot.path, 'missing.txt'), libraryDir.path, 'm.txt'),
      throwsA(isA<FileSystemException>()),
    );
  });
}
