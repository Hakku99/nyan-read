import 'package:shared_preferences/shared_preferences.dart';

enum ViewMode { grid, list }

enum SortBy { recency, importDate, title }

class BookshelfPreferencesService {
  BookshelfPreferencesService();

  SharedPreferences? _prefs;

  // Keys
  static const String _keyViewMode = 'bookshelf_view_mode';
  static const String _keySortBy = 'bookshelf_sort_by';
  static const String _keyIsAscending = 'bookshelf_sort_ascending';
  static const String _keyDeleteFiles = 'bookshelf_delete_files_on_remove';

  // Default values
  ViewMode _viewMode = ViewMode.grid;
  SortBy _sortBy = SortBy.recency;
  bool _isAscending = false; // Default to descending for Recency
  bool _deleteFilesOnRemove = false;

  // Getters
  ViewMode get viewMode => _viewMode;
  SortBy get sortBy => _sortBy;
  bool get isAscending => _isAscending;
  bool get deleteFilesOnRemove => _deleteFilesOnRemove;

  /// Initialize the service and load saved preferences
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    if (_prefs == null) return;

    // Load view mode
    final viewModeIndex = _prefs!.getInt(_keyViewMode);
    if (viewModeIndex != null && viewModeIndex < ViewMode.values.length) {
      _viewMode = ViewMode.values[viewModeIndex];
    }

    // Load sort by
    final sortByIndex = _prefs!.getInt(_keySortBy);
    if (sortByIndex != null && sortByIndex < SortBy.values.length) {
      _sortBy = SortBy.values[sortByIndex];
    }

    // Load sort order
    _isAscending = _prefs!.getBool(_keyIsAscending) ?? false;

    // Load delete files setting
    _deleteFilesOnRemove = _prefs!.getBool(_keyDeleteFiles) ?? false;
  }

  /// Set view mode and persist
  Future<void> setViewMode(ViewMode mode) async {
    _viewMode = mode;
    await _prefs?.setInt(_keyViewMode, mode.index);
  }

  /// Set sort by and persist
  /// If same sort selected, toggles direction.
  /// If new sort selected, resets direction to default (Title->ASC, Others->DESC).
  Future<void> setSortBy(SortBy sortBy) async {
    if (_sortBy == sortBy) {
      _isAscending = !_isAscending;
    } else {
      _sortBy = sortBy;
      // Default direction: Title is ASC, others are DESC
      _isAscending = sortBy == SortBy.title;
    }

    await _prefs?.setInt(_keySortBy, sortBy.index);
    await _prefs?.setBool(_keyIsAscending, _isAscending);
  }

  /// Explicitly set sort direction
  Future<void> setSortDirection(bool ascending) async {
    if (_isAscending != ascending) {
      _isAscending = ascending;
      await _prefs?.setBool(_keyIsAscending, _isAscending);
    }
  }

  /// Set sort by and direction atomically
  Future<void> setSort(SortBy sortBy, bool isAscending) async {
    _sortBy = sortBy;
    _isAscending = isAscending;
    await _prefs?.setInt(_keySortBy, sortBy.index);
    await _prefs?.setBool(_keyIsAscending, isAscending);
  }

  /// Explicitly toggle sort direction
  Future<void> toggleSortDirection() async {
    _isAscending = !_isAscending;
    await _prefs?.setBool(_keyIsAscending, _isAscending);
  }

  /// Set delete files on remove and persist
  Future<void> setDeleteFilesOnRemove(bool value) async {
    _deleteFilesOnRemove = value;
    await _prefs?.setBool(_keyDeleteFiles, value);
  }

  /// Get SQL ORDER BY clause based on current sort preference
  String getOrderByClause() {
    final direction = _isAscending ? 'ASC' : 'DESC';
    switch (_sortBy) {
      case SortBy.recency:
        // Sort by last read time, nulls last (never read books at the end)
        return 'last_read_at $direction';
      case SortBy.importDate:
        return 'added_at $direction';
      case SortBy.title:
        // Case-insensitive alphabetical sorting
        return 'title COLLATE NOCASE $direction';
    }
  }
}
