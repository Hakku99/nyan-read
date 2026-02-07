import 'package:shared_preferences/shared_preferences.dart';

enum ViewMode { grid, list }

enum SortBy { recency, importDate, title }

class BookshelfPreferencesService {
  static final BookshelfPreferencesService _instance =
      BookshelfPreferencesService._internal();
  static BookshelfPreferencesService get instance => _instance;

  BookshelfPreferencesService._internal();

  SharedPreferences? _prefs;

  // Keys
  static const String _keyViewMode = 'bookshelf_view_mode';
  static const String _keySortBy = 'bookshelf_sort_by';
  static const String _keyDeleteFiles = 'bookshelf_delete_files_on_remove';

  // Default values
  ViewMode _viewMode = ViewMode.grid;
  SortBy _sortBy = SortBy.recency;
  bool _deleteFilesOnRemove = false;

  // Getters
  ViewMode get viewMode => _viewMode;
  SortBy get sortBy => _sortBy;
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

    // Load delete files setting
    _deleteFilesOnRemove = _prefs!.getBool(_keyDeleteFiles) ?? false;
  }

  /// Set view mode and persist
  Future<void> setViewMode(ViewMode mode) async {
    _viewMode = mode;
    await _prefs?.setInt(_keyViewMode, mode.index);
  }

  /// Set sort by and persist
  Future<void> setSortBy(SortBy sortBy) async {
    _sortBy = sortBy;
    await _prefs?.setInt(_keySortBy, sortBy.index);
  }

  /// Set delete files on remove and persist
  Future<void> setDeleteFilesOnRemove(bool value) async {
    _deleteFilesOnRemove = value;
    await _prefs?.setBool(_keyDeleteFiles, value);
  }

  /// Get SQL ORDER BY clause based on current sort preference
  String getOrderByClause() {
    switch (_sortBy) {
      case SortBy.recency:
        // Sort by last read time, nulls last (never read books at the end)
        return 'last_read_at DESC';
      case SortBy.importDate:
        return 'added_at DESC';
      case SortBy.title:
        // Case-insensitive alphabetical sorting
        return 'title COLLATE NOCASE ASC';
    }
  }

  /// Get human-readable label for sort option
  String getSortByLabel(SortBy sortBy) {
    switch (sortBy) {
      case SortBy.recency:
        return '最近阅读';
      case SortBy.importDate:
        return '导入日期';
      case SortBy.title:
        return '书名';
    }
  }
}
