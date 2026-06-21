import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../core/services/feature_manager.dart';
import '../../core/services/riverpod_providers.dart';
import '../../core/services/bookshelf_preferences_service.dart';
import '../../core/models/book.dart';
import '../../core/theme/nyan_radius.dart';
import '../../core/theme/nyan_shadows.dart';
import '../../core/theme/nyan_shelf_ui.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/theme/nyan_typography.dart';
import '../../core/ui/components/components.dart';
import '../../core/ui/nyan_sheet.dart';
import '../../core/ui/nyan_theme_context.dart';
import '../../modules/privacy/privacy_lock_service.dart';
import 'package:go_router/go_router.dart';
import '../settings/settings_page.dart';
import '../ads/ads_ui.dart';
import '../../core/ui/nyan_icons.dart';
import '../../core/utils/book_import_fingerprint.dart';
import '../../core/utils/book_source_platform.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../core/utils/title_sort_key.dart';
import 'widgets/import_book_sheet.dart';
import 'widgets/bookshelf_shelf_toolbar.dart';
import 'widgets/bookshelf_sort_sheet.dart';
import 'widgets/segmented_tab_control.dart';
import 'bookshelf_view_model.dart';
import 'bookshelf_view_model_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _HomeScreenContent();
  }
}

class _HomeScreenContent extends ConsumerStatefulWidget {
  const _HomeScreenContent();

  @override
  ConsumerState<_HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends ConsumerState<_HomeScreenContent>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late final BookshelfPreferencesService _prefs;
  bool _isHeroCollapsed = false;
  bool _adDismissed = false;

  BookshelfViewModel get _vm => ref.read(bookshelfViewModelRpProvider);

  @override
  void initState() {
    super.initState();
    _prefs = ref.read(bookshelfPreferencesRpProvider);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double _shelfScrollBottomPadding(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    if (_vm.isSelectionMode) {
      return safeBottom + NyanShelfUi.scrollBottomSelectionBarClearance;
    }
    return safeBottom + NyanShelfUi.scrollBottomFabClearance;
  }

  /// 3-column grid delegate with dynamically computed aspect ratio.
  ///
  /// The cover follows a 120:156 portrait ratio; text below is fixed height.
  /// Computing from [context] ensures the ratio is correct for every screen width.
  SliverGridDelegateWithFixedCrossAxisCount _bookshelfGridDelegate(
    BuildContext context,
  ) {
    const double crossAxisSpacing = NyanShelfUi.gridCrossAxisSpacing; // 12
    // 16pt each side (now owned by the sliver, not the outer Padding).
    const double gridSideInset = NyanSpacing.space16;

    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double usedWidth =
        2 * gridSideInset +
        2 * crossAxisSpacing; // 2 gaps for 3 columns
    final double cardWidth = (screenWidth - usedWidth) / 3;
    final double coverHeight = cardWidth / NyanShelfUi.gridCoverAspectRatio;
    final double cardHeight =
        coverHeight + NyanShelfUi.gridCardTextSectionHeight;

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      childAspectRatio: cardWidth / cardHeight,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: NyanShelfUi.gridMainAxisSpacing, // 16
    );
  }

