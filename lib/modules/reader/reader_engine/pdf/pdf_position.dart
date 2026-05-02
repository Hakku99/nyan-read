import '../reader_engine.dart';

class PdfReadingPosition extends ReadingPosition {
  PdfReadingPosition({
    required super.pageNumber,
    super.chapterIndex,
  });

  @override
  int get pageNumber => super.pageNumber ?? 1;

  factory PdfReadingPosition.fromJson(String json) {
    final position = ReadingPosition.fromJson('pdf', json);
    return PdfReadingPosition(
      pageNumber: position.pageNumber ?? 1,
      chapterIndex: position.chapterIndex,
    );
  }
}
