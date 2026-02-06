class Book {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final String format; // 'epub', 'txt', 'pdf'
  final bool isPrivate;
  final int totalPages;
  final double currentProgress;
  final String? lastPositionType;
  final String? lastPositionPayload;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.format,
    this.isPrivate = false,
    this.totalPages = 0,
    this.currentProgress = 0.0,
    this.lastPositionType,
    this.lastPositionPayload,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'file_path': filePath,
      'format': format,
      'is_private': isPrivate ? 1 : 0,
      'total_pages': totalPages,
      'current_progress': currentProgress,
      'last_position_type': lastPositionType,
      'last_position_payload': lastPositionPayload,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'],
      author: map['author'] ?? 'Unknown',
      filePath: map['file_path'],
      format: map['format'],
      isPrivate: map['is_private'] == 1,
      totalPages: map['total_pages'] ?? 0,
      currentProgress: map['current_progress'] ?? 0.0,
      lastPositionType: map['last_position_type'],
      lastPositionPayload: map['last_position_payload'],
    );
  }
}
