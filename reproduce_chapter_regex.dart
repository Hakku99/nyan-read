// ignore_for_file: avoid_print — CLI scratch script (dart run reproduce_chapter_regex.dart)

void main() {
  final lines = [
    "第1卷：第1章",
    "第一卷：第一章",
    "第一卷第1章",
    "第1卷  第二章",
    "第100章",
    "Chapter 1",
  ];

  final chapterPatterns = [
    RegExp(r'^第[零一二三四五六七八九十百千万\d]+[章回节]', multiLine: false),
    RegExp(r'^Chapter\s+\d+', caseSensitive: false),
    RegExp(r'^\d+\.\s*\S+', multiLine: false),
    RegExp(r'^[零一二三四五六七八九十百千万]+、', multiLine: false),
    // New pattern to be added
    RegExp(r'^第[零一二三四五六七八九十百千万\d]+卷[：:]?\s*第[零一二三四五六七八九十百千万\d]+[章回节]'),
  ];

  for (final line in lines) {
    bool isChapter = false;
    for (final pattern in chapterPatterns) {
      if (pattern.hasMatch(line)) {
        isChapter = true;
        print("Match: '$line' with pattern '${pattern.pattern}'");
        break;
      }
    }
    if (!isChapter) {
      print("No match for: '$line'");
    }
  }
}
