// Design token gate: enforce AGENTS.md rule that hex Color literals live only in
// the theme palette files, not in feature/widgets code under lib/.
//
// Run from repo root:
//   dart run tool/check_design_tokens.dart

import 'dart:io';

import 'package:path/path.dart' as p;

/// Matches `Color(0x...)` style constructors (including `const Color(0x...)`).
final RegExp _hexColorLiteral =
    RegExp(r'\bColor\s*\(\s*0x', caseSensitive: false);

const Set<String> _hexLiteralAllowlist = {
  'lib/core/theme/nyan_colors.dart',
  'lib/core/theme/theme_presets.dart',
};

void main(List<String> args) {
  final repoRoot = Directory.current;
  final libDir = Directory(p.join(repoRoot.path, 'lib'));

  if (!libDir.existsSync()) {
    stderr
        .writeln('check_design_tokens: lib/ not found under ${repoRoot.path}');
    exitCode = 2;
    return;
  }

  final violations = <String>[];

  for (final entity in libDir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;

    final relative =
        p.relative(entity.path, from: repoRoot.path).replaceAll(r'\', '/');

    if (_hexLiteralAllowlist.contains(relative)) continue;

    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_hexColorLiteral.hasMatch(line)) {
        violations.add('$relative:${i + 1}: $line.trim()');
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln(
      'check_design_tokens: OK (no Color(0x...) outside allowlist in lib/)',
    );
    return;
  }

  stderr.writeln(
    'check_design_tokens: FAILED — hex Color literals must only appear in:',
  );
  for (final path in _hexLiteralAllowlist) {
    stderr.writeln('  - $path');
  }
  stderr.writeln('Violations:');
  for (final v in violations) {
    stderr.writeln('  $v');
  }
  exitCode = 1;
}
