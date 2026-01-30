import 'dart:convert';
import '../reader_engine.dart';

class TxtReadingPosition implements ReadingPosition {
  final int paragraphIndex;

  TxtReadingPosition({required this.paragraphIndex});

  @override
  String toJson() => jsonEncode({'paragraphIndex': paragraphIndex});

  factory TxtReadingPosition.fromJson(String json) {
    final map = jsonDecode(json);
    return TxtReadingPosition(
      paragraphIndex: map['paragraphIndex'] ?? 0,
    );
  }
}
