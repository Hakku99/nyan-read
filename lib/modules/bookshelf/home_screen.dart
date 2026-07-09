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
import 'widgets/animated_book_card.dart';
import '../../core/ui/nyan_sheet.dart';
import '../../core/ui/nyan_theme_context.dart';
import 'package:go_router/go_router.dart';
import '../settings/settings_page.dart';
import '../ads/ads_ui.dart';
import '../../core/ui/nyan_icons.dart';
import '../../core/utils/book_import_fingerprint.dart';
import '../../core/utils/book_sandbox_copier.dart';
import '../../core/utils/book_source_platform.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../core/utils/title_sort_key.dart';
import 'book_details_page.dart';
import 'widgets/import_book_sheet.dart';
import 'widgets/bookshelf_shelf_toolbar.dart';
import 'widgets/bookshelf_sort_sheet.dart';
import '../../core/ui/components/segmented_tab_control.dart';
import 'book_search_page.dart';
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
    final books = vm.selectedBooks;

    // U21 spec: bottom sheet confirm with book list + "also delete files" toggle.
    final result = await showNyanSheet<({bool confirmed, bool alsoDeleteFiles})>(
      context: context,
      isDismissible: false,
      builder: (sheetCtx) => _DeleteBooksSheetContent(
        books: books,
        onDelete: (alsoDelete) =>
            Navigator.pop(sheetCtx, (confirmed: true, alsoDeleteFiles: alsoDelete)),
        onCancel: () =>
            Navigator.pop(sheetCtx, (confirmed: false, alsoDeleteFiles: false)),
      ),
    );

    if (result == null || !result.confirmed || !context.mounted) return;

    final loc = AppLocalizations.of(context)!;

    // Show loading toast while deletion is in flight.
    SnackBarUtils.show(
      context,
      loc.deletedBooks(deletedCount),
      tone: NyanSnackTone.loading,
    );

    try {
      await vm.deleteSelectedBooks(result.alsoDeleteFiles);
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
        AppLocalizations.of(context)!.errorDeletingBooks(e.toString()),
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
        AppLocalizations.of(context)!.undoFailed(e.toString()),
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
        AppLocalizations.of(context)!.errorMovingBooks(e.toString()),
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
      // Private shelf is free-tier (2026-07); the only gate is PIN unlock.
      final isPrivateShelfUnlocked = featureManager.isPrivateShelfUnlocked;
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
            storageType: importSource.storageType,
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
      } else {
        // Every file failed or was unresolvable (per-file errors are logged
        // above). Without this branch the loading toast just vanishes with
        // no outcome at all (M3-4).
        SnackBarUtils.show(
          context,
          loc.importNothingSucceeded(result.files.length),
          tone: NyanSnackTone.error,
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
      // iOS/macOS: file_picker hands back a copy inside a *temporary*
      // directory that the OS (or our cache scavenger) may clear — the book
      // would silently die after import. Copy it into the app-owned library
      // so its lifetime is ours. Windows/Linux pickers return the user's
      // real path, which we reference in place.
      if (BookSandboxCopier.platformNeedsPrivateCopy) {
        try {
          final sandboxPath = await BookSandboxCopier.copyIntoLibrary(
            sourcePath: pickedPath,
            fileName: path.basename(pickedPath),
          );
          return _ImportedBookSource(
            sourceLocator: sandboxPath,
            sourceType: BookSourceType.filePath,
            displayName: path.basename(pickedPath),
            signatureHint: sandboxPath,
            storageType: BookStorageType.appPrivateCopy,
          );
        } catch (e) {
          // Fall back to the picked path: the import still succeeds, the
          // book just keeps the legacy at-risk lifetime.
          debugPrint('Sandbox copy failed for $pickedPath, '
              'falling back to external path: $e');
        }
      }
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
    final showPrivacyTab = featureManager.isPrivateShelfUnlocked;
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
    final privacyService = ref.read(privacyLockServiceRpProvider);

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
    final created =
        await ref.read(privacyLockServiceRpProvider).showPinSetup(context);
    if (created == true && mounted) {
      _unlockPrivateShelfAfterRouteSettles();
    }
  }

  Future<void> _showEnterPasswordDialog(BuildContext context) async {
    final unlocked =
        await ref.read(privacyLockServiceRpProvider).showPinVerify(context);
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
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              isGridView: _prefs.viewMode == ViewMode.grid,
              isSortActive: _prefs.sortBy != SortBy.recency || _prefs.isAscending,
              isPrivacyUnlocked: featureManager.isPrivateShelfUnlocked,
              sortTooltip: loc.sortBy,
              listViewTooltip: loc.listView,
              gridViewTooltip: loc.gridView,
              lockTooltip: featureManager.isPrivateShelfUnlocked
                  ? loc.lockPrivacyShelf
                  : loc.unlockPrivacyShelf,
              settingsTooltip: loc.settingsTitle,
              onSearch: () {
                final isPrivate = showPrivacyTab && _tabController.index == 1;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookSearchPage(isPrivate: isPrivate),
                  ),
                );
              },
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

        // Privacy tab shows once unlocked — free-tier feature (2026-07).
        final showPrivacyTab = featureManager.isPrivateShelfUnlocked;
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
                  child: ListenableBuilder(
                    listenable: vm,
                    builder: (context, _) {
                      final singleBook = vm.selectedCount == 1
                          ? vm.publicBooks
                              .followedBy(vm.privateBooks)
                              .where((b) =>
                                  vm.selectedBookIds.contains(b.id))
                              .firstOrNull
                          : null;
                      return _SelectActionBar(
                        isOnPrivateTab: isOnPrivateTab,
                        showMakePrivate: true,
                        selectedCount: vm.selectedCount,
                        onMakePrivate: () =>
                            _moveSelectedBooks(context, !isOnPrivateTab),
                        onExport: () => _showExportNotice(context),
                        onDelete: () => _deleteSelectedBooks(context),
                        onDetails: singleBook != null
                            ? () => _openBookDetails(context, singleBook)
                            : null,
                      );
                    },
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

  void _openBookDetails(BuildContext context, Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookDetailsPage(book: book, bookData: book.toMap()),
      ),
    ).then((_) => _vm.loadBooks());
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
          onOpenDetails: () => _openBookDetails(context, book),
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
        return AnimatedBookCardList(
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
          onOpenDetails: () => _openBookDetails(context, book),
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
    required this.selectedCount,
    required this.onMakePrivate,
    required this.onExport,
    required this.onDelete,
    this.onDetails,
  });

  /// True when the active tab is the private shelf (flips the Make Private label
  /// to "Move to Public").
  final bool isOnPrivateTab;

  /// Whether the Make Private / Public action is shown (Pro feature gate).
  final bool showMakePrivate;

  /// Current selection count — drives the Details button (shown when == 1).
  final int selectedCount;

  final VoidCallback onMakePrivate;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  /// Navigates to the details of the single selected book. Only called when
  /// [selectedCount] == 1 (spec `SelectActionBar`: Details shown for single).
  final VoidCallback? onDetails;

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
            // Details — only when exactly 1 book is selected (spec SelectActionBar).
            if (selectedCount == 1 && onDetails != null) ...[
              action(
                icon: NyanIcons.book,
                label: loc.viewDetails,
                onTap: onDetails!,
              ),
              hairline(),
            ],
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
class _DeleteBooksSheetContent extends StatefulWidget {
  const _DeleteBooksSheetContent({
    required this.books,
    required this.onDelete,
    required this.onCancel,
  });

