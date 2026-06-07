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
  // --- Phase 2: Hybrid Signature Anchoring fields ---
  final String preContext; // up to 15 chars before selection
  final String postContext; // up to 15 chars after selection
  final int isHealed; // 0 = original, 1 = offset was healed

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
    this.preContext = '',
    this.postContext = '',
    this.isHealed = 0,
  });

  /// Create from database map (backwards-compatible with v4 rows missing anchor fields)
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
      preContext: (map['pre_context'] as String?) ?? '',
      postContext: (map['post_context'] as String?) ?? '',
      isHealed: (map['is_healed'] as int?) ?? 0,
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
      'pre_context': preContext,
      'post_context': postContext,
      'is_healed': isHealed,
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
    String? preContext,
    String? postContext,
    int? isHealed,
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
      preContext: preContext ?? this.preContext,
      postContext: postContext ?? this.postContext,
      isHealed: isHealed ?? this.isHealed,
    );
  }

  @override
  String toString() {
    return 'Highlight(id: $id, paragraphIndex: $paragraphIndex, text: "${selectedText.length > 20 ? selectedText.substring(0, 20) : selectedText}...", color: $colorCode, healed: $isHealed)';
  }
}

/// Predefined highlight colors — values match NyanColors.highlight* tokens.
class HighlightColors {
  static const String yellow = '#F2E58A';
  static const String green = '#A8D18D';
  static const String blue = '#9EC5E8';
  static const String pink = '#E8A0BF';
  static const String orange = '#F2BE7E';

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
