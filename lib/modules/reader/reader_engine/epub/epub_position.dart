import '../reader_engine.dart';

class EpubReadingPosition extends ReadingPosition {
  EpubReadingPosition({required String cfi, int? chapterIndex})
      : super(
          cfi: cfi,
          chapterIndex: chapterIndex,
        );

  String get cfi => super.cfi ?? '';

  factory EpubReadingPosition.fromJson(String json) {
    final position = ReadingPosition.fromJson('epub', json);
    return EpubReadingPosition(
      cfi: position.cfi ?? '',
      chapterIndex: position.chapterIndex,
    );
  }
}