  Future<void> _deleteSelectedBooks(BuildContext context) async {
    final vm = _vm;
    if (vm.selectedCount == 0) return;

    final deletedCount = vm.selectedCount;

    // U21 spec: bottom sheet confirm (no deleteFiles toggle).
    final confirmed = await showNyanSheet<bool>(
      context: context,
      builder: (sheetCtx) => _DeleteBooksSheetContent(
        bookCount: deletedCount,
        onDelete: () => Navigator.pop(sheetCtx, true),
        onCancel: () => Navigator.pop(sheetCtx, false),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final loc = AppLocalizations.of(context)!;

    // Show loading toast while deletion is in flight.
    SnackBarUtils.show(
      context,
      loc.deletedBooks(deletedCount),
      tone: NyanSnackTone.loading,
    );

    try {
      // Spec does not include a "delete files" toggle; preserve source files.
      await vm.deleteSelectedBooks(false);
      if (!context.mounted) return;
      SnackBarUtils.show(
        context,
        loc.deletedBooks(deletedCount),
        tone: NyanSnackTone.success,
        actionLabel: loc.undo,
        onActionTap: () => _undoDelete(context),
      );
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.show(
        context,
        'Error deleting books: $e',
        tone: NyanSnackTone.error,
      );
    }
  }

  Future<void> _undoDelete(BuildContext context) async {
    SnackBarUtils.dismiss();
    try {
      await _vm.undoLastDelete();
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.show(
        context,
        'Undo failed: $e',
        tone: NyanSnackTone.error,
      );
    }
  }

  void _showExportNotice(BuildContext context) {
    // Export flow is a stub — show an info toast until the feature is built.
    SnackBarUtils.show(
      context,
      AppLocalizations.of(context)!.exportData,
      tone: NyanSnackTone.info,
    );
  }

  Future<void> _moveSelectedBooks(BuildContext context, bool toPrivate) async {
    final vm = _vm;
    if (vm.selectedCount == 0) return;

    try {
      await vm.moveSelectedBooks(toPrivate);
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.show(
        context,
        'Error moving books: $e',
        tone: NyanSnackTone.error,
      );
    }
  }

  Future<void> _importBook(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: ['epub', 'txt', 'pdf'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }
    if (!context.mounted) return;

    DateTime? loadingShownAt;
    try {
      SnackBarUtils.show(
        context,
        loc.importingBooksTitle,
        description: loc.importingBooksSubtitle,
        tone: NyanSnackTone.loading,
      );
      // Anchor the 600ms floor to show() call time — independent of how long
      // the native picker dismiss animation takes.
      loadingShownAt = DateTime.now();
      // Yield until the overlay has rendered its first frame. Without this,
      // rapid I/O-completion events from the import loop can queue ahead of
      // the vsync callback and delay the card entrance animation — especially
      // noticeable when importing many files.
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;

      final db = ref.read(databaseServiceRpProvider);
      final existingIndex = await BookImportFingerprint.buildExistingIndex(db);

      final featureManager = ref.read(featureManagerRpProvider);
      final isPrivateShelfUnlocked =
          featureManager.isPro && featureManager.isPrivateShelfUnlocked;
      final isPrivate = isPrivateShelfUnlocked && _tabController.index == 1;

      int successCount = 0;
      int skippedCount = 0;
      final knownSignatures = <String>{...existingIndex.signatures};
      final knownLocators = <String>{...existingIndex.normalizedLocators};

      for (final file in result.files) {
        final importSource = await _resolveImportedSource(file);
        if (importSource == null) continue;

        try {
          final fileName = importSource.displayName;
          final addedAt = DateTime.now().millisecondsSinceEpoch;
          final normalizedSourceLocator =
              BookImportFingerprint.normalizeLocator(
            importSource.sourceType,
            importSource.sourceLocator,
          );
          final contentSignature = await BookImportFingerprint.computeForSource(
            sourceType: importSource.sourceType,
            sourceLocator: importSource.sourceLocator,
            locatorHint: importSource.signatureHint,
            transientFilePath: file.path,
          );

          final isDuplicate = knownLocators.contains(normalizedSourceLocator) ||
              (contentSignature != null &&
                  knownSignatures.contains(contentSignature));
          if (isDuplicate) {
            skippedCount++;
            debugPrint('Skipping duplicate import: $fileName');
            continue;
          }

          final book = Book(
            id: const Uuid().v4(),
            title: path.basenameWithoutExtension(fileName),
            author: 'Unknown',
            sourceLocator: importSource.sourceLocator,
            sourceType: importSource.sourceType,
            format: path.extension(fileName).replaceAll('.', ''),
            titleSortKey:
                buildTitleSortKey(path.basenameWithoutExtension(fileName)),
            isPrivate: isPrivate,
            addedAt: addedAt,
            contentSignature: contentSignature,
            storageType: BookStorageType.externalPath,
          );

          await db.insertBook(book.toMap());
          knownLocators.add(normalizedSourceLocator);
          if (contentSignature != null) {
            knownSignatures.add(contentSignature);
          }
          successCount++;
        } catch (e) {
          debugPrint('Error importing file ${file.name}: $e');
        }
      }

      await _cleanupPickerTempFiles();

      if (!context.mounted) return;
      await _awaitMinLoadingDisplay(loadingShownAt);
      if (!context.mounted) return;

      final shelfLabel = isPrivate ? loc.privateShelf : loc.publicShelf;
      if (successCount > 0) {
        SnackBarUtils.show(
          context,
          loc.importedBooks(successCount, shelfLabel),
          tone: NyanSnackTone.success,
        );
      } else if (skippedCount > 0) {
        SnackBarUtils.show(
          context,
          loc.duplicatesSkipped(skippedCount),
          tone: NyanSnackTone.skipped,
        );
      }

      if (successCount > 0) {
        _vm.loadBooks();
      }
    } catch (e) {
      if (context.mounted && loadingShownAt != null) {
        await _awaitMinLoadingDisplay(loadingShownAt);
      }
      if (context.mounted) {
        SnackBarUtils.show(
          context,
          loc.importFailed(e.toString()),
          tone: NyanSnackTone.error,
        );
      }
    }
  }

  /// Waits until [shownAt] is at least 600ms in the past.
  ///
  /// 600ms accounts for: native picker dismiss animation (~300ms on iOS) +
  /// card entrance animation (220ms) + minimum perception window. Since
  /// [shownAt] is anchored to when [SnackBarUtils.show] is called (before the
  /// import work), the floor ensures the loading toast has been visible long
  /// enough for the user to register it before the result toast appears.
  static Future<void> _awaitMinLoadingDisplay(DateTime? shownAt) async {
    if (shownAt == null) return;
    const floor = Duration(milliseconds: 600);
    final remaining = floor - DateTime.now().difference(shownAt);
    if (remaining > Duration.zero) await Future.delayed(remaining);
  }

  Future<_ImportedBookSource?> _resolveImportedSource(PlatformFile file) async {
    final fileName = file.name;
    final identifier = file.identifier;
    final isAndroid = !kIsWeb && Platform.isAndroid;

    if (isAndroid &&
        identifier != null &&
        identifier.isNotEmpty &&
        identifier.startsWith('content://')) {
      final persisted =
          await BookSourcePlatform.persistReadPermission(identifier);
      if (!persisted) {
        debugPrint('Failed to persist read permission for $identifier');
        return null;
      }
      return _ImportedBookSource(
        sourceLocator: identifier,
        sourceType: BookSourceType.androidContentUri,
        displayName: fileName,
        signatureHint: fileName,
      );
    }

    final pickedPath = file.path;
    if (pickedPath != null && pickedPath.isNotEmpty) {
      return _ImportedBookSource(
        sourceLocator: pickedPath,
        sourceType: BookSourceType.filePath,
        displayName: path.basename(pickedPath),
        signatureHint: pickedPath,
      );
    }

    debugPrint('Unable to resolve a stable import source for ${file.name}');
    return null;
  }

  Future<void> _cleanupPickerTempFiles() async {
    final isAndroid = !kIsWeb && Platform.isAndroid;
    if (!isAndroid) return;

    try {
      await FilePicker.platform.clearTemporaryFiles();
    } catch (e) {
      debugPrint('Failed to clear file picker temporary files: $e');
    }
  }

  void _showImportMenu(BuildContext context) {
    final parentContext = context;
    final featureManager = ref.read(featureManagerRpProvider);
    final vm = _vm;
    final showPrivacyTab =
        featureManager.isPro && featureManager.isPrivateShelfUnlocked;
    final isPrivateShelf = showPrivacyTab && _tabController.index == 1;
    final activeBooks = isPrivateShelf ? vm.privateBooks : vm.publicBooks;
    final loc = AppLocalizations.of(context)!;
    final shelfLabel = isPrivateShelf ? loc.privateShelf : loc.publicShelf;

    showNyanSheet(
      context: context,
      builder: (context) {
        return ImportBookSheet(
          isEmptyShelf: activeBooks.isEmpty,
          shelfLabel: shelfLabel,
          onImportFiles: () {
            Navigator.pop(context);
            _importBook(parentContext);
          },
        );
      },
    );
  }

  void _showSortMenu(BuildContext context) async {
    // Two-axis sort sheet (key chips + Ascending/Descending segmented control)
    // that applies live while open, per `BookshelfScreen.jsx`.
    await showBookshelfSortSheet(
      context: context,
      currentSortBy: _prefs.sortBy,
      currentAscending: _prefs.isAscending,
      onChanged: (sortBy, isAscending) async {
        await _prefs.setSort(sortBy, isAscending);
        _vm.loadBooks();
      },
    );
  }

  Future<void> _handlePrivacyLock(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final fm = ref.read(featureManagerRpProvider);
    final privacyService = PrivacyLockService();

    if (fm.isPrivateShelfUnlocked) {
      // Lock it
      fm.lockPrivateShelf();
      SnackBarUtils.show(context, loc.privacyShelfLocked);
      // Force switch back to public tab if we were on private
      _tabController.animateTo(0);
    } else {
      // Unlock flow
      final hasPass = await privacyService.hasPassword();
      if (!mounted) return;

      if (!hasPass) {
        await _showSetPasswordDialog(this.context);
      } else {
        await _showEnterPasswordDialog(this.context);
      }
    }
  }

  void _unlockPrivateShelfAfterRouteSettles() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(featureManagerRpProvider).unlockPrivateShelf();
    });
  }

  Future<void> _showSetPasswordDialog(BuildContext context) async {
    // Full-screen PIN takeover (U16) — set→confirm. PrivacyLockService stores a
    // 4-digit hashed PIN, so the numeric keypad is the canonical entry surface.
    final created = await PrivacyLockService().showPinSetup(context);
    if (created == true && mounted) {
      _unlockPrivateShelfAfterRouteSettles();
    }
  }

  Future<void> _showEnterPasswordDialog(BuildContext context) async {
    final unlocked = await PrivacyLockService().showPinVerify(context);
    if (unlocked == true && mounted) {
      _unlockPrivateShelfAfterRouteSettles();
    }
  }

  Book? _resolveContinueReadingBook(List<Book> books) {
    for (final book in books) {
      if (book.currentProgress > 0 && book.currentProgress < 1) {
        return book;
      }
    }
    if (books.isEmpty) {
      return null;
    }
    return books.first;
  }

  PreferredSizeWidget? _buildSelectionAppBar(
    BuildContext context,
    bool showPrivacyTab,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          final vm = _vm;
          final selectedCount = vm.selectedCount;
          final nyan = context.nyanTheme;
          final theme = Theme.of(context);

          return AppBar(
            leadingWidth: NyanSpacing.minTapTarget + NyanSpacing.space12,
            leading: Padding(
              padding: const EdgeInsets.only(left: NyanSpacing.space8),
              child: SizedBox(
                width: NyanSpacing.minTapTarget,
                height: NyanSpacing.minTapTarget,
                child: IconButton(
                  icon: Icon(NyanIcons.close, size: NyanSpacing.space20),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => vm.toggleSelectionMode(active: false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: NyanSpacing.minTapTarget,
                    minHeight: NyanSpacing.minTapTarget,
                  ),
                ),
              ),
            ),
            // Title: 18pt w600 per spec SelectionHeader.
            title: Text(
              '$selectedCount ${AppLocalizations.of(context)!.selected}',
              style: TextStyle(
                fontFamily: NyanTypography.uiFontFamily,
                fontSize: NyanTypography.selectionHeaderTitle,
                fontWeight: FontWeight.w600,
                height: 1.15,
                letterSpacing: -0.2,
                color: nyan.textPrimary,
              ),
            ),
            centerTitle: false,
            titleSpacing: NyanSpacing.space4,
            // Trailing: "Select all" pill button per spec SelectionHeader.
            actions: [
              Builder(
                builder: (ctx) {
                  final loc = AppLocalizations.of(ctx)!;
                  final isPrivateTab =
                      showPrivacyTab && _tabController.index == 1;
                  final currentTotal =
                      isPrivateTab ? vm.privateCount : vm.publicCount;
                  final allSelected =
                      currentTotal > 0 && selectedCount >= currentTotal;

                  return Padding(
                    padding: const EdgeInsets.only(right: NyanSpacing.space8),
                    child: GestureDetector(
                      onTap: () => vm.selectAll(isPrivateTab),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(
                            horizontal: NyanSpacing.space12),
                        decoration: BoxDecoration(
                          color: nyan.primary.withValues(alpha: 0.10),
                          borderRadius:
                              BorderRadius.circular(NyanRadius.chip),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              allSelected
                                  ? NyanIcons.deselect
                                  : NyanIcons.listChecks,
                              size: 16,
                              color: nyan.primaryDeep,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              allSelected ? loc.deselectAll : loc.selectAll,
                              style: TextStyle(
                                fontFamily: NyanTypography.uiFontFamily,
                                fontSize: NyanTypography.meta,
                                fontWeight: FontWeight.w600,
                                height: 1.0,
                                color: nyan.primaryDeep,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: theme.colorScheme.surface.withValues(alpha: 0),
            elevation: 0,
            scrolledUnderElevation: 0,
          );
        },
      ),
    );
  }

  Widget _buildContinueReadingSection(
    BuildContext context,
    Book continueReadingBook,
    bool isCompact,
  ) {
    final loc = AppLocalizations.of(context)!;
    final progressPercent =
        (continueReadingBook.currentProgress.clamp(0.0, 1.0) * 100)
            .toStringAsFixed(0);
    final progress = continueReadingBook.currentProgress.clamp(0.0, 1.0);

    return NyanContinueReadingCard(
      book: continueReadingBook,
      compact: isCompact,
      collapsed: _isHeroCollapsed,
      onToggleCollapse: () {
        setState(() {
          _isHeroCollapsed = !_isHeroCollapsed;
        });
      },
      progressLabel: '${loc.readingProgress}  $progressPercent%',
      buttonLabel: progress <= 0 ? loc.startReading : loc.continueReading,
      onContinue: () {
        context.push('/reader/${continueReadingBook.id}').then((_) {
          if (mounted) {
            _vm.loadBooks();
          }
        });
      },
    );
  }

  Widget _buildLibrarySurface(
    BuildContext context, {
    required FeatureManager featureManager,
    required bool showPrivacyTab,
    required List<Book> activeBooks,
    required bool showHeaderSections,
    required bool isSelectionMode,
  }) {
    final loc = AppLocalizations.of(context)!;
    final continueReadingBook = _resolveContinueReadingBook(activeBooks);
    final selectedTabIndex = showPrivacyTab ? _tabController.index : 0;
    const useCompactContinueReading = false;

    return CustomScrollView(
      slivers: [
        // Spec `ShelfToolbar` (_chrome.jsx): gear (left) · spacer · search+sort+view+lock (right).
        // Pinned so it never scrolls away — both toolbar and tab strip stay fixed.
        if (showHeaderSections)
          SliverPersistentHeader(
            pinned: true,
            delegate: _ShelfToolbarDelegate(
              isGridView: _prefs.viewMode == ViewMode.grid,
              isSortActive: _prefs.sortBy != SortBy.recency || _prefs.isAscending,
              isPro: featureManager.isPro,
              isPrivacyUnlocked: featureManager.isPrivateShelfUnlocked,
              sortTooltip: loc.sortBy,
              listViewTooltip: loc.listView,
              gridViewTooltip: loc.gridView,
              lockTooltip: featureManager.isPrivateShelfUnlocked
                  ? loc.lockPrivacyShelf
                  : loc.unlockPrivacyShelf,
              settingsTooltip: loc.settingsTitle,
              onSearch: () {}, // search not yet implemented
              onSort: () => _showSortMenu(context),
              onToggleView: () async {
                final isGrid = _prefs.viewMode == ViewMode.grid;
                await _prefs.setViewMode(
                  isGrid ? ViewMode.list : ViewMode.grid,
                );
                setState(() {});
              },
              onPrivacyLock: () => _handlePrivacyLock(context),
              onSettings: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ).then((_) => setState(() {})),
            ),
          ),
        // Pinned shelf switcher sits directly under the title, above the
        // continue-reading hero (BookshelfScreen.jsx: tabs are pinned chrome,
        // the hero scrolls beneath them).
        SliverPersistentHeader(
          pinned: true,
          delegate: BookshelfShelfPinnedHeaderDelegate(
            extent: kBookshelfShelfToolbarPinnedExtent,
            child: BookshelfShelfToolbar(
              tabs: [
                SegmentedTab(label: loc.publicShelf),
                if (showPrivacyTab) SegmentedTab(label: loc.privateShelf),
              ],
              selectedIndex: selectedTabIndex,
              onTabChanged: (index) {
                _tabController.animateTo(index);
                setState(() {});
              },
            ),
          ),
        ),
        if (showHeaderSections && continueReadingBook != null)
          SliverToBoxAdapter(
            child: Padding(
              // 16pt side inset matches the grid / hero rhythm. No vertical pad:
              // the pinned tabs supply the gap above and the grid's own top pad
              // supplies the gap below (avoids a doubled 32pt gulf).
              padding: const EdgeInsets.symmetric(
                horizontal: NyanSpacing.space16,
              ),
              child: _buildContinueReadingSection(
                context,
                continueReadingBook,
                useCompactContinueReading,
              ),
            ),
          ),
        ..._buildShelfSlivers(
          context,
          activeBooks,
          showPrivacyTab && _tabController.index == 1,
          adsEnabled: featureManager.adsEnabled,
          isSelectionMode: isSelectionMode,
          isProUser: featureManager.isPro,
          forceProNudge: featureManager.forceProNudge,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(bookshelfViewModelRpProvider);
    final featureManager = ref.read(featureManagerRpProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([featureManager, vm]),
      builder: (context, _) {
        final isSelectionMode = vm.isSelectionMode;

        // Logic: Only show Privacy Tab if Pro AND Unlocked
        final showPrivacyTab =
            featureManager.isPro && featureManager.isPrivateShelfUnlocked;
        final selectedTabIndex = showPrivacyTab ? _tabController.index : 0;

        final isOnPrivateTab = showPrivacyTab && _tabController.index == 1;

        return Scaffold(
          appBar: isSelectionMode
              ? _buildSelectionAppBar(context, showPrivacyTab)
              : null,
          body: Stack(
            children: [
              SafeArea(
                child: Padding(
                  // No horizontal padding: pinned toolbar + tab-strip must be
                  // full-viewport-width (spec: background goes edge-to-edge).
                  // Each component manages its own 16pt inset internally.
                  padding: EdgeInsets.zero,
                  child: vm.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildLibrarySurface(
                          context,
                          featureManager: featureManager,
                          showPrivacyTab: showPrivacyTab,
                          activeBooks: showPrivacyTab && selectedTabIndex == 1
                              ? vm.privateBooks
                              : vm.publicBooks,
                          showHeaderSections: !isSelectionMode,
                          isSelectionMode: isSelectionMode,
                        ),
                ),
              ),
              if (isSelectionMode)
                Positioned(
                  left: NyanSpacing.space12,
                  right: NyanSpacing.space12,
                  bottom:
                      NyanSpacing.space12 + MediaQuery.viewPaddingOf(context).bottom,
                  child: _SelectActionBar(
                    isOnPrivateTab: isOnPrivateTab,
                    showMakePrivate: featureManager.isPro,
                    onMakePrivate: () =>
                        _moveSelectedBooks(context, !isOnPrivateTab),
                    onExport: () => _showExportNotice(context),
                    onDelete: () => _deleteSelectedBooks(context),
                  ),
                ),
            ],
          ),
          floatingActionButton: isSelectionMode
              ? null
              : Builder(
                  builder: (context) {
                    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
                    return Padding(
                      padding: EdgeInsets.only(
                        right: NyanSpacing.space4,
                        bottom: NyanSpacing.space8 + safeBottom,
                      ),
                      child: NyanFAB(
                        onPressed: () => _showImportMenu(context),
                        icon: NyanIcons.add,
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  List<Widget> _buildShelfSlivers(
    BuildContext context,
    List<Book> books,
    bool isPrivate, {
    required bool adsEnabled,
    required bool isSelectionMode,
    required bool isProUser,
    required bool forceProNudge,
  }) {
    if (books.isEmpty) {
      AdsUI.hide();
      final loc = AppLocalizations.of(context)!;

      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: NyanShelfUi.scrollBottomFabClearance,
            ),
            child: Center(
              child: NyanEmptyState(
                iconData: NyanIcons.books,
                title: isPrivate
                    ? loc.emptyShelfMessage
                    : loc.emptyShelfTitle,
                description: isPrivate
                    ? loc.emptyPrivateShelf
                    : loc.emptyShelfSubtitle,
              ),
            ),
          ),
        ),
      ];
    }

    final showInlineAd = !forceProNudge &&
        !_adDismissed &&
        AdsUI.shouldShowBookshelfInlineAd(
          adsEnabled: adsEnabled,
          isPrivateShelf: isPrivate,
          isSelectionMode: isSelectionMode,
          isProUser: isProUser,
          bookCount: books.length,
        );

    final showProNudge = AdsUI.shouldShowProNudge(
      adsEnabled: adsEnabled,
      isPrivateShelf: isPrivate,
      isSelectionMode: isSelectionMode,
      isProUser: isProUser,
      bookCount: books.length,
      forceProNudge: forceProNudge,
    );

    return _prefs.viewMode == ViewMode.grid
        ? _buildGridSlivers(context, books,
            showInlineAd: showInlineAd, showProNudge: showProNudge)
        : _buildListSlivers(context, books,
            showInlineAd: showInlineAd, showProNudge: showProNudge);
  }

  List<Widget> _buildGridSlivers(
    BuildContext context,
    List<Book> books, {
    required bool showInlineAd,
    required bool showProNudge,
  }) {
    final topPad = NyanShelfUi.sectionGapAfterShelfChrome;
    final bottomPad = _shelfScrollBottomPadding(context);
    const double gridSideInset = NyanSpacing.space16;

    final Widget? slotWidget = showInlineAd
        ? AdsUI.buildBookshelfInlineAd(context,
              onDismiss: () => setState(() => _adDismissed = true))
        : showProNudge
            ? AdsUI.buildProNudge(context)
            : null;

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          gridSideInset,
          topPad,
          gridSideInset,
          slotWidget != null ? 0 : bottomPad,
        ),
        sliver: SliverGrid(
          gridDelegate: _bookshelfGridDelegate(context),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildGridBookTile(context, books[index]),
            childCount: books.length,
          ),
        ),
      ),
      if (slotWidget != null)
        SliverToBoxAdapter(
          child: Padding(
            // ponytail: 14pt top gap matches spec marginTop; L/R 16 standard inset
            padding: EdgeInsets.fromLTRB(
                gridSideInset, 14, gridSideInset, bottomPad),
            child: slotWidget,
          ),
        ),
    ];
  }

  Widget _buildGridBookTile(BuildContext context, Book book) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final vm = _vm;
        final isSelectionMode = vm.isSelectionMode;
        final isSelected = vm.isBookSelected(book.id);
        return NyanBookGridCard(
          book: book,
          isSelected: isSelected,
          isSelectionMode: isSelectionMode,
          onTap: () {
            if (isSelectionMode) {
              vm.toggleBookSelection(book.id);
            } else {
              context.push('/reader/${book.id}').then((_) => vm.loadBooks());
            }
          },
          onLongPress: () {
            if (isSelectionMode) {
              vm.toggleBookSelection(book.id);
            } else {
              vm.toggleSelectionMode(active: true, initialBookId: book.id);
            }
          },
        );
      },
    );
  }

  /// Surface / radius / shadow / hairline border for the list-view grouped
  /// panel (bundle3.jsx `BookListRow` group). The border follows the
  /// `--chrome-edge` token: transparent in light, a [NyanTheme.divider] ring in
  /// dark. Painted by [DecoratedSliver] so the inner [SliverList] stays lazy.
  BoxDecoration _listGroupDecoration(BuildContext context) {
    final nyan = context.nyanTheme;
    final isDark = nyan.brightness == Brightness.dark;
    return BoxDecoration(
      color: nyan.surface,
      borderRadius: BorderRadius.circular(NyanRadius.cardNested),
      border: Border.all(
        color: isDark ? nyan.divider : Colors.transparent,
        width: 1,
      ),
      boxShadow: NyanShadows.settingsGrouped(nyan),
    );
  }

  List<Widget> _buildListSlivers(
    BuildContext context,
    List<Book> books, {
    required bool showInlineAd,
    required bool showProNudge,
  }) {
    final topPad = NyanShelfUi.sectionGapAfterShelfChrome;
    final bottomPad = _shelfScrollBottomPadding(context);
    const double listSideInset = NyanSpacing.space16;

    final decoration = _listGroupDecoration(context);
    final lastIndex = books.length - 1;

    final Widget? slotWidget = showInlineAd
        ? AdsUI.buildBookshelfInlineAd(context,
              onDismiss: () => setState(() => _adDismissed = true))
        : showProNudge
            ? AdsUI.buildProNudge(context)
            : null;

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          listSideInset,
          topPad,
          listSideInset,
          slotWidget != null ? 0 : bottomPad,
        ),
        sliver: DecoratedSliver(
          decoration: decoration,
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildListBookTile(
                context,
                books[index],
                showTopDivider: index > 0,
                isFirst: index == 0,
                isLast: index == lastIndex,
              ),
              childCount: books.length,
            ),
          ),
        ),
      ),
      if (slotWidget != null)
        SliverToBoxAdapter(
          child: Padding(
            // ponytail: 14pt top gap matches spec marginTop; L/R 16 standard inset
            padding: EdgeInsets.fromLTRB(
                listSideInset, 14, listSideInset, bottomPad),
            child: slotWidget,
          ),
        ),
    ];
  }

  Widget _buildListBookTile(
    BuildContext context,
    Book book, {
    required bool showTopDivider,
    required bool isFirst,
    required bool isLast,
  }) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final vm = _vm;
        final isSelectionMode = vm.isSelectionMode;
        final isSelected = vm.isBookSelected(book.id);
        return NyanBookCard(
          book: book,
          bookData: book.toMap(),
          isSelected: isSelected,
          isSelectionMode: isSelectionMode,
          showTopDivider: showTopDivider,
          isFirst: isFirst,
          isLast: isLast,
          onTap: () {
            if (isSelectionMode) {
              vm.toggleBookSelection(book.id);
            } else {
              context.push('/reader/${book.id}').then((_) => vm.loadBooks());
            }
          },
          onLongPress: () {
            if (isSelectionMode) {
              vm.toggleBookSelection(book.id);
            } else {
              vm.toggleSelectionMode(active: true, initialBookId: book.id);
            }
          },
          onSelectionToggle: () => vm.toggleBookSelection(book.id),
        );
      },
    );
  }
}

