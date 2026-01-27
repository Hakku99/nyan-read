class Bookmark {
  final String id;
  final String bookId;
  final int pageIndex;
  final String note;
  final DateTime createdAt;

  Bookmark({
    required this.id,
    required this.bookId,
    required this.pageIndex,
    this.note = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'page_index': pageIndex,
      'note': note,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'],
      bookId: map['book_id'],
      pageIndex: map['page_index'],
      note: map['note'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }
}
