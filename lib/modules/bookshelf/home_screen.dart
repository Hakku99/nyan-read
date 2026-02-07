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

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshShelf() {
    setState(() {
      _refreshKey++;
    });
  }

  Future<void> _importBook(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'txt', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final originalFile = File(result.files.single.path!);
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(originalFile.path);
      final savedFile =
          await originalFile.copy(path.join(appDir.path, fileName));

      // Determine privacy based on current tab
      // If we are on the second tab (index 1), it's private.
      // But we need to make sure the second tab IS the private shelf.
      final featureManager = context.read<FeatureManager>();
      final isPrivateShelfUnlocked =
          featureManager.isPro && featureManager.isPrivateShelfUnlocked;

      // If private shelf is not visible, we can't be on it.
      // If it is visible, check tab index.
      final isPrivate = isPrivateShelfUnlocked && _tabController.index == 1;

      final book = Book(
        id: const Uuid().v4(),
        title: path.basenameWithoutExtension(fileName),
        author: "Unknown",
        filePath: savedFile.path,
        format: path.extension(fileName).replaceAll('.', ''),
        isPrivate: isPrivate,
      );

      await DatabaseService().insertBook(book.toMap());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "Book Imported to ${isPrivate ? 'Private' : 'Public'} Shelf!")));
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
                title: const Text('Import Single File'),
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
      appBar: AppBar(
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
            tooltip:
                _prefs.viewMode == ViewMode.grid ? 'List View' : 'Grid View',
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
            onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()))
                .then((_) => setState(() {})), // Refresh on return
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.secondary,
          unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
          indicatorColor: Theme.of(context).colorScheme.secondary,
          indicatorWeight: 4,
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
      future: DatabaseService().getBooks(
        isPrivate: isPrivate,
        orderBy: _prefs.getOrderByClause(),
      ),
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
        return GestureDetector(
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => ReaderPage(book: book)));
          },
          onLongPress: () => _showBookMenu(context, book, isPrivate),
          child: Card(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.book, size: 40, color: Colors.pink),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(book.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
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
          child: InkWell(
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ReaderPage(book: book)));
            },
            onLongPress: () => _showBookMenu(context, book, isPrivate),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Book icon
                  const Icon(Icons.book, size: 40, color: Colors.pink),
                  const SizedBox(width: 16),

                  // Book info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${book.author} • ${book.format.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Progress bar
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey[300],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.pink),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$progressPercent%',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Last read time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        lastReadText,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
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

  void _showBookMenu(BuildContext context, Book book, bool isPrivate) async {
    // Fetch full book data for details page
    final bookData = await DatabaseService().getBookById(book.id);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('View Details'),
                onTap: () {
                  Navigator.pop(context);
                  if (bookData != null) {
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
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Book'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context, book);
                },
              ),
              if (context.read<FeatureManager>().isPro)
                ListTile(
                  leading: Icon(isPrivate ? Icons.lock_open : Icons.lock),
                  title: Text(isPrivate
                      ? 'Move to Public Shelf'
                      : 'Move to Private Shelf'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _moveBook(context, book, !isPrivate);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Book book) async {
    final prefs = BookshelfPreferencesService.instance;
    bool deleteFile = prefs.deleteFilesOnRemove;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('⚠️ Confirm Delete'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Book: ${book.title}'),
                  const SizedBox(height: 8),
                  Text(
                    'File: ${book.filePath}',
                    style:
                        const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Also delete local file'),
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
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      await _deleteBook(book, deleteFile);
    }
  }

  Future<void> _deleteBook(Book book, bool deleteFile) async {
    try {
      // Delete from database
      await DatabaseService().deleteBook(book.id);

      // Delete file if requested
      if (deleteFile) {
        final file = File(book.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${book.title} deleted')),
        );
        _refreshShelf();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting book: $e')),
        );
      }
    }
  }

  Future<void> _moveBook(
      BuildContext context, Book book, bool toPrivate) async {
    try {
      // Check if moving to private shelf requires unlock
      if (toPrivate) {
        final fm = context.read<FeatureManager>();
        if (!fm.isPrivateShelfUnlocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please unlock Private Shelf first')),
          );
          return;
        }
      }

      await DatabaseService().updateBookPrivacy(book.id, toPrivate);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${book.title} moved to ${toPrivate ? "Private" : "Public"} Shelf'),
          ),
        );
        _refreshShelf();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error moving book: $e')),
        );
      }
    }
  }
}
