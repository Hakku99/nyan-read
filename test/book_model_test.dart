import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';

void main() {
  test('Book toMap/fromMap preserves timestamp fields', () {
    final book = Book(
      id: 'book-1',
      title: 'Title',
      author: 'Author',
      sourceLocator: '/tmp/a.txt',
      format: 'txt',
      titleSortKey: 'abcd',
      currentProgress: 0.2,
      lastReadAt: 1234,
      addedAt: 5678,
    );

    final map = book.toMap();
    expect(map['last_read_at'], 1234);
    expect(map['added_at'], 5678);
    expect(map['title_sort_key'], 'abcd');

    final roundTrip = Book.fromMap(map);
    expect(roundTrip.lastReadAt, 1234);
    expect(roundTrip.addedAt, 5678);
    expect(roundTrip.titleSortKey, 'abcd');
  });

  test('Book.fromMap lowercases a legacy uppercase format', () {
    final map = Book(
      id: 'book-2',
      title: 'Title',
      author: 'Author',
      sourceLocator: '/tmp/A.PDF',
      format: 'PDF',
    ).toMap();

    expect(Book.fromMap(map).format, 'pdf');
  });

  test('Book.fromMap lowercases a legacy last_position_type', () {
    final map = Book(
      id: 'book-3',
      title: 'Title',
      author: 'Author',
      sourceLocator: '/tmp/a.epub',
      format: 'epub',
      lastPositionType: 'EPUB',
    ).toMap();

    expect(Book.fromMap(map).lastPositionType, 'epub');
    map['last_position_type'] = null;
    expect(Book.fromMap(map).lastPositionType, isNull);
  });

  test('BookSourceType normalizes known values and falls back to filePath',
      () {
    expect(BookSourceType.normalize('file_path'), BookSourceType.filePath);
    expect(BookSourceType.normalize('android_content_uri'),
        BookSourceType.androidContentUri);
    // Library-folder tree children (review #3 / library-folders Phase A) —
    // must survive normalize or every tree book silently degrades to a
    // nonexistent file path.
    expect(BookSourceType.normalize('android_tree_uri'),
        BookSourceType.androidTreeUri);
    expect(BookSourceType.normalize('garbage'), BookSourceType.filePath);
    expect(BookSourceType.normalize(null), BookSourceType.filePath);
  });
}
