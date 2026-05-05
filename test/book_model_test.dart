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
}