// ── Floating selection action bar ─────────────────────────────────────────────

/// Floating 3-action dock shown at the bottom of the screen in selection mode.
///
/// Layout per bundle3.jsx `SelectActionBar`: surface bg, chrome-edge border,
/// r-dock (24pt), lightCard shadow, 7pt vertical / 6pt horizontal padding.
/// Actions: Make Private | Export | Delete, separated by 0.5px hairlines.
class _SelectActionBar extends StatelessWidget {
  const _SelectActionBar({
    required this.isOnPrivateTab,
    required this.showMakePrivate,
    required this.onMakePrivate,
    required this.onExport,
    required this.onDelete,
  });

  /// True when the active tab is the private shelf (flips the Make Private label
  /// to "Move to Public").
  final bool isOnPrivateTab;

  /// Whether the Make Private / Public action is shown (Pro feature gate).
  final bool showMakePrivate;

  final VoidCallback onMakePrivate;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final isDark = nyan.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;

    Widget action({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool isDanger = false,
    }) {
      // Spec: icon = primaryDeep, label = textSecondary for normal; both error for danger.
      final iconColor = isDanger ? nyan.errorPrimaryTextColor : nyan.primaryDeep;
      final labelColor =
          isDanger ? nyan.errorPrimaryTextColor : nyan.textSecondary;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          // Spec button padding: 8px top/bottom, 4px sides.
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: iconColor),
                // Spec gap: 5px between icon and label.
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: NyanTypography.caption,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                    color: labelColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Spec: divider at 40% opacity — visually recedes behind the actions.
    Widget hairline() => Container(
          width: 0.5,
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: nyan.divider.withValues(alpha: 0.40),
        );

