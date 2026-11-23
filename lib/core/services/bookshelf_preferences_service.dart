import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ViewMode { grid, list }

enum SortBy { recency, importDate, title }

/// Shelf reading-status filter (docs/DESIGN_LIBRARY_FOLDERS.md §5.1).
/// `finished` arrives with the Phase C schema (finished_at); until then the
/// derivable states are: reading = last_read_at set, unread = never opened.
enum ShelfStatusFilter { all, reading, unread }

class BookshelfPreferencesService {
  BookshelfPreferencesService();

  SharedPreferences? _prefs;

  // Keys
  static const String _keyViewMode = 'bookshelf_view_mode';
  static const String _keySortBy = 'bookshelf_sort_by';
  static const String _keyIsAscending = 'bookshelf_sort_ascending';
  static const String _keyDeleteFiles = 'bookshelf_delete_files_on_remove';
  static const String _keyRecentSearches = 'bookshelf_recent_searches';
  // Before this purge, private-shelf queries were saved into the shared list
  // and cannot be told apart from public ones; drop the whole list once.
  static const String _keyRecentSearchesPurged =
      'bookshelf_recent_searches_purged_v1';
  // Per-shelf so the private tab's filter doesn't leak onto the public one.
  static const String _keyPublicStatusFilter = 'bookshelf_status_filter_public';
  static const String _keyPrivateStatusFilter =
      'bookshelf_status_filter_private';
  static const String _keyHeroCollapsed = 'bookshelf_hero_collapsed';
  static const String _keyPendingFileDeletions =
      'bookshelf_pending_file_deletions';
  static const String _keyPendingGrantReleases =
      'bookshelf_pending_grant_releases';
  static const int _maxRecentSearches = 5;

  // Default values
  ViewMode _viewMode = ViewMode.grid;
  SortBy _sortBy = SortBy.recency;
  bool _isAscending = false; // Default to descending for Recency
  bool _deleteFilesOnRemove = false;
  List<String> _recentSearches = [];
  ShelfStatusFilter _publicStatusFilter = ShelfStatusFilter.all;
  ShelfStatusFilter _privateStatusFilter = ShelfStatusFilter.all;
  bool _heroCollapsed = false;

  /// Continue-reading hero collapse state — persisted so a user who prefers
  /// the compact card keeps it across restarts.
  bool get heroCollapsed => _heroCollapsed;

  Future<void> setHeroCollapsed(bool value) async {
    _heroCollapsed = value;
    await _prefs?.setBool(_keyHeroCollapsed, value);
  }

  // Getters
  ViewMode get viewMode => _viewMode;
  SortBy get sortBy => _sortBy;
  bool get isAscending => _isAscending;
  bool get deleteFilesOnRemove => _deleteFilesOnRemove;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  /// Source files whose deletion is still inside the undo grace window.
  ///
  /// Persisted (a transient work queue, not user data) so a process kill
  /// within the window cannot orphan the files: the next launch finishes the
  /// job. Empty when nothing is pending.
  List<String> get pendingFileDeletions {
    try {
      return List.unmodifiable(
          _prefs?.getStringList(_keyPendingFileDeletions) ?? const []);
    } catch (e) {
      // Wrong stored type: drop it so it cannot throw on every launch.
      debugPrint('Discarding malformed pending file deletions: $e');
      unawaited(_prefs?.remove(_keyPendingFileDeletions));
      return const [];
    }
  }

  Future<void> setPendingFileDeletions(List<String> locators) async {
    if (locators.isEmpty) {
      await _prefs?.remove(_keyPendingFileDeletions);
    } else {
      await _prefs?.setStringList(_keyPendingFileDeletions, locators);
    }
  }

  /// Persisted `content://` URIs whose SAF grant still has to be handed back
  /// (deleted books whose undo window a killed session never closed).
  List<String> get pendingGrantReleases {
    try {
      return List.unmodifiable(
          _prefs?.getStringList(_keyPendingGrantReleases) ?? const []);
    } catch (e) {
      debugPrint('Discarding malformed pending grant releases: $e');
      unawaited(_prefs?.remove(_keyPendingGrantReleases));
      return const [];
    }
  }

  Future<void> setPendingGrantReleases(List<String> uris) async {
    if (uris.isEmpty) {
      await _prefs?.remove(_keyPendingGrantReleases);
    } else {
      await _prefs?.setStringList(_keyPendingGrantReleases, uris);
    }
  }

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

    // Load recent searches
    if (_prefs!.getBool(_keyRecentSearchesPurged) != true) {
      await _prefs!.remove(_keyRecentSearches);
      await _prefs!.setBool(_keyRecentSearchesPurged, true);
    }
    _recentSearches = _prefs!.getStringList(_keyRecentSearches) ?? [];

    // Load per-shelf status filters
    _publicStatusFilter = _readStatusFilter(_keyPublicStatusFilter);
    _privateStatusFilter = _readStatusFilter(_keyPrivateStatusFilter);

    _heroCollapsed = _prefs!.getBool(_keyHeroCollapsed) ?? false;
  }

  ShelfStatusFilter _readStatusFilter(String key) {
    final index = _prefs?.getInt(key);
    if (index != null && index >= 0 && index < ShelfStatusFilter.values.length) {
      return ShelfStatusFilter.values[index];
    }
    return ShelfStatusFilter.all;
  }

  ShelfStatusFilter statusFilterFor({required bool isPrivate}) =>
      isPrivate ? _privateStatusFilter : _publicStatusFilter;

  Future<void> setStatusFilter({
    required bool isPrivate,
    required ShelfStatusFilter filter,
  }) async {
    if (isPrivate) {
      _privateStatusFilter = filter;
      await _prefs?.setInt(_keyPrivateStatusFilter, filter.index);
    } else {
      _publicStatusFilter = filter;
      await _prefs?.setInt(_keyPublicStatusFilter, filter.index);
    }
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

  /// Prepend [query] to recent searches, dedupe, cap at [_maxRecentSearches].
  Future<void> addRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _recentSearches = [
      trimmed,
      ..._recentSearches.where((s) => s != trimmed),
    ].take(_maxRecentSearches).toList();
    await _prefs?.setStringList(_keyRecentSearches, _recentSearches);
  }

  Future<void> clearRecentSearches() async {
    _recentSearches = [];
    await _prefs?.remove(_keyRecentSearches);
  }

  /// Get SQL ORDER BY clause based on current sort preference
  String getOrderByClause() {
    final direction = _isAscending ? 'ASC' : 'DESC';
    switch (_sortBy) {
      case SortBy.recency:
        // Always keep unread books at the end, regardless of direction.
        final addedDirection = _isAscending ? 'ASC' : 'DESC';
        return 'last_read_at IS NULL ASC, '
            'last_read_at $direction, '
            'added_at IS NULL ASC, '
            'added_at $addedDirection, '
            'id $addedDirection';
      case SortBy.importDate:
        return 'added_at IS NULL ASC, added_at $direction, id $direction';
      case SortBy.title:
        // Case-insensitive alphabetical sorting with deterministic tie-breakers.
        return 'title_sort_key IS NULL ASC, '
            'title_sort_key $direction, '
            'title COLLATE NOCASE $direction, '
            'added_at IS NULL ASC, '
            'added_at DESC, '
            'id DESC';
    }
  }
}
