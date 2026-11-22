/// Shelf status-filter derivation (docs/DESIGN_LIBRARY_FOLDERS.md §5.1):
/// reading/unread key off last_read_at — the same signal the sort clause
/// uses for "keep unread books at the end".
/// Also covers the continue-reading hero pick, which keys off the same field.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/core/services/bookshelf_preferences_service.dart';
import 'package:nyan_read/modules/bookshelf/bookshelf_view_model.dart';

Book _book(String id, {int? lastReadAt}) => Book(
      id: id,
      title: id,
      author: 'a',
      sourceLocator: '/tmp/$id.txt',
      format: 'txt',
      lastReadAt: lastReadAt,
    );

void main() {
  final opened = _book('opened', lastReadAt: 123);
  final untouched = _book('untouched');
  final books = [opened, untouched];

  test('all passes the list through untouched', () {
    expect(
        BookshelfViewModel.filterBooksByStatus(books, ShelfStatusFilter.all),
        same(books));
  });

  test('reading keeps only books with a last_read_at', () {
    final result = BookshelfViewModel.filterBooksByStatus(
        books, ShelfStatusFilter.reading);
    expect(result.map((b) => b.id), ['opened']);
  });

  test('unread keeps only never-opened books', () {
    final result = BookshelfViewModel.filterBooksByStatus(
        books, ShelfStatusFilter.unread);
    expect(result.map((b) => b.id), ['untouched']);
  });

  Book b(String id, double progress, int? at) => Book(
        id: id,
        title: id,
        author: 'a',
        sourceLocator: '/tmp/$id.txt',
        format: 'txt',
        currentProgress: progress,
        lastReadAt: at,
      );

  test(
      'continue reading picks the most recent in-progress book, not shelf order',
      () {
    final books = [
      b('alpha', 0.2, 100),
      b('zeta', 0.5, 900),
      b('done', 1, 999)
    ];
    expect(BookshelfViewModel.resolveContinueReadingBook(books)!.id, 'zeta');
  });

  test('continue reading falls back to first book / null', () {
    expect(BookshelfViewModel.resolveContinueReadingBook([b('x', 0, null)])!.id,
        'x');
    expect(BookshelfViewModel.resolveContinueReadingBook([]), isNull);
  });

  test('continue reading: null lastReadAt loses to a real timestamp', () {
    final books = [b('restored', 0.4, null), b('recent', 0.1, 50)];
    expect(BookshelfViewModel.resolveContinueReadingBook(books)!.id, 'recent');
  });

  test('continue reading: ties keep the shelf order', () {
    final books = [b('first', 0.2, 10), b('second', 0.3, 10)];
    expect(BookshelfViewModel.resolveContinueReadingBook(books)!.id, 'first');
  });
}
