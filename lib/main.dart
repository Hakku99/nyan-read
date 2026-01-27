import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/feature_manager.dart';
import 'core/services/database_service.dart';
import 'core/models/book.dart';
import 'modules/reader/reader_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Init Services
  await DatabaseService().database; // warm up db
  final featureManager = FeatureManager();
  await featureManager.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: featureManager),
      ],
      child: const NyanApp(),
    ),
  );
}

class NyanApp extends StatelessWidget {
  const NyanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nyan Read',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        scaffoldBackgroundColor: const Color(0xFFFFF0F5), // Lavender Blush (Cute)
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final featureManager = context.watch<FeatureManager>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nyan Read ฅ^•ﻌ•^ฅ'),
        backgroundColor: Colors.pink[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanel()))
          )
        ],
      ),
      body: Column(
        children: [
          // Pro Banner
          if (featureManager.currentMode == AppMode.free)
            Container(
              color: Colors.yellow[100],
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              child: const Text(
                "ADVERTISEMENT: Buy Pro for Privacy Shelf!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.brown),
              ),
            ),

          // Tabs
          Expanded(
            child: DefaultTabController(
              length: featureManager.privacyShelfEnabled ? 2 : 1,
              child: Column(
                children: [
                  TabBar(
                    labelColor: Colors.pink,
                    indicatorColor: Colors.pink,
                    tabs: [
                      const Tab(text: "Public Shelf"),
                      if (featureManager.privacyShelfEnabled)
                        const Tab(text: "Privacy Shelf (Pro)"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildShelf(context, isPrivate: false),
                        if (featureManager.privacyShelfEnabled)
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
        onPressed: () {
          // Stub: Add a dummy book to DB
          DatabaseService().insertBook(
            Book(
              id: DateTime.now().toIso8601String(),
              title: "New Book ${DateTime.now().second}",
              author: "Author",
              filePath: "dummy/path.epub",
              format: "epub",
              isPrivate: false, // Default to public
            ).toMap()
          );
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dummy Book Added! Refresh required.")));
        },
      ),
    );
  }

  Widget _buildShelf(BuildContext context, {required bool isPrivate}) {
    // In real app: FutureBuilder connected to DatabaseService.getBooks(isPrivate: isPrivate)
    // Here: Static Dummy List for UI Demo
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 5,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
             Navigator.push(context, MaterialPageRoute(
               builder: (_) => ReaderPage(
                 book: Book(id: '1', title: 'Demo Book', author: 'Me', filePath: '', format: 'epub')
               )
             ));
          },
          child: Card(
            color: isPrivate ? Colors.grey[200] : Colors.white,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isPrivate ? Icons.lock : Icons.book, size: 40, color: Colors.pink[200]),
                const SizedBox(height: 8),
                Text("Book $index", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final fm = context.watch<FeatureManager>();
    
    return Scaffold(
      appBar: AppBar(title: const Text("Admin / Manager Mode")),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Pro Mode Enabled"),
            subtitle: const Text("Unlocks Privacy Shelf, No Ads"),
            value: fm.currentMode == AppMode.pro,
            onChanged: (val) => fm.toggleMode(val ? AppMode.pro : AppMode.free),
          ),
          const Divider(),
          ListTile(
            title: const Text("Feature Flags Status"),
            subtitle: Text(
              "Ads: ${fm.adsEnabled}\n"
              "Privacy: ${fm.privacyShelfEnabled}\n"
              "TTS: ${fm.ttsEnabled}"
            ),
          ),
        ],
      ),
    );
  }
}
