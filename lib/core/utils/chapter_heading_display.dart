/// Display helpers for web-novel chapter headings.
///
/// Many sources OCR or type 章 as 草. We normalize **display only** so the
/// bottom bar, overlay, and TOC list show the same chapter wording when they
/// refer to the same numbering.
///
/// Fix common typo: `第…草` → `第…章` at the start of a heading (subtitle kept).
String normalizeChapterHeadingForDisplay(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return raw;

  // 第 + Arabic digits + 草
  var m = RegExp(r'^第\s*(\d{1,4})\s*草(\s+.*)?$').firstMatch(t);
  if (m != null) {
    final suffix = m.group(2);
    if (suffix != null && suffix.trim().isNotEmpty) {
      return '第${m.group(1)}章$suffix';
    }
    return '第${m.group(1)}章';
  }

  // 第 + Chinese numerals + 草
  m = RegExp(r'^第\s*([零〇一二三四五六七八九十百千两]{1,8})\s*草(\s+.*)?$')
      .firstMatch(t);
  if (m != null) {
    final suffix = m.group(2);
    if (suffix != null && suffix.trim().isNotEmpty) {
      return '第${m.group(1)}章$suffix';
    }
    return '第${m.group(1)}章';
  }

  return raw;
}

/// Extract a comparable chapter ordinal from a heading line (for TOC dedup).
/// Returns null if the line does not look like a numbered chapter title.
int? extractChapterOrdinalFromHeading(String title) {
  final normalized = title.trim();
  if (normalized.isEmpty) return null;

  final digitMatch =
      RegExp(r'第\s*(\d{1,4})\s*章').firstMatch(normalized);
  if (digitMatch != null) {
    return int.tryParse(digitMatch.group(1)!);
  }
  final digitCao =
      RegExp(r'第\s*(\d{1,4})\s*草').firstMatch(normalized);
  if (digitCao != null) {
    return int.tryParse(digitCao.group(1)!);
  }

  final zhMatch =
      RegExp(r'第\s*([零〇一二三四五六七八九十百千两]{1,8})\s*章')
              .firstMatch(normalized) ??
          RegExp(r'第\s*([零〇一二三四五六七八九十百千两]{1,8})\s*草')
              .firstMatch(normalized);
  if (zhMatch == null) return null;
  return _parseChineseOrdinal(zhMatch.group(1)!);
}

int? _parseChineseOrdinal(String input) {
  final digits = <String, int>{
    '零': 0,
    '〇': 0,
    '一': 1,
    '二': 2,
    '两': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
  };
  int total = 0;
  int current = 0;
  for (final ch in input.split('')) {
    if (digits.containsKey(ch)) {
      current = digits[ch]!;
      continue;
    }
    if (ch == '十') {
      total += (current == 0 ? 1 : current) * 10;
      current = 0;
      continue;
    }
    if (ch == '百') {
      total += (current == 0 ? 1 : current) * 100;
      current = 0;
      continue;
    }
    if (ch == '千') {
      total += (current == 0 ? 1 : current) * 1000;
      current = 0;
      continue;
    }
    return null;
  }
  return total + current;
}

/// True if the title is only "第…章" or "第…草" with no subtitle (merge candidates).
bool isGenericNumericChapterTitle(String title) {
  final t = title.trim();
  if (RegExp(r'^第\s*[\d零〇一二三四五六七八九十百千两]{1,8}\s*章$').hasMatch(t)) {
    return true;
  }
  return RegExp(r'^第\s*[\d零〇一二三四五六七八九十百千两]{1,8}\s*草$').hasMatch(t);
}
