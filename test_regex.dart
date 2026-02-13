void main() {
  final chapterPatterns = [
    RegExp(r'^第[零一二三四五六七八九十百千万\d]+[章回节话]', multiLine: false),
    RegExp(r'^Chapter\s+\d+', caseSensitive: false),
    RegExp(r'^\d+[\.，,]\s*\S+',
        multiLine: false), // "1.Title", "1. Title", "1,Title", "1，Title"
    RegExp(r'^\d+\s+\S+', multiLine: false), // "040 Title", "123 Title"
    RegExp(r'^[零一二三四五六七八九十百千万]+、', multiLine: false),
    RegExp(
        r'^第[零一二三四五六七八九十百千万\dIVXLCDMivxlcdm]+卷[：:\s]*第[零一二三四五六七八九十百千万\d]+[章回节话]',
        caseSensitive: false),
    RegExp(r'^.+[：:]\s*第[零一二三四五六七八九十百千万\d]+[章回节话]', multiLine: false),
  ];

  final testCases = [
    "1，xxx",
    "040 yyy",
    "1.Title",
    "1. Title",
    "1, Title",
    "Chapter 1",
    "第1章",
    "第一卷 第1章",
    "Title: 第1话 Title",
    "Not a chapter",
    "123", // Standalone number, should NOT match here (handled separately in code)
  ];

  for (final testCase in testCases) {
    bool isChapter = false;
    for (final pattern in chapterPatterns) {
      if (pattern.hasMatch(testCase)) {
        isChapter = true;
        break;
      }
    }
    print("'$testCase' -> ${isChapter ? 'MATCH' : 'NO MATCH'}");
  }
}
