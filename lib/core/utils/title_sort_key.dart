import 'package:fast_gbk/fast_gbk.dart';

/// Builds a deterministic shelf sort key for mixed CJK/ASCII titles.
///
/// SQLite `COLLATE NOCASE` is ASCII-focused and cannot produce natural Chinese
/// ordering. We derive a GBK-byte hex key so Chinese titles sort closer to
/// pinyin order while still working offline and without platform ICU hooks.
String buildTitleSortKey(String title) {
  final normalized = title.trim().toLowerCase();
  if (normalized.isEmpty) {
    return '';
  }

  try {
    final bytes = gbk.encode(normalized);
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  } catch (_) {
    // Fallback still gives deterministic ordering for unsupported characters.
    return normalized;
  }
}
