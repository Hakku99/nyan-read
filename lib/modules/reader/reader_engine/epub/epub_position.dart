import 'dart:convert';
import '../reader_engine.dart';

class EpubReadingPosition implements ReadingPosition {
  final String cfi;

  EpubReadingPosition({required this.cfi});

  @override
  String toJson() => jsonEncode({'cfi': cfi});

  factory EpubReadingPosition.fromJson(String json) {
    final map = jsonDecode(json);
    return EpubReadingPosition(cfi: map['cfi']);
  }
}
