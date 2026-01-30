import 'dart:convert';
import '../reader_engine.dart';

class PdfReadingPosition implements ReadingPosition {
  final int pageNumber;

  PdfReadingPosition({required this.pageNumber});

  @override
  String toJson() => jsonEncode({'pageNumber': pageNumber});

  factory PdfReadingPosition.fromJson(String json) {
    final map = jsonDecode(json);
    return PdfReadingPosition(pageNumber: map['pageNumber'] ?? 1);
  }
}
