import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/bookshelf_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('status filter (library-folders Phase B)', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('defaults to all and persists per shelf tab', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = BookshelfPreferencesService();
      await prefs.initialize();

      expect(prefs.statusFilterFor(isPrivate: false), ShelfStatusFilter.all);
      expect(prefs.statusFilterFor(isPrivate: true), ShelfStatusFilter.all);

      await prefs.setStatusFilter(
          isPrivate: false, filter: ShelfStatusFilter.unread);
      await prefs.setStatusFilter(
          isPrivate: true, filter: ShelfStatusFilter.reading);

      // Public and private filters must not leak into each other, and both
      // must survive a service reload (restart simulation).
      final reloaded = BookshelfPreferencesService();
      await reloaded.initialize();
      expect(
          reloaded.statusFilterFor(isPrivate: false), ShelfStatusFilter.unread);
      expect(reloaded.statusFilterFor(isPrivate: true),
          ShelfStatusFilter.reading);
    });
  });
}
