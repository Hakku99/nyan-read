import '../reader_engine.dart';

class TxtReadingPosition extends ReadingPosition {
  const TxtReadingPosition({
    required super.paragraphIndex,
    super.paragraphLeadingEdge,
    super.paragraphTrailingEdge,
    super.chapterIndex,
    super.textOffset,
    super.textViewportOffset,
    super.layoutIdentity,
    super.anchorVersion,
  });

  @override
  int get paragraphIndex => super.paragraphIndex ?? 0;

  factory TxtReadingPosition.fromJson(String json) {
    return TxtReadingPosition.fromPosition(
        ReadingPosition.fromJson('txt', json));
  }

  factory TxtReadingPosition.fromPosition(ReadingPosition position) {
    return TxtReadingPosition(
      paragraphIndex: position.paragraphIndex ?? 0,
      paragraphLeadingEdge: position.paragraphLeadingEdge,
      paragraphTrailingEdge: position.paragraphTrailingEdge,
      chapterIndex: position.chapterIndex,
      textOffset: position.textOffset,
      textViewportOffset: position.textViewportOffset,
      layoutIdentity: position.layoutIdentity,
      anchorVersion: position.anchorVersion,
    );
  }
}
