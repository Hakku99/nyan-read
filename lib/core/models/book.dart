class Book {
  final String id;
  final String title;
  final String author;
  final String filePath;
  final String format; // 'epub', 'txt', 'pdf'
  final bool isPrivate;
  final int totalPages;
  final double currentProgress;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.format,
    this.isPrivate = false,
    this.totalPages = 0,
    this.currentProgress = 0.0,
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
    );
  }
}
