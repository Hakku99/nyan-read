import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

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
    // Current tab index: 0 = Public, 1 = Private (if shown)
    // If showPrivacyTab is false, index 0 is always Public.
    // If showPrivacyTab is true, index 0 is Public, 1 is Private.
    // Wait, TabController index might not match if tabs are hidden?
    // public/private decision relies on `isPrivate` in `_buildShelf`.
    // Let's assume TabController matches the view.

    final isPrivateTab = showPrivacyTab && _tabController.index == 1;
    final future = isPrivateTab ? _privateBooksFuture : _publicBooksFuture;

    final books = await future;
    setState(() {
      _selectedBookIds
          .clear(); // Or should we append? Usually "Select All" replaces or adds.
      // Let's just add all from current view.
      for (final book in books) {
        // book is Map<String, dynamic> here? No, fetch returns Map.
        // Wait, DatabaseService().getBooks returns List<Map<...>>.
        // We need 'id'.
        if (book['id'] != null) {
          _selectedBookIds.add(book['id'] as String);
        }
      }
    });
  }

  void _deselectAllBooks() {
    setState(() {
      _selectedBookIds.clear();
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
              title: Text('⚠️ Delete $count Books?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("This action cannot be undone."),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Also delete local files'),
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
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error),
                  child: const Text('Delete'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $count books')),
        );
        _toggleSelectionMode(active: false);
        _refreshShelf();
      }
    }
  }

  Future<void> _moveSelectedBooks(bool toPrivate) async {
    final db = DatabaseService();
    final idsToMove = List<String>.from(_selectedBookIds);

    for (final id in idsToMove) {
      await db.updateBookPrivacy(id, toPrivate);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Moved ${idsToMove.length} books to ${toPrivate ? 'Private' : 'Public'} Shelf')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "Imported $successCount books to ${isPrivate ? 'Private' : 'Public'} Shelf!")));
        _refreshShelf();
      }
    }
  }

  void _showImportMenu(BuildContext context) {
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
                title: const Text('Import Files'),
                onTap: () {
                  Navigator.pop(context);
                  _importBook(parentContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Import Folder'),
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
    final result = await FilePicker.platform.getDirectoryPath();

    if (result != null) {
      try {
        // Scan folder
        final files = await FolderImportService.instance.scanFolder(
          result,
          includeHidden: false,
        );

        if (files.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('No supported books found in folder')),
            );
          }
          return;
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
                files: files,
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error scanning folder: $e')),
          );
        }
      }
    }
  }

  Future<void> _handlePrivacyLock(BuildContext context) async {
    final fm = context.read<FeatureManager>();
    final privacyService = PrivacyLockService();

    if (fm.isPrivateShelfUnlocked) {
      // Lock it
      fm.lockPrivateShelf();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Privacy Shelf Locked")));
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
    final passController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Set Privacy Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: passController,
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true),
            TextField(
                controller: confirmController,
                decoration:
                    const InputDecoration(labelText: "Confirm Password"),
                obscureText: true),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Passwords do not match")));
                }
              },
              child: const Text("Save")),
        ],
      ),
    );
  }

  void _showEnterPasswordDialog(BuildContext context) {
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Unlock Privacy Shelf"),
        content: TextField(
          controller: passController,
          decoration: const InputDecoration(labelText: "Password"),
          obscureText: true,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
              onPressed: () async {
                final isValid = await PrivacyLockService()
                    .verifyPassword(passController.text);
                if (mounted) {
                  Navigator.pop(ctx);
                  if (isValid) {
                    context.read<FeatureManager>().unlockPrivateShelf();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Invalid Password")));
                  }
                }
              },
              child: const Text("Unlock")),
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
              title: Text('${_selectedBookIds.length} Selected'),
              actions: [
                if (_selectedBookIds.length == 1)
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    tooltip: 'View Details',
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
                      tooltip:
                          showPrivacyTab ? 'Move to Public' : 'Move to Private',
                      onPressed: () => _moveSelectedBooks(!showPrivacyTab),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: 'Delete Selected',
                    onPressed: _deleteSelectedBooks,
                  ),
                ],
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'select_all') {
                      _selectAllBooks(showPrivacyTab);
                    } else if (value == 'deselect_all') {
                      _deselectAllBooks();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'select_all',
                      child: Text('Select All'),
                    ),
                    const PopupMenuItem(
                      value: 'deselect_all',
                      child: Text('Deselect All'),
                    ),
                  ],
                ),
              ],
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            )
          : AppBar(
              title: const Text('Nyan Read ฅ^•ﻌ•^ฅ'),
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
                      ? 'List View'
                      : 'Grid View',
                ),

                // Sort Menu
                PopupMenuButton<SortBy>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort',
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

                // Select Mode Entry
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: 'Select Books',
                  onPressed: () => _toggleSelectionMode(active: true),
                ),

                // Lock/Unlock Button
                if (featureManager.isPro)
                  IconButton(
                    icon: Icon(featureManager.isPrivateShelfUnlocked
                        ? Icons.lock_open
                        : Icons.lock),
                    onPressed: () => _handlePrivacyLock(context),
                    tooltip: featureManager.isPrivateShelfUnlocked
                        ? "Lock Privacy Shelf"
                        : "Unlock Privacy Shelf",
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
                  const Tab(text: "Public Shelf"),
                  if (showPrivacyTab) const Tab(text: "Private Shelf"),
                ],
              ),
            ),
      body: Column(
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
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showImportMenu(context),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MascotManager().render(MascotScene.emptyShelf, size: 120),
                const SizedBox(height: 16),
                const Text("It's empty here. Import a book?"),
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
