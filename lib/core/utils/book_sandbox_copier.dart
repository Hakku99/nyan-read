import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Copies imported book files into the app-owned library directory
/// (`<documents>/books/`) so their lifetime is controlled by the app.
///
/// Only needed on platforms where file_picker returns a path into a
/// *temporary* directory that the OS (or our own cache scavenger) may clear:
/// iOS and macOS. Windows/Linux pickers return the user's real file path, and
/// Android imports go through SAF `content://` URIs — neither needs a copy.
class BookSandboxCopier {
  BookSandboxCopier._();

  static const String libraryDirName = 'books';

  /// True when the current platform requires copying picked files into the
  /// sandbox to keep them alive past the import session.
  static bool get platformNeedsPrivateCopy =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  /// Copies [sourcePath] into `<documents>/books/` and returns the sandbox
  /// path. Keeps the original [fileName] (readable in file browsers /
  /// exports), appending ` (n)` on collision. The byte copy runs in a helper
  /// isolate; only the path_provider lookup stays on the main isolate
  /// (platform channel constraint).
  ///
  /// Throws on I/O failure — callers decide whether to fall back to the
  /// original external path.
  static Future<String> copyIntoLibrary({
    required String sourcePath,
    required String fileName,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final targetDirPath = path.join(docsDir.path, libraryDirName);
    return Isolate.run(
      () => copySync(sourcePath, targetDirPath, fileName),
    );
  }

  @visibleForTesting
  static String copySync(
      String sourcePath, String targetDirPath, String fileName) {
    Directory(targetDirPath).createSync(recursive: true);

    var targetPath = path.join(targetDirPath, fileName);
    if (File(targetPath).existsSync()) {
      final base = path.basenameWithoutExtension(fileName);
      final ext = path.extension(fileName);
      var counter = 1;
      do {
        targetPath = path.join(targetDirPath, '$base ($counter)$ext');
        counter++;
      } while (File(targetPath).existsSync());
    }

    File(sourcePath).copySync(targetPath);
    return targetPath;
  }
}
