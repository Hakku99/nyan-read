import '../reader_engine.dart';

class EpubReadingPosition extends ReadingPosition {
  EpubReadingPosition({
    required super.cfi,
    super.chapterIndex,
    super.paragraphIndex,
  });

  @override
  String get cfi => super.cfi ?? '';

  factory EpubReadingPosition.fromJson(String json) {
    final position = ReadingPosition.fromJson('epub', json);
    return EpubReadingPosition(
      cfi: position.cfi ?? '',
      chapterIndex: position.chapterIndex,
      paragraphIndex: position.paragraphIndex,
    );
  }
}
