import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../core/services/feature_manager.dart';
import '../../core/services/database_service.dart';
import '../../core/services/bookshelf_preferences_service.dart';
import '../../core/services/service_locator.dart';
import '../../core/models/book.dart';
import '../../core/services/mascot_manager.dart';
import '../../core/theme/nyan_radius.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/theme/nyan_typography.dart';
import '../../core/ui/components/components.dart';
import '../../modules/privacy/privacy_lock_service.dart';
import 'package:go_router/go_router.dart';
import '../settings/settings_page.dart';
import '../ads/ads_ui.dart';
import '../../core/utils/book_import_fingerprint.dart';
import '../../core/utils/book_source_platform.dart';
import '../../core/utils/snackbar_utils.dart';
import 'book_details_page.dart';
import 'widgets/import_book_sheet.dart';
import 'widgets/segmented_tab_control.dart';
import 'bookshelf_view_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide the ViewModel at the highest level of this route
    return ChangeNotifierProvider(
      create: (_) => BookshelfViewModel(getIt(), getIt()),
      child: const _HomeScreenContent(),
    );
  }
}

class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent();

  @override
  State<_HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<_HomeScreenContent>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _prefs = getIt<BookshelfPreferencesService>();
  bool _isHeroCollapsed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteSelectedBooks(BuildContext context) async {
    final pageContext = this.context;
    final loc = AppLocalizations.of(pageContext)!;
    final vm = pageContext.read<BookshelfViewModel>();

    if (vm.selectedCount == 0) return;

    final prefs = getIt<BookshelfPreferencesService>();
    bool deleteFile = prefs.deleteFilesOnRemove;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(loc.deleteBooksTitle(vm.selectedCount)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.actionCannotBeUndone),
                  const SizedBox(height: NyanSpacing.space16),
                  CheckboxListTile(
                    title: Text(loc.alsoDeleteLocalFiles),
                    value: deleteFile,
                    onChanged: (value) {
                      setState(() {
                        deleteFile = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(loc.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error),
                  child: Text(loc.delete),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      final deletedCount = vm.selectedCount;
      try {
        await vm.deleteSelectedBooks(deleteFile);
        if (mounted) {
          SnackBarUtils.show(
            pageContext,
            loc.deletedBooks(deletedCount),
            tone: NyanSnackTone.info,
          );
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.show(
            pageContext,
            'Error deleting books: $e',
            tone: NyanSnackTone.error,
          );
        }
      }
    }
  }

  Future<void> _moveSelectedBooks(BuildContext context, bool toPrivate) async {
    final pageContext = this.context;
    final vm = pageContext.read<BookshelfViewModel>();
    if (vm.selectedCount == 0) return;

    try {
      await vm.moveSelectedBooks(toPrivate);
    } catch (e) {
      if (mounted) {
        SnackBarUtils.show(
          pageContext,
          'Error moving books: $e',
          tone: NyanSnackTone.error,
        );
      }
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

    var progressVisible = false;
    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const ImportProgressDialog(),
      );
      progressVisible = true;

      final db = getIt<DatabaseService>();
      final existingIndex = await BookImportFingerprint.buildExistingIndex(db);

      final featureManager = context.read<FeatureManager>();
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
            isPrivate: isPrivate,
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

      if (context.mounted && progressVisible) {
        Navigator.of(context, rootNavigator: true).pop();
        progressVisible = false;
      }

      if (mounted) {
        final shelf = isPrivate ? loc.privateShelf : loc.publicShelf;

        if (successCount > 0 && skippedCount > 0) {
          SnackBarUtils.show(
            context,
            '${loc.importedBooks(successCount, shelf)}. ${loc.duplicatesSkipped(skippedCount)}',
            tone: NyanSnackTone.success,
          );
        } else if (successCount > 0) {
          SnackBarUtils.show(
            context,
            loc.importedBooks(successCount, shelf),
            tone: NyanSnackTone.success,
          );
        } else if (skippedCount > 0) {
          SnackBarUtils.show(
            context,
            loc.allBooksInLibrary(skippedCount),
            tone: NyanSnackTone.info,
          );
        }

        if (successCount > 0) {
          context.read<BookshelfViewModel>().loadBooks();
        }
      }
    } catch (e) {
      if (context.mounted && progressVisible) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        SnackBarUtils.show(
          context,
          loc.importFailed(e.toString()),
          tone: NyanSnackTone.error,
        );
      }
    }
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
      debugPrint('Failed to clear file picker temporary files: ' + e.toString());
    }
  }

  void _showImportMenu(BuildContext context) {
    final parentContext = context;
    final featureManager = context.read<FeatureManager>();
    final vm = context.read<BookshelfViewModel>();
    final showPrivacyTab =
        featureManager.isPro && featureManager.isPrivateShelfUnlocked;
    final isPrivateShelf = showPrivacyTab && _tabController.index == 1;
    final activeBooks = isPrivateShelf ? vm.privateBooks : vm.publicBooks;
    final loc = AppLocalizations.of(context)!;
    final shelfLabel = isPrivateShelf ? loc.privateShelf : loc.publicShelf;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
    final loc = AppLocalizations.of(context)!;
    final sortOptions = [
      (SortBy.recency, false, loc.lastReadDesc),
      (SortBy.recency, true, loc.lastReadAsc),
      (SortBy.importDate, false, loc.addedDesc),
      (SortBy.importDate, true, loc.addedAsc),
      (SortBy.title, true, loc.titleAsc),
      (SortBy.title, false, loc.titleDesc),
    ];

    final selected = await showNyanSelectionSheet<({SortBy sortBy, bool isAscending})>(
      context: context,
      title: loc.sortBy,
      currentValue: (sortBy: _prefs.sortBy, isAscending: _prefs.isAscending),
      options: [
        for (final option in sortOptions)
          NyanSelectionOption(
            value: (sortBy: option.$1, isAscending: option.$2),
            label: option.$3,
          ),
      ],
    );

    if (selected == null) return;

    await _prefs.setSort(selected.sortBy, selected.isAscending);
    if (!context.mounted) return;

    context.read<BookshelfViewModel>().loadBooks();
  }

  Future<void> _handlePrivacyLock(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final fm = context.read<FeatureManager>();
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
        _showSetPasswordDialog(context);
      } else {
        _showEnterPasswordDialog(context);
      }
    }
  }

  // ... (Dialog methods remain largely the same, skipped for brevity in this tool call, see instruction)
  void _showSetPasswordDialog(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final passController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.setPrivacyPassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: passController,
                decoration: InputDecoration(labelText: loc.password),
                obscureText: true),
            TextField(
                controller: confirmController,
                decoration: InputDecoration(labelText: loc.confirmPassword),
                obscureText: true),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(loc.cancel)),
          TextButton(
              onPressed: () async {
                if (passController.text.isNotEmpty &&
                    passController.text == confirmController.text) {
                  await PrivacyLockService().setPassword(passController.text);
                  if (mounted) {
                    Navigator.pop(ctx);
                    _showEnterPasswordDialog(context);
                  }
                } else {
                  SnackBarUtils.show(context, loc.passwordsDoNotMatch);
                }
              },
              child: Text(loc.save)),
        ],
      ),
    );
  }

  void _showEnterPasswordDialog(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.unlockPrivacyShelfTitle),
        content: TextField(
          controller: passController,
          decoration: InputDecoration(labelText: loc.password),
          obscureText: true,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(loc.cancel)),
          TextButton(
              onPressed: () async {
                final isValid = await PrivacyLockService()
                    .verifyPassword(passController.text);
                if (mounted) {
                  Navigator.pop(ctx);
                  if (isValid) {
                    context.read<FeatureManager>().unlockPrivateShelf();
                  } else {
                    SnackBarUtils.show(context, loc.invalidPassword);
                  }
                }
              },
              child: Text(loc.unlock)),
        ],
      ),
    );
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
    FeatureManager featureManager,
    bool showPrivacyTab,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Selector<BookshelfViewModel, int>(
        selector: (_, vm) => vm.selectedCount,
        builder: (context, selectedCount, _) {
          final vm = context.read<BookshelfViewModel>();
          final theme = Theme.of(context);
          final textTheme = theme.textTheme;

          Widget buildToolbarButton({
            required IconData icon,
            required String tooltip,
            required VoidCallback onPressed,
          }) {
            return SizedBox(
              width: NyanSpacing.minTapTarget,
              height: NyanSpacing.minTapTarget,
              child: IconButton(
                icon: Icon(icon, size: NyanSpacing.space20),
                tooltip: tooltip,
                onPressed: onPressed,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: NyanSpacing.minTapTarget,
                  minHeight: NyanSpacing.minTapTarget,
                ),
              ),
            );
          }

          return AppBar(
            leadingWidth: NyanSpacing.minTapTarget + NyanSpacing.space12,
            leading: Padding(
              padding: const EdgeInsets.only(left: NyanSpacing.space8),
              child: buildToolbarButton(
                icon: Icons.close_rounded,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => vm.toggleSelectionMode(active: false),
              ),
            ),
            title: Text(
              '$selectedCount ${AppLocalizations.of(context)!.selected}',
              style: textTheme.bodyLarge?.copyWith(
                fontSize: NyanTypography.body,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
            centerTitle: false,
            titleSpacing: NyanSpacing.space4,
            actions: [
              if (selectedCount == 1)
                buildToolbarButton(
                  icon: Icons.info_outline_rounded,
                  tooltip: AppLocalizations.of(context)!.viewDetails,
                  onPressed: () async {
                    final bookId = vm.selectedBookIds.first;
                    final bookData =
                        await getIt<DatabaseService>().getBookById(bookId);
                    if (bookData != null && mounted) {
                      final book = Book.fromMap(bookData);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookDetailsPage(
                            book: book,
                            bookData: bookData,
                          ),
                        ),
                      );
                    }
                  },
                ),
              if (selectedCount > 0 && featureManager.isPro)
                buildToolbarButton(
                  icon:
                      showPrivacyTab ? Icons.lock_open_rounded : Icons.lock_rounded,
                  tooltip: showPrivacyTab
                      ? AppLocalizations.of(context)!.moveToPublic
                      : AppLocalizations.of(context)!.moveToPrivate,
                  onPressed: () => _moveSelectedBooks(context, !showPrivacyTab),
                ),
              buildToolbarButton(
                icon: Icons.delete_outline_rounded,
                tooltip: AppLocalizations.of(context)!.delete,
                onPressed: () => _deleteSelectedBooks(context),
              ),
              Builder(
                builder: (context) {
                  final loc = AppLocalizations.of(context)!;
                  final isPrivateTab =
                      showPrivacyTab && _tabController.index == 1;
                  final currentTotal =
                      isPrivateTab ? vm.privateCount : vm.publicCount;
                  final allSelected =
                      currentTotal > 0 && selectedCount >= currentTotal;

                  return buildToolbarButton(
                    icon: allSelected ? Icons.deselect : Icons.select_all,
                    tooltip: allSelected ? loc.deselectAll : loc.selectAll,
                    onPressed: () => vm.selectAll(isPrivateTab),
                  );
                },
              ),
              const SizedBox(width: NyanSpacing.space8),
            ],
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            iconTheme: theme.iconTheme.copyWith(
              size: NyanSpacing.space20,
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: NyanSpacing.space20),
        constraints: const BoxConstraints(
          minWidth: NyanSpacing.minTapTarget,
          minHeight: NyanSpacing.minTapTarget,
        ),
        padding: const EdgeInsets.all(NyanSpacing.space12),
      ),
    );
  }

  Widget _buildLibraryActionButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(NyanRadius.input),
        child: Container(
          constraints: const BoxConstraints(
            minWidth: NyanSpacing.minTapTarget,
            minHeight: NyanSpacing.minTapTarget,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(NyanRadius.input),
          ),
          child: Icon(icon, size: NyanSpacing.space20),
        ),
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
      buttonLabel: loc.startReading,
      onContinue: () {
        context.push('/reader/${continueReadingBook.id}').then((_) {
          if (mounted) {
            context.read<BookshelfViewModel>().loadBooks();
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
    final theme = Theme.of(context);
    const useCompactContinueReading = false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeaderSections)
          Theme(
            data: theme.copyWith(
              textTheme: theme.textTheme.copyWith(
                bodySmall: theme.textTheme.bodySmall?.copyWith(
                  fontSize: NyanTypography.meta,
                  height: 1.35,
                  letterSpacing: 0.15,
                ),
              ),
            ),
            child: NyanPageHeader(
              title: loc.appTitle,
              subtitle: loc.enjoyReading,
              actions: [
                _buildHeaderActionButton(
                  tooltip: loc.settingsTitle,
                  icon: Icons.settings_outlined,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ).then((_) => setState(() {})),
                ),
              ],
              padding: const EdgeInsets.fromLTRB(
                NyanSpacing.space4,
                0,
                NyanSpacing.space4,
                NyanSpacing.space12,
              ),
            ),
          ),
        if (showHeaderSections && continueReadingBook != null) ...[
          _buildContinueReadingSection(
            context,
            continueReadingBook,
            useCompactContinueReading,
          ),
          const SizedBox(height: NyanSpacing.space12),
        ],
        NyanInfoCard(
          padding: const EdgeInsets.all(NyanSpacing.space8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedTabControl(
                tabs: [
                  SegmentedTab(label: loc.publicShelf),
                  if (showPrivacyTab)
                    SegmentedTab(
                      label: loc.privateShelf,
                      icon: Icons.lock,
                    ),
                ],
                selectedIndex: _tabController.index,
                onTabChanged: (index) {
                  _tabController.animateTo(index);
                  setState(() {});
                },
              ),
              const SizedBox(height: NyanSpacing.space4),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: NyanSpacing.space8,
                  runSpacing: NyanSpacing.space8,
                  children: [
                    _buildLibraryActionButton(
                      context: context,
                      icon: _prefs.viewMode == ViewMode.grid
                          ? Icons.view_list
                          : Icons.grid_view,
                      tooltip: _prefs.viewMode == ViewMode.grid
                          ? loc.listView
                          : loc.gridView,
                      onPressed: () async {
                        await _prefs.setViewMode(
                          _prefs.viewMode == ViewMode.grid
                              ? ViewMode.list
                              : ViewMode.grid,
                        );
                        setState(() {});
                      },
                    ),
                    _buildLibraryActionButton(
                      context: context,
                      icon: Icons.sort,
                      tooltip: loc.sortBy,
                      onPressed: () => _showSortMenu(context),
                    ),
                    if (featureManager.isPro)
                      _buildLibraryActionButton(
                        context: context,
                        icon: featureManager.isPrivateShelfUnlocked
                            ? Icons.lock_open
                            : Icons.lock,
                        tooltip: featureManager.isPrivateShelfUnlocked
                            ? loc.lockPrivacyShelf
                            : loc.unlockPrivacyShelf,
                        onPressed: () => _handlePrivacyLock(context),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: NyanSpacing.space12),
        Expanded(
          child: _buildShelfContent(
            context,
            activeBooks,
            showPrivacyTab && _tabController.index == 1,
            adsEnabled: featureManager.adsEnabled,
            isSelectionMode: isSelectionMode,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final featureManager = context.watch<FeatureManager>();
    final isSelectionMode =
        context.select<BookshelfViewModel, bool>((vm) => vm.isSelectionMode);

    // Logic: Only show Privacy Tab if Pro AND Unlocked
    final showPrivacyTab =
        featureManager.isPro && featureManager.isPrivateShelfUnlocked;
    final targetTabLength = showPrivacyTab ? 2 : 1;

    // Dispose and recreate if length changes
    if (_tabController.length != targetTabLength) {
      _tabController.dispose();
      _tabController = TabController(length: targetTabLength, vsync: this);
      // If we reduced tabs, we are likely already at 0, but good to ensure
      if (_tabController.index >= targetTabLength) {
        _tabController.index = 0;
      }
    }

    return Scaffold(
      appBar: isSelectionMode
          ? _buildSelectionAppBar(context, featureManager, showPrivacyTab)
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            NyanSpacing.space16,
            NyanSpacing.space12,
            NyanSpacing.space16,
            0,
          ),
          child: Selector<
              BookshelfViewModel,
              ({bool isLoading, List<Book> pub, List<Book> priv})>(
            selector: (_, vm) => (
              isLoading: vm.isLoading,
              pub: vm.publicBooks,
              priv: vm.privateBooks,
            ),
            builder: (context, state, child) {
              if (state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              final activeBooks =
                  showPrivacyTab && _tabController.index == 1
                      ? state.priv
                      : state.pub;

              return _buildLibrarySurface(
                context,
                featureManager: featureManager,
                showPrivacyTab: showPrivacyTab,
                activeBooks: activeBooks,
                showHeaderSections: !isSelectionMode,
                isSelectionMode: isSelectionMode,
              );
            },
          ),
        ),
      ),
      floatingActionButton: isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => _showImportMenu(context),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildShelfContent(
    BuildContext context,
    List<Book> books,
    bool isPrivate, {
    required bool adsEnabled,
    required bool isSelectionMode,
  }) {
    if (books.isEmpty) {
      AdsUI.hide();
      final loc = AppLocalizations.of(context)!;

      return LayoutBuilder(
        builder: (context, constraints) {
          final compactLayout = constraints.maxHeight < 520;

          return Column(
            children: [
              Spacer(flex: compactLayout ? 1 : 2),
              NyanEmptyState(
                padding: const EdgeInsets.symmetric(
                  horizontal: NyanSpacing.space24,
                ),
                iconSpacing: NyanSpacing.space12,
                descriptionSpacing: NyanSpacing.space4,
                textMinHeight: compactLayout ? 112 : 132,
                icon: MascotManager().render(
                  MascotScene.emptyShelf,
                  size: compactLayout ? 112 : 128,
                ),
                title: isPrivate ? loc.emptyShelfMessage : loc.emptyShelfTitle,
                description:
                    isPrivate ? loc.emptyPrivateShelf : loc.emptyShelfSubtitle,
              ),
              Spacer(flex: compactLayout ? 2 : 3),
            ],
          );
        },
      );
    }

    final showInlineAd = AdsUI.shouldShowBookshelfInlineAd(
      adsEnabled: adsEnabled,
      isPrivateShelf: isPrivate,
      isSelectionMode: isSelectionMode,
      bookCount: books.length,
    );

    return _prefs.viewMode == ViewMode.grid
        ? _buildGridView(context, books, showInlineAd: showInlineAd)
        : _buildListView(context, books, showInlineAd: showInlineAd);
  }

  Widget _buildGridView(
    BuildContext context,
    List<Book> books, {
    required bool showInlineAd,
  }) {
    const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      childAspectRatio: 0.75,
      crossAxisSpacing: NyanSpacing.space16,
      mainAxisSpacing: NyanSpacing.space16,
    );

    if (!showInlineAd) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          0,
          NyanSpacing.space8,
          0,
          NyanSpacing.space16,
        ),
        gridDelegate: gridDelegate,
        itemCount: books.length,
        itemBuilder: (context, index) => _buildGridBookTile(context, books[index]),
      );
    }

    final leadingBooks = books.take(AdsUI.bookshelfGridInsertionCount).toList();
    final trailingBooks = books.skip(AdsUI.bookshelfGridInsertionCount).toList();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: NyanSpacing.space8),
          sliver: SliverGrid(
            gridDelegate: gridDelegate,
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildGridBookTile(context, leadingBooks[index]),
              childCount: leadingBooks.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: NyanSpacing.space16),
            child: AdsUI.buildBookshelfInlineAd(
              context,
              density: NyanInlineAdDensity.compact,
            ),
          ),
        ),
        if (trailingBooks.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.only(bottom: NyanSpacing.space16),
            sliver: SliverGrid(
              gridDelegate: gridDelegate,
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildGridBookTile(context, trailingBooks[index]),
                childCount: trailingBooks.length,
              ),
            ),
          )
        else
          const SliverToBoxAdapter(
            child: SizedBox(height: NyanSpacing.space16),
          ),
      ],
    );
  }

  Widget _buildGridBookTile(BuildContext context, Book book) {
    return Selector<BookshelfViewModel, ({bool isSelectionMode, bool isSelected})>(
      selector: (_, vm) => (
        isSelectionMode: vm.isSelectionMode,
        isSelected: vm.isBookSelected(book.id),
      ),
      builder: (context, state, child) {
        final vm = context.read<BookshelfViewModel>();
        return NyanBookGridCard(
          book: book,
          isSelected: state.isSelected,
          isSelectionMode: state.isSelectionMode,
          onTap: () {
            if (state.isSelectionMode) {
              vm.toggleBookSelection(book.id);
            } else {
              context.push('/reader/${book.id}').then((_) => vm.loadBooks());
            }
          },
          onLongPress: () {
            if (state.isSelectionMode) {
              vm.toggleBookSelection(book.id);
            } else {
              vm.toggleSelectionMode(active: true, initialBookId: book.id);
            }
          },
        );
      },
    );
  }

  Widget _buildListView(
    BuildContext context,
    List<Book> books, {
    required bool showInlineAd,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        0,
        NyanSpacing.space4,
        0,
        NyanSpacing.space16,
      ),
      itemCount: books.length + (showInlineAd ? 1 : 0),
      itemBuilder: (context, index) {
        if (showInlineAd && index == AdsUI.bookshelfListInsertionIndex) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: NyanSpacing.space4),
            child: AdsUI.buildBookshelfInlineAd(context),
          );
        }

        final bookIndex = showInlineAd && index > AdsUI.bookshelfListInsertionIndex
            ? index - 1
            : index;
        return _buildListBookTile(context, books[bookIndex]);
      },
    );
  }

  Widget _buildListBookTile(BuildContext context, Book book) {
    return Selector<BookshelfViewModel, ({bool isSelectionMode, bool isSelected})>(
      selector: (_, vm) => (
        isSelectionMode: vm.isSelectionMode,
        isSelected: vm.isBookSelected(book.id),
      ),
      builder: (context, state, child) {
        final vm = context.read<BookshelfViewModel>();
        return NyanBookCard(
          book: book,
          bookData: book.toMap(),
          isSelected: state.isSelected,
          isSelectionMode: state.isSelectionMode,
          onTap: () {
            if (state.isSelectionMode) {
              vm.toggleBookSelection(book.id);
            } else {
              context.push('/reader/${book.id}').then((_) => vm.loadBooks());
            }
          },
          onLongPress: () {
            if (state.isSelectionMode) {
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
