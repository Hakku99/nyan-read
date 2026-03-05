import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../core/services/feature_manager.dart';
import '../../core/services/database_service.dart';
import '../../core/services/bookshelf_preferences_service.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/folder_import_service.dart';
import '../../core/models/book.dart';
import '../../core/services/mascot_manager.dart';
import '../../modules/privacy/privacy_lock_service.dart';
import 'package:go_router/go_router.dart';
import '../settings/settings_page.dart';
import '../ads/ads_ui.dart';
import '../../core/utils/snackbar_utils.dart';
import 'book_details_page.dart';
import 'widgets/segmented_tab_control.dart';
import 'widgets/animated_book_card.dart';
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
  // Design system constants
  static const double _radius16 = 16.0;
  static const double _spacing8 = 8.0;
  static const double _spacing12 = 12.0;
  static const double _spacing16 = 16.0;
  static const double _minTouchTarget = 40.0;

  late TabController _tabController;
  final _prefs = getIt<BookshelfPreferencesService>();

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
    final loc = AppLocalizations.of(context)!;
    final vm = context.read<BookshelfViewModel>();

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
                  const SizedBox(height: 16),
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
      try {
        await vm.deleteSelectedBooks(deleteFile);
        if (mounted) {
          SnackBarUtils.show(context, loc.deletedBooks(vm.selectedCount));
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.show(context, 'Error deleting books: $e');
        }
      }
    }
  }

  Future<void> _moveSelectedBooks(BuildContext context, bool toPrivate) async {
    final vm = context.read<BookshelfViewModel>();
    if (vm.selectedCount == 0) return;

    try {
      await vm.moveSelectedBooks(toPrivate);
    } catch (e) {
      if (mounted) {
        SnackBarUtils.show(context, 'Error moving books: $e');
      }
    }
  }

  Future<void> _importBook(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: ['epub', 'txt', 'pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      // Get existing filenames from database to check for duplicates
      final db = getIt<DatabaseService>();
      final existingFilenames = await db.getAllBookFilenames();

      // Determine privacy based on current tab
      // If we are on the second tab (index 1), it's private.
      // But we need to make sure the second tab IS the private shelf.
      final featureManager = context.read<FeatureManager>();
      final isPrivateShelfUnlocked =
          featureManager.isPro && featureManager.isPrivateShelfUnlocked;

      // If private shelf is not visible, we can't be on it.
      // If it is visible, check tab index.
      final isPrivate = isPrivateShelfUnlocked && _tabController.index == 1;

      int successCount = 0;
      int skippedCount = 0;
      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();

      for (final file in result.files) {
        if (file.path != null) {
          try {
            final originalFile = File(file.path!);
            final fileName = path.basename(originalFile.path);

            // Check if file with this name already exists in the database
            if (existingFilenames.contains(fileName)) {
              skippedCount++;
              debugPrint("Skipping duplicate file: $fileName");

              // Clean Copy: Even if skipped, we MUST destroy the file_picker temp cache
              if (originalFile.existsSync() &&
                  originalFile.path.startsWith(tempDir.path)) {
                try {
                  originalFile.deleteSync();
                } catch (_) {}
              }
              continue;
            }

            final savedFile =
                await originalFile.copy(path.join(appDir.path, fileName));

            // [Clean Copy Pipeline]: Destroy the temporary file_picker cache payload
            if (originalFile.existsSync() &&
                originalFile.path.startsWith(tempDir.path)) {
              try {
                originalFile.deleteSync();
                debugPrint(
                    '--- [Clean Copy] 阅后即焚: 已销毁临时导入副本 ${originalFile.path} ---');
              } catch (e) {
                debugPrint('--- [Clean Copy Error] 销毁临时副本失败: $e ---');
              }
            }

            final book = Book(
              id: const Uuid().v4(),
              title: path.basenameWithoutExtension(fileName),
              author: "Unknown",
              filePath: savedFile.path,
              format: path.extension(fileName).replaceAll('.', ''),
              isPrivate: isPrivate,
            );

            await db.insertBook(book.toMap());
            successCount++;
          } catch (e) {
            debugPrint("Error importing file ${file.name}: $e");
          }
        }
      }

      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        final shelf = isPrivate ? loc.privateShelf : loc.publicShelf;

        // Show appropriate feedback based on results
        if (successCount > 0 && skippedCount > 0) {
          SnackBarUtils.show(
            context,
            '${loc.importedBooks(successCount, shelf)}. ${loc.duplicatesSkipped(skippedCount)}',
          );
        } else if (successCount > 0) {
          SnackBarUtils.show(context, loc.importedBooks(successCount, shelf));
        } else if (skippedCount > 0) {
          SnackBarUtils.show(context, loc.allBooksInLibrary(skippedCount));
        }

        if (successCount > 0) {
          context.read<BookshelfViewModel>().loadBooks();
        }
      }
    }
  }

  void _showImportMenu(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    // Capture the parent context to ensure provider access
    final parentContext = context;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text(loc.importFiles),
                onTap: () {
                  Navigator.pop(context);
                  _importBook(parentContext);
                },
              ),
              if (!Platform.isAndroid)
                ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: Text(loc.importFolder),
                  onTap: () {
                    Navigator.pop(context);
                    _importFolder(parentContext);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showSortMenu(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Text(
                      loc.sortBy,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ...() {
                    // Define the 6 combined sort options
                    final sortOptions = [
                      (SortBy.recency, false, loc.lastReadDesc),
                      (SortBy.recency, true, loc.lastReadAsc),
                      (SortBy.importDate, false, loc.addedDesc),
                      (SortBy.importDate, true, loc.addedAsc),
                      (SortBy.title, true, loc.titleAsc),
                      (SortBy.title, false, loc.titleDesc),
                    ];

                    return sortOptions.map((option) {
                      final sortBy = option.$1;
                      final isAscending = option.$2;
                      final label = option.$3;
                      final isSelected = _prefs.sortBy == sortBy &&
                          _prefs.isAscending == isAscending;

                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        title: Text(
                          label,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              )
                            : null,
                        onTap: () async {
                          await _prefs.setSort(sortBy, isAscending);
                          if (context.mounted) {
                            context.read<BookshelfViewModel>().loadBooks();
                          }
                          setModalState(() {});
                          Navigator.pop(context);
                        },
                      );
                    }).toList();
                  }(),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _importFolder(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.getDirectoryPath();

    if (result != null) {
      try {
        final importService = FolderImportService.instance;

        // Show initial loading snackbar
        if (mounted) {
          SnackBarUtils.show(context, 'Starting background scan...');
        }

        // Get existing filenames first to pass to the Isolate
        final db = getIt<DatabaseService>();
        final existingFilenames = await db.getAllBookFilenames();

        // Scan folder using Isolate
        final scanResult = await importService.scanFolderBackground(
          result,
          existingFilenames,
          includeHidden: false,
          onProgress: (progress) {
            // Optional: You can update a ValueNotifier here to show live progress
            debugPrint(
                'Background Scan Progress: Scanned: ${progress.totalScanned}, Found New: ${progress.validFound}');
          },
        );

        if (scanResult.filePaths.isEmpty) {
          if (mounted) {
            // Check for errors first
            if (scanResult.errors.isNotEmpty) {
              final errorMsg = scanResult.errors.first;
              SnackBarUtils.show(context, errorMsg);
              return;
            }

            // On Android, if we successfully got permission but still found 0 files,
            // it's likely due to Scoped Storage limitations
            if (Platform.isAndroid && scanResult.totalScanned == 0) {
              SnackBarUtils.show(
                context,
                'Folder import is limited on Android 10+. Please use "Import Files" to select multiple books at once.',
              );
              return;
            }

            final skippedExts = scanResult.skippedExtensions.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            final topSkipped = skippedExts.take(3).map((e) => e.key).join(', ');

            String msg = loc.noSupportedBooksFound;
            if (scanResult.totalScanned > 0) {
              msg += ' ${loc.scannedFiles(scanResult.totalScanned)}';
              if (topSkipped.isNotEmpty)
                msg += ' ${loc.skippedExtensions(topSkipped)}';
            }

            SnackBarUtils.show(context, msg);
          }
          return;
        }

        // Duplicates were already filtered out inside the Isolate!
        final uniqueBooksMap = scanResult.parsedBooks;

        // Execute batch insert into database
        await db.batchInsertBooks(uniqueBooksMap);

        if (mounted) {
          SnackBarUtils.show(
              context, 'Successfully imported ${uniqueBooksMap.length} books!');
          context.read<BookshelfViewModel>().loadBooks();
        }
      } catch (e) {
        if (mounted) {
          final loc = AppLocalizations.of(context)!;
          SnackBarUtils.show(context, loc.errorScanningFolder(e.toString()));
        }
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final featureManager = context.watch<FeatureManager>();

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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Selector<BookshelfViewModel,
            ({bool isSelectionMode, int selectedCount})>(
          selector: (_, vm) => (
            isSelectionMode: vm.isSelectionMode,
            selectedCount: vm.selectedCount,
          ),
          builder: (context, state, _) {
            final vm = context.read<BookshelfViewModel>();
            if (state.isSelectionMode) {
              return AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => vm.toggleSelectionMode(active: false),
                ),
                title: Text(
                    '${state.selectedCount} ${AppLocalizations.of(context)!.selected}'),
                actions: [
                  if (state.selectedCount == 1)
                    IconButton(
                      icon: const Icon(Icons.info_outline),
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
                  if (state.selectedCount > 0) ...[
                    if (featureManager.isPro)
                      IconButton(
                        icon:
                            Icon(showPrivacyTab ? Icons.lock_open : Icons.lock),
                        tooltip: showPrivacyTab
                            ? AppLocalizations.of(context)!.moveToPublic
                            : AppLocalizations.of(context)!.moveToPrivate,
                        onPressed: () =>
                            _moveSelectedBooks(context, !showPrivacyTab),
                      ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: AppLocalizations.of(context)!.delete,
                    onPressed: () => _deleteSelectedBooks(context),
                  ),
                  Builder(builder: (context) {
                    final loc = AppLocalizations.of(context)!;
                    final isPrivateTab =
                        showPrivacyTab && _tabController.index == 1;
                    final currentTotal =
                        isPrivateTab ? vm.privateCount : vm.publicCount;
                    final allSelected =
                        currentTotal > 0 && state.selectedCount >= currentTotal;

                    return IconButton(
                      icon:
                          Icon(allSelected ? Icons.deselect : Icons.select_all),
                      tooltip: allSelected ? loc.deselectAll : loc.selectAll,
                      onPressed: () => vm.selectAll(isPrivateTab),
                    );
                  }),
                  const SizedBox(width: _spacing8),
                ],
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              );
            }

            return AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context)!.appTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context)!.enjoyReading,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              centerTitle: false,
              actions: [
                // Grouped action container
                Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: _spacing8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(_radius16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // View Mode Toggle
                      IconButton(
                        icon: Icon(_prefs.viewMode == ViewMode.grid
                            ? Icons.view_list
                            : Icons.grid_view),
                        iconSize: 20,
                        constraints: const BoxConstraints(
                          minWidth: _minTouchTarget,
                          minHeight: _minTouchTarget,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          await _prefs.setViewMode(
                              _prefs.viewMode == ViewMode.grid
                                  ? ViewMode.list
                                  : ViewMode.grid);
                          setState(() {});
                        },
                        tooltip: _prefs.viewMode == ViewMode.grid
                            ? AppLocalizations.of(context)!.listView
                            : AppLocalizations.of(context)!.gridView,
                      ),

                      // Sort Menu
                      IconButton(
                        icon: const Icon(Icons.sort, size: 20),
                        iconSize: 20,
                        tooltip: AppLocalizations.of(context)!.sort,
                        constraints: const BoxConstraints(
                          minWidth: _minTouchTarget,
                          minHeight: _minTouchTarget,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => _showSortMenu(context),
                      ),

                      // Lock/Unlock Button
                      if (featureManager.isPro)
                        IconButton(
                          icon: Icon(
                            featureManager.isPrivateShelfUnlocked
                                ? Icons.lock_open
                                : Icons.lock,
                            size: 20,
                          ),
                          iconSize: 20,
                          constraints: const BoxConstraints(
                            minWidth: _minTouchTarget,
                            minHeight: _minTouchTarget,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () => _handlePrivacyLock(context),
                          tooltip: featureManager.isPrivateShelfUnlocked
                              ? AppLocalizations.of(context)!.lockPrivacyShelf
                              : AppLocalizations.of(context)!
                                  .unlockPrivacyShelf,
                        ),

                      // Settings
                      IconButton(
                        icon: const Icon(Icons.settings, size: 20),
                        iconSize: 20,
                        constraints: const BoxConstraints(
                          minWidth: _minTouchTarget,
                          minHeight: _minTouchTarget,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SettingsPage()))
                            .then((_) => setState(() {})), // Refresh on return
                        tooltip: 'Settings',
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Ads Stub
            if (!featureManager.isPro && featureManager.adsEnabled)
              AdsUI.showBanner(context),

            // Main Content Card
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.only(left: _spacing16, right: _spacing16),
                child: Card(
                  elevation: 0,
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      // Segmented Tab Control
                      Padding(
                        padding: const EdgeInsets.all(_spacing12),
                        child: SegmentedTabControl(
                          tabs: [
                            SegmentedTab(
                              label: AppLocalizations.of(context)!.publicShelf,
                            ),
                            if (showPrivacyTab)
                              SegmentedTab(
                                label:
                                    AppLocalizations.of(context)!.privateShelf,
                                icon: Icons.lock,
                              ),
                          ],
                          selectedIndex: _tabController.index,
                          onTabChanged: (index) {
                            _tabController.animateTo(index);
                            setState(() {}); // Rebuild to update subtitle
                          },
                        ),
                      ),
                      Expanded(
                        child: Selector<
                            BookshelfViewModel,
                            ({
                              bool isLoading,
                              List<Book> pub,
                              List<Book> priv
                            })>(
                          selector: (_, vm) => (
                            isLoading: vm.isLoading,
                            pub: vm.publicBooks,
                            priv: vm.privateBooks,
                          ),
                          builder: (context, state, child) {
                            if (state.isLoading) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            return TabBarView(
                              controller: _tabController,
                              physics:
                                  const NeverScrollableScrollPhysics(), // Use tab bar to switch
                              children: [
                                _buildShelfContent(context, state.pub, false),
                                if (showPrivacyTab)
                                  _buildShelfContent(context, state.priv, true),
                              ],
                            );
                          },
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showImportMenu(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildShelfContent(
      BuildContext context, List<Book> books, bool isPrivate) {
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: MascotManager().render(MascotScene.emptyShelf, size: 120),
            ),
            Text(
              isPrivate
                  ? AppLocalizations.of(context)!.emptyPrivateShelf
                  : AppLocalizations.of(context)!.emptyShelfInstructions,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }

    return _prefs.viewMode == ViewMode.grid
        ? _buildGridView(context, books, isPrivate)
        : _buildListView(context, books, isPrivate);
  }

  Widget _buildGridView(
      BuildContext context, List<Book> books, bool isPrivate) {
    return GridView.builder(
      padding: const EdgeInsets.all(_spacing16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75, // 3:4 ratio
        crossAxisSpacing: _spacing16,
        mainAxisSpacing: _spacing16,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];

        return Selector<BookshelfViewModel,
            ({bool isSelectionMode, bool isSelected})>(
          selector: (_, vm) => (
            isSelectionMode: vm.isSelectionMode,
            isSelected: vm.isBookSelected(book.id),
          ),
          builder: (context, state, child) {
            final vm = context.read<BookshelfViewModel>();
            return AnimatedBookCardGrid(
              book: book,
              isSelected: state.isSelected,
              isSelectionMode: state.isSelectionMode,
              onTap: () {
                if (state.isSelectionMode) {
                  vm.toggleBookSelection(book.id);
                } else {
                  context
                      .push('/reader/${book.id}')
                      .then((_) => vm.loadBooks());
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
      },
    );
  }

  Widget _buildListView(
      BuildContext context, List<Book> books, bool isPrivate) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: _spacing16, vertical: _spacing8),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];

        return Selector<BookshelfViewModel,
            ({bool isSelectionMode, bool isSelected})>(
          selector: (_, vm) => (
            isSelectionMode: vm.isSelectionMode,
            isSelected: vm.isBookSelected(book.id),
          ),
          builder: (context, state, child) {
            final vm = context.read<BookshelfViewModel>();
            return AnimatedBookCardList(
              book: book,
              bookData: book
                  .toMap(), // For compatibility with older list view API if needed
              isSelected: state.isSelected,
              isSelectionMode: state.isSelectionMode,
              onTap: () {
                if (state.isSelectionMode) {
                  vm.toggleBookSelection(book.id);
                } else {
                  context
                      .push('/reader/${book.id}')
                      .then((_) => vm.loadBooks());
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
      },
    );
  }
}
