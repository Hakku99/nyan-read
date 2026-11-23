/// Pre-fix builds stored private-shelf queries in the shared recent-searches
/// list; the first launch after the fix drops the whole list exactly once.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/bookshelf_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('legacy recent searches are purged once, later ones are kept', () async {
    SharedPreferences.setMockInitialValues({
      'bookshelf_recent_searches': ['secret title'],
    });
    final first = BookshelfPreferencesService();
    await first.initialize();
    expect(first.recentSearches, isEmpty);

    await first.addRecentSearch('public title');
    final second = BookshelfPreferencesService();
    await second.initialize();
    expect(second.recentSearches, ['public title']);
  });
}
