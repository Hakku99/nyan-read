import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Design system constants
  static const double _radius16 = 16.0;
  static const double _spacing8 = 8.0;
  static const double _spacing12 = 12.0;
  static const double _spacing16 = 16.0;
  static const double _spacing24 = 24.0;
  static const double _minTouchTarget = 40.0;

  // To trigger rebuilds of the Futures
  int _refreshKey = 0;
  late TabController _tabController;
  final _prefs = getIt<BookshelfPreferencesService>();
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
    _publicBooksFuture = getIt<DatabaseService>().getBooks(
      isPrivate: false,
      orderBy: _prefs.getOrderByClause(),
    );
    _privateBooksFuture = getIt<DatabaseService>().getBooks(
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

    final prefs = getIt<BookshelfPreferencesService>();
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
      final db = getIt<DatabaseService>();
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
    final db = getIt<DatabaseService>();
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

      for (final file in result.files) {
        if (file.path != null) {
          try {
            final originalFile = File(file.path!);
            final fileName = path.basename(originalFile.path);

            // Check if file with this name already exists in the database
            if (existingFilenames.contains(fileName)) {
              skippedCount++;
              debugPrint("Skipping duplicate file: $fileName");
              continue;
            }

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
          _refreshShelf();
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
                          _refreshShelf();
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
          _refreshShelf();
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
                const SizedBox(width: _spacing8),
              ],
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            )
          : AppBar(
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

                      // Content with animated transition
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeOutCubic,
                          child: KeyedSubtree(
                            key: ValueKey(_tabController.index),
                            child: _buildShelf(
                              context,
                              isPrivate:
                                  showPrivacyTab && _tabController.index == 1,
                            ),
                          ),
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
            const SizedBox(height: _spacing16),
          ],
          FloatingActionButton(
            heroTag: 'add_fab',
            elevation: 0,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                : Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onPrimary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(_spacing24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MascotManager().render(MascotScene.emptyShelf, size: 120),
                  const SizedBox(height: _spacing24),
                  Text(
                    AppLocalizations.of(context)!.emptyShelfTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: _spacing8),
                  Text(
                    AppLocalizations.of(context)!.emptyShelfSubtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
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
      padding: const EdgeInsets.all(_spacing16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75, // 3:4 ratio
        crossAxisSpacing: _spacing16,
        mainAxisSpacing: _spacing16,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final bookData = books[index];
        final book = Book.fromMap(bookData);
        final isSelected = _selectedBookIds.contains(book.id);

        return AnimatedBookCardGrid(
          book: book,
          isSelected: isSelected,
          isSelectionMode: _isSelectionMode,
          onTap: () {
            if (_isSelectionMode) {
              _toggleBookSelection(book.id);
            } else {
              context.push('/reader/${book.id}').then((_) => _refreshShelf());
            }
          },
          onLongPress: () {
            if (_isSelectionMode) {
              _toggleBookSelection(book.id);
            } else {
              _toggleSelectionMode(active: true, initialBookId: book.id);
            }
          },
        );
      },
    );
  }

  Widget _buildListView(
      BuildContext context, List<Map<String, dynamic>> books, bool isPrivate) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: _spacing16, vertical: _spacing8),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final bookData = books[index];
        final book = Book.fromMap(bookData);
        final isSelected = _selectedBookIds.contains(book.id);

        return AnimatedBookCardList(
          book: book,
          bookData: bookData,
          isSelected: isSelected,
          isSelectionMode: _isSelectionMode,
          onTap: () {
            if (_isSelectionMode) {
              _toggleBookSelection(book.id);
            } else {
              context.push('/reader/${book.id}').then((_) => _refreshShelf());
            }
          },
          onLongPress: () {
            if (_isSelectionMode) {
              _toggleBookSelection(book.id);
            } else {
              _toggleSelectionMode(active: true, initialBookId: book.id);
            }
          },
          onSelectionToggle: () => _toggleBookSelection(book.id),
        );
      },
    );
  }
}
