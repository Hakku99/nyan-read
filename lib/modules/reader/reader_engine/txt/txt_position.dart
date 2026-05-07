import '../reader_engine.dart';

class TxtReadingPosition extends ReadingPosition {
  TxtReadingPosition({
    required super.paragraphIndex,
    super.paragraphLeadingEdge,
    super.paragraphTrailingEdge,
    super.chapterIndex,
  });

  @override
  int get paragraphIndex => super.paragraphIndex ?? 0;

  factory TxtReadingPosition.fromJson(String json) {
    final position = ReadingPosition.fromJson('txt', json);
    return TxtReadingPosition(
      paragraphIndex: position.paragraphIndex ?? 0,
      paragraphLeadingEdge: position.paragraphLeadingEdge,
      paragraphTrailingEdge: position.paragraphTrailingEdge,
      chapterIndex: position.chapterIndex,
    );
  }
}
