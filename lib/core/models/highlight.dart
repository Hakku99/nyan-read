/// Represents a text highlight with optional note
class Highlight {
  final String id;
  final String bookId;
  final int paragraphIndex;
  final int startOffset;
  final int endOffset;
  final String selectedText;
  final String colorCode;
  final String? note;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Highlight({
    required this.id,
    required this.bookId,
    required this.paragraphIndex,
    required this.startOffset,
    required this.endOffset,
    required this.selectedText,
    required this.colorCode,
    this.note,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create from database map
  factory Highlight.fromMap(Map<String, dynamic> map) {
    return Highlight(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      paragraphIndex: map['paragraph_index'] as int,
      startOffset: map['start_offset'] as int,
      endOffset: map['end_offset'] as int,
      selectedText: map['selected_text'] as String,
      colorCode: map['color_code'] as String,
      note: map['note'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : null,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'paragraph_index': paragraphIndex,
      'start_offset': startOffset,
      'end_offset': endOffset,
      'selected_text': selectedText,
      'color_code': colorCode,
      'note': note,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

  /// Create a copy with updated fields
  Highlight copyWith({
    String? id,
    String? bookId,
    int? paragraphIndex,
    int? startOffset,
    int? endOffset,
    String? selectedText,
    String? colorCode,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Highlight(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      paragraphIndex: paragraphIndex ?? this.paragraphIndex,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      selectedText: selectedText ?? this.selectedText,
      colorCode: colorCode ?? this.colorCode,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Highlight(id: $id, paragraphIndex: $paragraphIndex, text: "${selectedText.length > 20 ? selectedText.substring(0, 20) : selectedText}...", color: $colorCode)';
  }
}

/// Predefined highlight colors
class HighlightColors {
  static const String yellow = '#FFEB3B';
  static const String green = '#4CAF50';
  static const String blue = '#2196F3';
  static const String pink = '#E91E63';
  static const String orange = '#FF9800';

  static const List<String> all = [yellow, green, blue, pink, orange];

  static String getName(String colorCode) {
    switch (colorCode) {
      case yellow:
        return 'Yellow';
      case green:
        return 'Green';
      case blue:
        return 'Blue';
      case pink:
        return 'Pink';
      case orange:
        return 'Orange';
      default:
        return 'Custom';
    }
  }
}
