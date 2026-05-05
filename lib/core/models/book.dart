class BookStorageType {
  static const String externalPath = 'external_path';
  static const String appPrivateCopy = 'app_private_copy';

  static const Set<String> _knownValues = {
    externalPath,
    appPrivateCopy,
  };

  static String normalize(String? value) {
    if (value != null && _knownValues.contains(value)) {
      return value;
    }
    return externalPath;
  }
}

class BookSourceType {
  static const String filePath = 'file_path';
  static const String androidContentUri = 'android_content_uri';

  static const Set<String> _knownValues = {
    filePath,
    androidContentUri,
  };

  static String normalize(String? value) {
    if (value != null && _knownValues.contains(value)) {
      return value;
    }
    return filePath;
  }
}

class Book {
  final String id;
  final String title;
  final String author;
  final String sourceLocator;
  final String sourceType;
  final String format; // 'epub', 'txt', 'pdf'
  final String? titleSortKey;
  final bool isPrivate;
  final int totalPages;
  final double currentProgress;
  final String? lastPositionType;
  final String? lastPositionPayload;
  final int? lastReadAt;
  final int? addedAt;
  final String? contentSignature;
  final String storageType;

  Book({
    required this.id,
    required this.title,
    required this.author,
    String? filePath,
    String? sourceLocator,
    this.sourceType = BookSourceType.filePath,
    required this.format,
    this.titleSortKey,
    this.isPrivate = false,
    this.totalPages = 0,
    this.currentProgress = 0.0,
    this.lastPositionType,
    this.lastPositionPayload,
    this.lastReadAt,
    this.addedAt,
    this.contentSignature,
    this.storageType = BookStorageType.externalPath,
  }) : sourceLocator = sourceLocator ?? filePath ?? '';

  String get filePath => sourceLocator;
  bool get isAndroidContentUri =>
      sourceType == BookSourceType.androidContentUri;
  bool get isFilePathSource => sourceType == BookSourceType.filePath;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'file_path': sourceLocator,
      'source_type': sourceType,
      'format': format,
      'title_sort_key': titleSortKey,
      'is_private': isPrivate ? 1 : 0,
      'total_pages': totalPages,
      'current_progress': currentProgress,
      'last_position_type': lastPositionType,
      'last_position_payload': lastPositionPayload,
      'last_read_at': lastReadAt,
      'added_at': addedAt,
      'content_signature': contentSignature,
      'storage_type': storageType,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'],
      author: map['author'] ?? 'Unknown',
      sourceLocator: map['file_path'],
      sourceType: BookSourceType.normalize(map['source_type'] as String?),
      format: map['format'],
      titleSortKey: map['title_sort_key'] as String?,
      isPrivate: map['is_private'] == 1,
      totalPages: map['total_pages'] ?? 0,
      currentProgress: map['current_progress'] ?? 0.0,
      lastPositionType: map['last_position_type'],
      lastPositionPayload: map['last_position_payload'],
      lastReadAt: map['last_read_at'] as int?,
      addedAt: map['added_at'] as int?,
      contentSignature: map['content_signature'],
      storageType: BookStorageType.normalize(map['storage_type'] as String?),
    );
  }
}
