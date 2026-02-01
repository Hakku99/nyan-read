import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../core/services/feature_manager.dart';
import '../../core/services/database_service.dart';
import '../../core/models/book.dart';
import '../../core/services/mascot_manager.dart';
import '../../modules/privacy/privacy_lock_service.dart';
import '../reader/reader_page.dart';
import '../settings/settings_page.dart';
import '../ads/ads_ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // To trigger rebuilds of the Futures
  int _refreshKey = 0;

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
      final savedFile = await originalFile.copy(path.join(appDir.path, fileName));

      final book = Book(
        id: const Uuid().v4(),
        title: path.basenameWithoutExtension(fileName), // Simple title derivation
        author: "Unknown",
        filePath: savedFile.path,
        format: path.extension(fileName).replaceAll('.', ''),
        isPrivate: false, // Default to public
      );

      await DatabaseService().insertBook(book.toMap());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Book Imported!")));
        _refreshShelf();
      }
    }
  }

  Future<void> _handlePrivacyLock(BuildContext context) async {
    final fm = context.read<FeatureManager>();
    final privacyService = PrivacyLockService();

    if (fm.isPrivateShelfUnlocked) {
      // Lock it
      fm.lockPrivateShelf();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Privacy Shelf Locked")));
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
            TextField(controller: passController, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
            TextField(controller: confirmController, decoration: const InputDecoration(labelText: "Confirm Password"), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              if (passController.text.isNotEmpty && passController.text == confirmController.text) {
                await PrivacyLockService().setPassword(passController.text);
                if (mounted) {
                  Navigator.pop(ctx);
                  _showEnterPasswordDialog(context); // Auto prompt to enter after setting? Or just unlock? Let's prompt.
                }
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
              }
            }, 
            child: const Text("Save")
          ),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final isValid = await PrivacyLockService().verifyPassword(passController.text);
              if (mounted) {
                Navigator.pop(ctx);
                if (isValid) {
                  context.read<FeatureManager>().unlockPrivateShelf();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Password")));
                }
              }
            }, 
            child: const Text("Unlock")
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final featureManager = context.watch<FeatureManager>();
    // final themeManager = context.watch<ThemeManager>(); // Used via Theme.of(context) generally

    // Logic: Only show Privacy Tab if Pro AND Unlocked
    final showPrivacyTab = featureManager.isPro && featureManager.isPrivateShelfUnlocked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nyan Read ฅ^•ﻌ•^ฅ'),
        actions: [
          // Lock/Unlock Button
          if (featureManager.isPro)
            IconButton(
              icon: Icon(featureManager.isPrivateShelfUnlocked ? Icons.lock_open : Icons.lock),
              onPressed: () => _handlePrivacyLock(context),
              tooltip: featureManager.isPrivateShelfUnlocked ? "Lock Privacy Shelf" : "Unlock Privacy Shelf",
            ),
          
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())).then((_) => setState((){})), // Refresh on return
          )
        ],
      ),
      body: Column(
        children: [
          // Ads Stub
          if (!featureManager.isPro && featureManager.adsEnabled)
             AdsUI.showBanner(context),

          // Tabs
          Expanded(
            child: DefaultTabController(
              length: showPrivacyTab ? 2 : 1,
              child: Column(
                children: [
                  TabBar(
                    labelColor: Theme.of(context).colorScheme.secondary,
                    unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
                    indicatorColor: Theme.of(context).colorScheme.secondary,
                    indicatorWeight: 4, // Thickness of border bottom of current active tab
                    tabs: [
                      const Tab(text: "Public Shelf"),
                      if (showPrivacyTab)
                        const Tab(text: "Private Shelf"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildShelf(context, isPrivate: false),
                        if (showPrivacyTab)
                          _buildShelf(context, isPrivate: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _importBook(context),
      ),
    );
  }

  Widget _buildShelf(BuildContext context, {required bool isPrivate}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey("shelf_${isPrivate}_$_refreshKey"), // Force rebuild on refresh
      future: DatabaseService().getBooks(isPrivate: isPrivate),
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
                 Navigator.push(context, MaterialPageRoute(
                   builder: (_) => ReaderPage(book: book)
                 ));
              },
              child: Card(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.book, size: 40, color: Colors.pink),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(book.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}