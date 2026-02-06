import '../../modules/reader/reader_engine/reader_engine.dart';

/// 章节数据模型
class Chapter {
  final String title;
  final ReadingPosition position;
  final int index;
  final bool isRead;

  const Chapter({
    required this.title,
    required this.position,
    required this.index,
    this.isRead = false,
  });

  Chapter copyWith({
    String? title,
    ReadingPosition? position,
    int? index,
    bool? isRead,
  }) {
    return Chapter(
      title: title ?? this.title,
      position: position ?? this.position,
      index: index ?? this.index,
      isRead: isRead ?? this.isRead,
    );
  }
}