  final List<Book> books;
  final void Function(bool alsoDeleteFiles) onDelete;
  final VoidCallback onCancel;

  @override
  State<_DeleteBooksSheetContent> createState() =>
      _DeleteBooksSheetContentState();
}

class _DeleteBooksSheetContentState extends State<_DeleteBooksSheetContent> {
  bool _alsoDeleteFiles = false;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final loc = AppLocalizations.of(context)!;
    final isDark = nyan.brightness == Brightness.dark;
    final surface = isDark ? nyan.surfaceRaised : nyan.surface;
    final chromeEdge = isDark ? nyan.divider : Colors.transparent;
    final borderRadius = BorderRadius.circular(NyanRadius.sheet);
    final bookCount = widget.books.length;

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
                // ── Grabber ───────────────────────────────────────────────
                // Spec: paddingTop 10, 40×5 pill, grabber colour.
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: nyan.primary.withValues(
                          alpha: isDark ? 0.50 : 0.36,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),

                // ── Icon + title + body ───────────────────────────────────
                // Spec: padding "18px 24px 4px".
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    NyanSpacing.space24,
                    18,
                    NyanSpacing.space24,
                    4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 48×48 error icon container — r-cardNested, errorBg, errorPrimary@26% border.
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: nyan.errorBackgroundColor,
                          borderRadius:
                              BorderRadius.circular(NyanRadius.cardNested),
                          border: Border.all(
                            color: nyan.errorPrimaryTextColor.withValues(
                                alpha: 0.26),
                            width: 0.7,
                          ),
                        ),
                        child: Icon(
                          NyanIcons.delete,
                          size: 23,
                          color: nyan.errorPrimaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Title: 19pt/600/letterSpacing-0.2.
                      Text(
                        loc.deleteBooksTitle(bookCount),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: NyanTypography.uiFontFamily,
                          fontSize: NyanTypography.deleteConfirmTitle,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          letterSpacing: -0.2,
                          color: nyan.textPrimary,
                        ),
                      ),
                      const SizedBox(height: NyanSpacing.space8),
                      // Body: 13.5pt/400/1.5 — progress + bookmarks only (source file
                      // note moved to the "also delete" checkbox description below).
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 286),
                        child: Text(
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
                      ),
                    ],
                  ),
                ),

                // ── Recessed book list ────────────────────────────────────
                // Spec: padding "16px 16px 0"; surfaceMuted recessed panel.
                if (widget.books.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        NyanSpacing.space16, NyanSpacing.space16, NyanSpacing.space16, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: nyan.surfaceMuted,
                        borderRadius:
                            BorderRadius.circular(NyanRadius.cardNested),
                        border: Border.all(
                          color: nyan.divider.withValues(alpha: 0.50),
                          width: 0.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(NyanRadius.cardNested),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < widget.books.length; i++) ...[
                              if (i > 0)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: NyanSpacing.space12),
                                  child: Container(
                                    height: 0.5,
                                    color: nyan.divider.withValues(alpha: 0.40),
                                  ),
                                ),
                              _BookPreviewRow(book: widget.books[i]),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── "Also delete files" checkbox ──────────────────────────
                // Spec: padding "14px 16px 0"; surfaceMuted row, r-cardNested.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      NyanSpacing.space16, 14, NyanSpacing.space16, 0),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _alsoDeleteFiles = !_alsoDeleteFiles),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: nyan.surfaceMuted,
                        borderRadius:
                            BorderRadius.circular(NyanRadius.cardNested),
                        border: Border.all(
                          color: nyan.divider.withValues(alpha: 0.50),
                          width: 0.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 11),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 22×22 checkbox square — r=7, border 1.5pt.
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _alsoDeleteFiles
                                    ? nyan.errorPrimaryTextColor
                                    : nyan.surface,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: _alsoDeleteFiles
                                      ? nyan.errorPrimaryTextColor
                                      : nyan.textPrimary.withValues(alpha: 0.28),
                                  width: 1.5,
                                ),
                              ),
                              child: _alsoDeleteFiles
                                  ? const Icon(Icons.check,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc.alsoDeleteFilesFromDevice,
                                    style: TextStyle(
                                      fontFamily: NyanTypography.uiFontFamily,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      height: 1.3,
                                      color: nyan.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    loc.alsoDeleteFilesFromDeviceDesc,
                                    style: TextStyle(
                                      fontFamily: NyanTypography.uiFontFamily,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w400,
                                      height: 1.35,
                                      color: nyan.textMuted,
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
                ),

                // ── Buttons ───────────────────────────────────────────────
                // Spec: padding 16px all sides; Cancel + Delete side by side, gap 9.
                Padding(
                  padding: const EdgeInsets.all(NyanSpacing.space16),
                  child: Row(
                    children: [
                      // Cancel — transparent bg, divider@60% border, textSecondary.
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onCancel,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(NyanRadius.cardNested),
                              border: Border.all(
                                color: nyan.divider.withValues(alpha: 0.60),
                                width: 1.0,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                loc.cancel,
                                style: TextStyle(
                                  fontFamily: NyanTypography.uiFontFamily,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.0,
                                  color: nyan.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      // Delete — errorPrimary bg, trash icon + "Delete".
                      Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onDelete(_alsoDeleteFiles),
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
                                Icon(NyanIcons.delete,
                                    size: 17, color: nyan.surface),
                                const SizedBox(width: 7),
                                Text(
                                  loc.deleteButton,
                                  style: TextStyle(
                                    fontFamily: NyanTypography.uiFontFamily,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    height: 1.0,
                                    color: nyan.surface,
                                  ),
                                ),
                              ],
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

// Recessed row inside the delete confirm book list preview.
class _BookPreviewRow extends StatelessWidget {
  const _BookPreviewRow({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final fmt = book.format.toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          // 30×40 cover thumbnail.
          Container(
            width: 30,
            height: 40,
            decoration: BoxDecoration(
              color: Color.lerp(nyan.surface, nyan.primary, 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: nyan.divider.withValues(alpha: 0.36),
                width: 0.5,
              ),
            ),
            child: Icon(NyanIcons.book, size: 15, color: nyan.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                    color: nyan.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                    color: nyan.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Format badge — 17pt tall pill, primaryDeep label 9/600.
          Container(
            height: 17,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: nyan.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: nyan.divider.withValues(alpha: 0.44),
                width: 0.5,
              ),
            ),
            child: Center(
              child: Text(
                fmt,
                style: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  fontSize: NyanTypography.shelfFormatChip,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                  color: nyan.primaryDeep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shelf toolbar pinned delegate ─────────────────────────────────────────────

/// Pinned toolbar row above the shelf tab strip.
///
/// Spec `ShelfToolbar` (_chrome.jsx): Settings gear on the left; flex spacer;
/// Search · Sort · View · Lock on the right (Lock was Pro-only until the
/// private shelf moved to the free tier, 2026-07). Gap between trailing
/// buttons = 6pt; 16pt horizontal padding (spec `"14px 16px 8px"` toolbar padding).
class _ShelfToolbarDelegate extends SliverPersistentHeaderDelegate {
  const _ShelfToolbarDelegate({
    required this.backgroundColor,
    required this.isGridView,
    required this.isSortActive,
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

  final Color backgroundColor;
  final bool isGridView;
  final bool isSortActive;
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
      color: backgroundColor,
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
                const SizedBox(width: 6),
                NyanSquareActionButton(
                  icon: isPrivacyUnlocked
                      ? NyanIcons.lockOpen
                      : NyanIcons.lock,
                  tooltip: lockTooltip,
                  onPressed: onPrivacyLock,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ShelfToolbarDelegate old) {
    return backgroundColor != old.backgroundColor ||
        isGridView != old.isGridView ||
        isSortActive != old.isSortActive ||
        isPrivacyUnlocked != old.isPrivacyUnlocked;
  }
}

// ── Imported book source ───────────────────────────────────────────────────────

class _ImportedBookSource {
  final String sourceLocator;
  final String sourceType;
  final String displayName;
  final String signatureHint;
  final String storageType;

  const _ImportedBookSource({
    required this.sourceLocator,
    required this.sourceType,
    required this.displayName,
    required this.signatureHint,
    this.storageType = BookStorageType.externalPath,
  });
}