    return Container(
      decoration: BoxDecoration(
        color: nyan.surface,
        borderRadius: BorderRadius.circular(NyanRadius.dock),
        border: Border.all(
          color: isDark ? nyan.divider : Colors.transparent,
          width: 1,
        ),
        boxShadow: NyanShadows.lightCard(nyan),
      ),
      // Spec dock padding: 7px top/bottom, 6px sides.
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
      child: IntrinsicHeight(
        child: Row(
          children: [
            if (showMakePrivate) ...[
              action(
                icon: NyanIcons.lock,
                label: isOnPrivateTab ? loc.moveToPublic : loc.moveToPrivate,
                onTap: onMakePrivate,
              ),
              hairline(),
            ],
            action(
              icon: NyanIcons.exportData,
              label: loc.export,
              onTap: onExport,
            ),
            hairline(),
            action(
              icon: NyanIcons.delete,
              label: loc.delete,
              onTap: onDelete,
              isDanger: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Delete confirm sheet ───────────────────────────────────────────────────────

/// Bottom sheet asking the user to confirm deletion of selected books.
///
/// Per bundle3.jsx `DeleteConfirmSheet`: 56×56 error icon container,
/// 18pt/600 title, 13.5pt/400 body, full-width Delete and Cancel buttons.
class _DeleteBooksSheetContent extends StatelessWidget {
  const _DeleteBooksSheetContent({
    required this.bookCount,
    required this.onDelete,
    required this.onCancel,
  });

  final int bookCount;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final loc = AppLocalizations.of(context)!;
    final isDark = nyan.brightness == Brightness.dark;
    // Matches NyanOnePaperSheet surface logic — highest layer in dark.
    final surface = isDark ? nyan.surfaceRaised : nyan.surface;
    final chromeEdge = isDark ? nyan.divider : Colors.transparent;
    final borderRadius = BorderRadius.circular(NyanRadius.sheet);

    // Spec DeleteConfirmSheet has NO grabber pill — this is a destructive
    // confirmation that must not be accidentally dismissed by swipe. The surface
    // treatment (shadow + clip + border) mirrors NyanOnePaperSheet without the grabber.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: NyanShadows.lightCard(nyan),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: ColoredBox(
          color: surface,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: chromeEdge, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Upper section: icon + title + body ───────────────────
                // Spec: padding 24px top, 20px sides, 18px bottom; all center-aligned.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    NyanSpacing.space20,
                    NyanSpacing.space24,
                    NyanSpacing.space20,
                    18,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 56×56 error icon container — r-cardNested, errorBg, errorPrimary@22% border.
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: nyan.errorBackgroundColor,
                          borderRadius:
                              BorderRadius.circular(NyanRadius.cardNested),
                          border: Border.all(
                            color:
                                nyan.errorPrimaryTextColor.withValues(alpha: 0.22),
                            width: 0.7,
                          ),
                        ),
                        child: Icon(
                          NyanIcons.delete,
                          size: 26,
                          color: nyan.errorPrimaryTextColor,
                        ),
                      ),
                      // Spec: marginBottom 14 between icon and title.
                      const SizedBox(height: 14),
                      // Title: 18pt/600, center-aligned.
                      Text(
                        loc.deleteBooksTitle(bookCount),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: NyanTypography.uiFontFamily,
                          fontSize: NyanTypography.selectionHeaderTitle,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: nyan.textPrimary,
                        ),
                      ),
                      const SizedBox(height: NyanSpacing.space8),
                      // Body: 13.5pt/400/1.5, center-aligned.
                      Text(
                        loc.actionCannotBeUndone,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: NyanTypography.uiFontFamily,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                          color: nyan.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Button section ───────────────────────────────────────
                // Spec: padding 0 top, 16px sides, 16px bottom; gap 10 between buttons.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    NyanSpacing.space16,
                    0,
                    NyanSpacing.space16,
                    NyanSpacing.space16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Delete button — h=50, r-cardNested, errorPrimary bg.
                      // Spec label: "Delete {n} books" with count; font 600 15px.
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: nyan.errorPrimaryTextColor,
                            borderRadius:
                                BorderRadius.circular(NyanRadius.cardNested),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                NyanIcons.delete,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: NyanSpacing.space8),
                              Text(
                                loc.deleteBooksButton(bookCount),
                                style: const TextStyle(
                                  fontFamily: NyanTypography.uiFontFamily,
                                  // Off-ladder 15pt: spec DeleteConfirmSheet button, §4.6.
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.0,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Spec gap: 10px between buttons.
                      const SizedBox(height: 10),
                      // Cancel button — h=50, r-cardNested, surfaceMuted bg, divider border.
                      GestureDetector(
                        onTap: onCancel,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: nyan.surfaceMuted,
                            borderRadius:
                                BorderRadius.circular(NyanRadius.cardNested),
                            border: Border.all(color: nyan.divider, width: 1.0),
                          ),
                          child: Center(
                            child: Text(
                              loc.cancel,
                              style: TextStyle(
                                fontFamily: NyanTypography.uiFontFamily,
                                // Off-ladder 15pt: spec DeleteConfirmSheet button, §4.6.
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.0,
                                color: nyan.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shelf toolbar pinned delegate ─────────────────────────────────────────────

/// Pinned toolbar row above the shelf tab strip.
///
/// Spec `ShelfToolbar` (_chrome.jsx): Settings gear on the left; flex spacer;
/// Search · Sort · View · Lock (Pro only) on the right. Gap between trailing
/// buttons = 6pt; 16pt horizontal padding (spec `"14px 16px 8px"` toolbar padding).
class _ShelfToolbarDelegate extends SliverPersistentHeaderDelegate {
  const _ShelfToolbarDelegate({
    required this.isGridView,
    required this.isSortActive,
    required this.isPro,
    required this.isPrivacyUnlocked,
    required this.sortTooltip,
    required this.listViewTooltip,
    required this.gridViewTooltip,
    required this.lockTooltip,
    required this.settingsTooltip,
    required this.onSearch,
    required this.onSort,
    required this.onToggleView,
    required this.onPrivacyLock,
    required this.onSettings,
  });

  final bool isGridView;
  final bool isSortActive;
  final bool isPro;
  final bool isPrivacyUnlocked;
  final String sortTooltip;
  final String listViewTooltip;
  final String gridViewTooltip;
  final String lockTooltip;
  final String settingsTooltip;
  final VoidCallback onSearch;
  final VoidCallback onSort;
  final VoidCallback onToggleView;
  final VoidCallback onPrivacyLock;
  final VoidCallback onSettings;

  // 14pt top + 44pt buttons + 8pt bottom = 66pt (spec `ShelfToolbar` padding).
  static const double _kHeight = 66;

  @override
  double get minExtent => _kHeight;

  @override
  double get maxExtent => _kHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          NyanSpacing.space16,
          14,
          NyanSpacing.space16,
          8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            NyanSquareActionButton(
              icon: NyanIcons.settings,
              tooltip: settingsTooltip,
              onPressed: onSettings,
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NyanSquareActionButton(
                  icon: NyanIcons.search,
                  tooltip: 'Search',
                  onPressed: onSearch,
                ),
                const SizedBox(width: 6),
                NyanSquareActionButton(
                  icon: NyanIcons.sort,
                  tooltip: sortTooltip,
                  onPressed: onSort,
                ),
                const SizedBox(width: 6),
                NyanSquareActionButton(
                  icon: isGridView ? NyanIcons.viewRows : NyanIcons.viewGrid,
                  tooltip: isGridView ? listViewTooltip : gridViewTooltip,
                  onPressed: onToggleView,
                ),
                if (isPro) ...[
                  const SizedBox(width: 6),
                  NyanSquareActionButton(
                    icon: isPrivacyUnlocked
                        ? NyanIcons.lockOpen
                        : NyanIcons.lock,
                    tooltip: lockTooltip,
                    onPressed: onPrivacyLock,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ShelfToolbarDelegate old) {
    return isGridView != old.isGridView ||
        isSortActive != old.isSortActive ||
        isPro != old.isPro ||
        isPrivacyUnlocked != old.isPrivacyUnlocked;
  }
}

// ── Imported book source ───────────────────────────────────────────────────────

class _ImportedBookSource {
  final String sourceLocator;
  final String sourceType;
  final String displayName;
  final String signatureHint;

  const _ImportedBookSource({
    required this.sourceLocator,
    required this.sourceType,
    required this.displayName,
    required this.signatureHint,
  });
}
