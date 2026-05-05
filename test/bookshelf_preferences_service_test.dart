import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/bookshelf_preferences_service.dart';

void main() {
  group('BookshelfPreferencesService.getOrderByClause', () {
    late BookshelfPreferencesService prefs;

    setUp(() {
      prefs = BookshelfPreferencesService();
    });

    test('recency desc uses null-safe deterministic order', () async {
      await prefs.setSort(SortBy.recency, false);
      expect(
        prefs.getOrderByClause(),
        'last_read_at IS NULL ASC, '
        'last_read_at DESC, '
        'added_at IS NULL ASC, '
        'added_at DESC, '
        'id DESC',
      );
    });

    test('recency asc keeps unread books at end', () async {
      await prefs.setSort(SortBy.recency, true);
      expect(
        prefs.getOrderByClause(),
        'last_read_at IS NULL ASC, '
        'last_read_at ASC, '
        'added_at IS NULL ASC, '
        'added_at ASC, '
        'id ASC',
      );
    });

    test('import date desc is deterministic', () async {
      await prefs.setSort(SortBy.importDate, false);
      expect(
        prefs.getOrderByClause(),
        'added_at IS NULL ASC, added_at DESC, id DESC',
      );
    });

    test('import date asc is deterministic', () async {
      await prefs.setSort(SortBy.importDate, true);
      expect(
        prefs.getOrderByClause(),
        'added_at IS NULL ASC, added_at ASC, id ASC',
      );
    });

    test('title asc adds deterministic tie-breakers', () async {
      await prefs.setSort(SortBy.title, true);
      expect(
        prefs.getOrderByClause(),
        'title_sort_key IS NULL ASC, title_sort_key ASC, title COLLATE NOCASE ASC, added_at IS NULL ASC, added_at DESC, id DESC',
      );
    });

    test('title desc adds deterministic tie-breakers', () async {
      await prefs.setSort(SortBy.title, false);
      expect(
        prefs.getOrderByClause(),
        'title_sort_key IS NULL ASC, title_sort_key DESC, title COLLATE NOCASE DESC, added_at IS NULL ASC, added_at DESC, id DESC',
      );
    });
  });
}
