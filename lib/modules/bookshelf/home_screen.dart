import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/feature_manager.dart';
import '../../core/services/database_service.dart';
import '../../core/services/bookshelf_preferences_service.dart';
import '../../core/services/folder_import_service.dart';
import '../../core/models/book.dart';
import '../../core/services/mascot_manager.dart';
import '../../modules/privacy/privacy_lock_service.dart';
import '../reader/reader_page.dart';
import '../settings/settings_page.dart';
import '../ads/ads_ui.dart';
import '../import/folder_import_preview_page.dart';
import '../../core/utils/snackbar_utils.dart';
import 'book_details_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // To trigger rebuilds of the Futures
  int _refreshKey = 0;
  late TabController _tabController;
  final _prefs = BookshelfPreferencesService.instance;
  bool _isSelectionMode = false;
  final Set<String> _selectedBookIds = {};

  late Future<List<Map<String, dynamic>>> _publicBooksFuture;
  late Future<List<Map<String, dynamic>>> _privateBooksFuture;
  int _publicCount = 0;
  int _privateCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshFutures();
    // Initially length 1, updated in build if needed?
    // Actually, we need to know if private shelf is unlocked to set length.
    // The previous implementation used DefaultTabController which handles this dynamically.
    // To keep it simple and robust, we will check FeatureManager in build to init/update controller.
    // However, TabController length cannot change. Safe bet: always 2, but only show 1 if locked?
    // Or just use a simple variable to track "current tab index" and sync with DefaultTabController?
    // Syncing with DefaultTabController is hard.
    // Let's use a valid approach: Re-create TabController when tabs change.
    _tabController = TabController(length: 1, vsync: this);
  }

  void _refreshFutures() {
    _publicBooksFuture = DatabaseService().getBooks(
      isPrivate: false,
      orderBy: _prefs.getOrderByClause(),
    );
    _privateBooksFuture = DatabaseService().getBooks(
      isPrivate: true,
      orderBy: _prefs.getOrderByClause(),
    );

    // Update counts for UI logic
    _publicBooksFuture.then((list) {
      if (mounted) setState(() => _publicCount = list.length);
    });
    _privateBooksFuture.then((list) {
      if (mounted) setState(() => _privateCount = list.length);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleSelectionMode({bool? active, String? initialBookId}) {
    setState(() {
      _isSelectionMode = active ?? !_isSelectionMode;
      _selectedBookIds.clear();
      if (_isSelectionMode && initialBookId != null) {
        _selectedBookIds.add(initialBookId);
      }
    });
  }

  Future<void> _selectAllBooks(bool showPrivacyTab) async {
    final isPrivateTab = showPrivacyTab && _tabController.index == 1;
    final future = isPrivateTab ? _privateBooksFuture : _publicBooksFuture;

    final books = await future;
    final bookIds = books.map((b) => b['id'] as String).toSet();

    // Check if ALL books in the current view are already selected
    final allSelected = bookIds.every((id) => _selectedBookIds.contains(id));

    setState(() {
      if (allSelected) {
        // Deselect all from current view
        _selectedBookIds.removeAll(bookIds);
      } else {
        // Select all from current view
        _selectedBookIds.addAll(bookIds);
      }
    });
  }

  void _toggleBookSelection(String bookId) {
    setState(() {
      if (_selectedBookIds.contains(bookId)) {
        _selectedBookIds.remove(bookId);
        if (_selectedBookIds.isEmpty) {
          // Optional: Exit selection mode if last item deselected?
          // For now, let's keep it active even if empty, like Gallery apps.
        }
      } else {
        _selectedBookIds.add(bookId);
      }
    });
  }

  Future<void> _deleteSelectedBooks() async {
    final loc = AppLocalizations.of(context)!;
    final count = _selectedBookIds.length;
    if (count == 0) return;

    final prefs = BookshelfPreferencesService.instance;
    bool deleteFile = prefs.deleteFilesOnRemove;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(loc.deleteBooksTitle(count)),
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

    if (confirmed == true) {
      final db = DatabaseService();
      // Copy list to avoid concurrent modification issues if any
      final idsToDelete = List<String>.from(_selectedBookIds);

      for (final id in idsToDelete) {
        // We need to fetch book to get file path if we delete files
        if (deleteFile) {
          final bookData = await db.getBookById(id);
          if (bookData != null) {
            final book = Book.fromMap(bookData);
            final file = File(book.filePath);
            if (await file.exists()) {
              await file.delete();
            }
          }
        }
        await db.deleteBook(id);
      }

      if (mounted) {
        SnackBarUtils.show(context, loc.deletedBooks(count));
        _toggleSelectionMode(active: false);
        _refreshShelf();
      }
    }
  }

  Future<void> _moveSelectedBooks(bool toPrivate) async {
    final loc = AppLocalizations.of(context)!;
    final db = DatabaseService();
    final idsToMove = List<String>.from(_selectedBookIds);

    for (final id in idsToMove) {
      await db.updateBookPrivacy(id, toPrivate);
    }

    if (mounted) {
      final shelf = toPrivate ? loc.privateShelf : loc.publicShelf;
      SnackBarUtils.show(context, loc.movedBooks(idsToMove.length, shelf));
      _toggleSelectionMode(active: false);
      _refreshShelf();
    }
  }

  void _refreshShelf() {
    setState(() {
      _refreshKey++;
      _refreshFutures();
    });
  }

  Future<void> _importBook(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: ['epub', 'txt', 'pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
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
      final appDir = await getApplicationDocumentsDirectory();

      for (final file in result.files) {
        if (file.path != null) {
          try {
            final originalFile = File(file.path!);
            final fileName = path.basename(originalFile.path);
            final savedFile =
                await originalFile.copy(path.join(appDir.path, fileName));

            final book = Book(
              id: const Uuid().v4(),
              title: path.basenameWithoutExtension(fileName),
              author: "Unknown",
              filePath: savedFile.path,
              format: path.extension(fileName).replaceAll('.', ''),
              isPrivate: isPrivate,
            );

            await DatabaseService().insertBook(book.toMap());
            successCount++;
          } catch (e) {
            debugPrint("Error importing file ${file.name}: $e");
          }
        }
      }

      if (mounted && successCount > 0) {
        final loc = AppLocalizations.of(context)!;
        final shelf = isPrivate ? loc.privateShelf : loc.publicShelf;
        SnackBarUtils.show(context, loc.importedBooks(successCount, shelf));
        _refreshShelf();
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

  Future<void> _importFolder(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.getDirectoryPath();

    if (result != null) {
      try {
        // Request storage permission on Android
        if (Platform.isAndroid) {
          PermissionStatus status;

          // Android 13+ (API 33+) uses granular media permissions
          // For reading books, we need all media permissions
          if (await Permission.photos.request().isGranted ||
              await Permission.videos.request().isGranted ||
              await Permission.audio.request().isGranted) {
            status = PermissionStatus.granted;
          } else {
            // Android 12 and below uses READ_EXTERNAL_STORAGE
            status = await Permission.storage.request();
          }

          if (!status.isGranted) {
            if (mounted) {
              SnackBarUtils.show(
                context,
                'Storage permission is required to import folders',
              );
            }
            return;
          }
        }

        final importService = FolderImportService.instance;

        // Scan folder
        final scanResult = await importService.scanFolder(
          result,
          includeHidden: false,
        );

        if (scanResult.files.isEmpty) {
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

        // Filter duplicates
        final db = DatabaseService();
        final existingFilenames = await db.getAllBookFilenames();
        final uniqueFiles =
            importService.filterDuplicates(scanResult.files, existingFilenames);
        final duplicateCount = scanResult.files.length - uniqueFiles.length;

        if (uniqueFiles.isEmpty) {
          if (mounted) {
            SnackBarUtils.show(context, loc.allBooksInLibrary(duplicateCount));
          }
          return;
        }

        if (duplicateCount > 0 && mounted) {
          SnackBarUtils.show(context, loc.duplicatesSkipped(duplicateCount));
        }

        // Determine privacy based on current tab
        final featureManager = context.read<FeatureManager>();
        final isPrivateShelfUnlocked =
            featureManager.isPro && featureManager.isPrivateShelfUnlocked;
        final isPrivate = isPrivateShelfUnlocked && _tabController.index == 1;

        // Navigate to preview page
        if (mounted) {
          final imported = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => FolderImportPreviewPage(
                files: uniqueFiles,
                isPrivate: isPrivate,
              ),
            ),
          );

          if (imported == true) {
            _refreshShelf();
          }
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
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _toggleSelectionMode(active: false),
              ),
              title: Text(
                  '${_selectedBookIds.length} ${AppLocalizations.of(context)!.selected}'),
              actions: [
                if (_selectedBookIds.length == 1)
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    tooltip: AppLocalizations.of(context)!.viewDetails,
                    onPressed: () async {
                      final bookId = _selectedBookIds.first;
                      final bookData =
                          await DatabaseService().getBookById(bookId);
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
                if (_selectedBookIds.isNotEmpty) ...[
                  if (featureManager.isPro)
                    IconButton(
                      icon: Icon(showPrivacyTab ? Icons.lock_open : Icons.lock),
                      tooltip: showPrivacyTab
                          ? AppLocalizations.of(context)!.moveToPublic
                          : AppLocalizations.of(context)!.moveToPrivate,
                      onPressed: () => _moveSelectedBooks(!showPrivacyTab),
                    ),
                ],
                Builder(builder: (context) {
                  final loc = AppLocalizations.of(context)!;
                  final isPrivateTab =
                      showPrivacyTab && _tabController.index == 1;
                  final currentTotal =
                      isPrivateTab ? _privateCount : _publicCount;
                  final allSelected = currentTotal > 0 &&
                      _selectedBookIds.length >= currentTotal;

                  return IconButton(
                    icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                    tooltip: allSelected ? loc.deselectAll : loc.selectAll,
                    onPressed: () => _selectAllBooks(showPrivacyTab),
                  );
                }),
              ],
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            )
          : AppBar(
              title: Text(AppLocalizations.of(context)!.appTitle),
              actions: [
                // View Mode Toggle
                IconButton(
                  icon: Icon(_prefs.viewMode == ViewMode.grid
                      ? Icons.view_list
                      : Icons.grid_view),
                  onPressed: () async {
                    await _prefs.setViewMode(_prefs.viewMode == ViewMode.grid
                        ? ViewMode.list
                        : ViewMode.grid);
                    setState(() {});
                  },
                  tooltip: _prefs.viewMode == ViewMode.grid
                      ? AppLocalizations.of(context)!.listView
                      : AppLocalizations.of(context)!.gridView,
                ),

                // Sort Menu
                PopupMenuButton<SortBy>(
                  icon: const Icon(Icons.sort),
                  tooltip: AppLocalizations.of(context)!.sort,
                  onSelected: (SortBy sortBy) async {
                    await _prefs.setSortBy(sortBy);
                    setState(() {});
                  },
                  itemBuilder: (context) => [
                    for (final sortBy in SortBy.values)
                      PopupMenuItem(
                        value: sortBy,
                        child: Row(
                          children: [
                            if (_prefs.sortBy == sortBy)
                              const Icon(Icons.check, size: 18)
                            else
                              const SizedBox(width: 18),
                            const SizedBox(width: 8),
                            Text(_prefs.getSortByLabel(sortBy)),
                          ],
                        ),
                      ),
                  ],
                ),

                // Lock/Unlock Button
                if (featureManager.isPro)
                  IconButton(
                    icon: Icon(featureManager.isPrivateShelfUnlocked
                        ? Icons.lock_open
                        : Icons.lock),
                    onPressed: () => _handlePrivacyLock(context),
                    tooltip: featureManager.isPrivateShelfUnlocked
                        ? AppLocalizations.of(context)!.lockPrivacyShelf
                        : AppLocalizations.of(context)!.unlockPrivacyShelf,
                  ),

                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsPage()))
                      .then((_) => setState(() {})), // Refresh on return
                )
              ],
              bottom: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor:
                    Theme.of(context).textTheme.bodySmall?.color,
                indicatorColor: Theme.of(context).colorScheme.primary,
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.label,
                indicator: UnderlineTabIndicator(
                  borderRadius: BorderRadius.circular(2),
                  borderSide: BorderSide(
                    width: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                tabs: [
                  Tab(text: AppLocalizations.of(context)!.publicShelf),
                  if (showPrivacyTab)
                    Tab(text: AppLocalizations.of(context)!.privateShelf),
                ],
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            // Ads Stub
            if (!featureManager.isPro && featureManager.adsEnabled)
              AdsUI.showBanner(context),

            // Tabs
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildShelf(context, isPrivate: false),
                  if (showPrivacyTab) _buildShelf(context, isPrivate: true),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSelectionMode) ...[
            FloatingActionButton(
              heroTag: 'delete_fab',
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              child: const Icon(Icons.delete),
              onPressed: _deleteSelectedBooks,
            ),
            const SizedBox(height: 16),
          ],
          FloatingActionButton(
            heroTag: 'add_fab',
            child: const Icon(Icons.add),
            onPressed: () {
              if (Platform.isAndroid) {
                // On Android, folder import is not supported, so just import files directly
                _importBook(context);
              } else {
                _showImportMenu(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShelf(BuildContext context, {required bool isPrivate}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey("shelf_${isPrivate}_$_refreshKey"),
      future: isPrivate ? _privateBooksFuture : _publicBooksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final books = snapshot.data ?? [];

        if (books.isEmpty) {
          final loc = AppLocalizations.of(context)!;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MascotManager().render(MascotScene.emptyShelf, size: 120),
                const SizedBox(height: 16),
                Text(loc.emptyShelfMessage),
              ],
            ),
          );
        }

        return _prefs.viewMode == ViewMode.grid
            ? _buildGridView(context, books, isPrivate)
            : _buildListView(context, books, isPrivate);
      },
    );
  }

  Widget _buildGridView(
      BuildContext context, List<Map<String, dynamic>> books, bool isPrivate) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final bookData = books[index];
        final book = Book.fromMap(bookData);
        final isSelected = _selectedBookIds.contains(book.id);

        return GestureDetector(
          onTap: () {
            if (_isSelectionMode) {
              _toggleBookSelection(book.id);
            } else {
              Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ReaderPage(book: book)))
                  .then((_) => _refreshShelf()); // Refresh shelf on return
            }
          },
          onLongPress: () {
            if (_isSelectionMode) {
              _toggleBookSelection(book.id);
            } else {
              _toggleSelectionMode(active: true, initialBookId: book.id);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Card(
                shape: isSelected
                    ? RoundedRectangleBorder(
                        side: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Soft container for book icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Text(
                        book.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isSelectionMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: isSelected
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : const SizedBox(width: 16, height: 16),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListView(
      BuildContext context, List<Map<String, dynamic>> books, bool isPrivate) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final bookData = books[index];
        final book = Book.fromMap(bookData);
        final isSelected = _selectedBookIds.contains(book.id);

        // Calculate progress percentage
        final progress =
            (bookData['current_progress'] as num?)?.toDouble() ?? 0.0;
        final progressPercent = (progress * 100).toInt();

        // Format last read time
        String lastReadText = 'Never read';
        if (bookData['last_read_at'] != null) {
          final lastRead = DateTime.fromMillisecondsSinceEpoch(
              bookData['last_read_at'] as int);
          lastReadText = dateFormat.format(lastRead);
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : null,
          child: InkWell(
            onTap: () {
              if (_isSelectionMode) {
                _toggleBookSelection(book.id);
              } else {
                Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ReaderPage(book: book)))
                    .then((_) => _refreshShelf()); // Refresh shelf on return
              }
            },
            onLongPress: () {
              if (_isSelectionMode) {
                _toggleBookSelection(book.id);
              } else {
                _toggleSelectionMode(active: true, initialBookId: book.id);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  if (_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (val) => _toggleBookSelection(book.id),
                      ),
                    ),

                  // Soft container for book icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 24,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Book info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${book.author} • ${book.format.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 0.3,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Rounded progress bar
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.15),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$progressPercent%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Last read time
                  if (!_isSelectionMode) // Hide this in selection mode to save space? Or keep it? keeping it is fine.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          lastReadText,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
