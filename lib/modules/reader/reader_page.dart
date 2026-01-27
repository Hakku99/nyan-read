import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/book.dart';
import 'dart:async';

class ReaderController extends ChangeNotifier {
  final Book book;
  double _fontSize = 16.0;
  double _brightness = 1.0; // 0.0 to 1.0
  Color _backgroundColor = const Color(0xFFFAF9F6); // Off-white
  int _currentPage = 0;
  Timer? _reminderTimer;
  int _readSeconds = 0;

  ReaderController(this.book);

  double get fontSize => _fontSize;
  double get brightness => _brightness;
  Color get backgroundColor => _backgroundColor;
  int get currentPage => _currentPage;

  void init() {
    // Start reading timer
    _reminderTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _readSeconds++;
      if (_readSeconds == 3600) { // 60 mins
        // Trigger generic event or notify UI to show dialog
        notifyListeners(); 
      }
    });
  }

  bool get showReminder => _readSeconds > 0 && _readSeconds % 3600 == 0;

  void nextPage() {
    _currentPage++;
    notifyListeners();
  }

  void prevPage() {
    if (_currentPage > 0) _currentPage--;
    notifyListeners();
  }

  void setFontSize(double size) {
    _fontSize = size;
    notifyListeners();
  }

  void setBackground(Color color) {
    _backgroundColor = color;
    notifyListeners();
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }
}

class ReaderPage extends StatelessWidget {
  final Book book;

  const ReaderPage({Key? key, required this.book}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReaderController(book)..init(),
      child: Consumer<ReaderController>(
        builder: (context, controller, child) {
          // Reminder Popup Logic
          if (controller.showReminder) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("ฅ^•ﻌ•^ฅ"),
                  content: const Text("You've been reading for an hour! Time to stretch."),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
                ),
              );
            });
          }

          return Scaffold(
            backgroundColor: controller.backgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.black54),
              actions: [
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  onPressed: () {
                    // Integration with Bookmark Module
                    // In real app: Provider.of<BookmarkService>(context, listen: false).addBookmark(...)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Bookmark Added!"))
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _showSettingsSheet(context, controller),
                )
              ],
            ),
            body: Stack(
              children: [
                // Content Area (Simulated)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      "This is page ${controller.currentPage + 1} of ${book.title}.\n\n"
                      "Imagine actual EPUB content here rendered with the selected font size.",
                      style: TextStyle(
                        fontSize: controller.fontSize,
                        fontFamily: 'Roboto', // Default
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                
                // Tap Zones
                Row(
                  children: [
                    Expanded(child: GestureDetector(onTap: controller.prevPage)),
                    Expanded(child: GestureDetector(onTap: controller.nextPage)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, ReaderController controller) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Display Settings"),
            Row(
              children: [
                const Text("Size:"),
                Expanded(
                  child: Slider(
                    value: controller.fontSize,
                    min: 12,
                    max: 30,
                    onChanged: controller.setFontSize,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _colorBtn(controller, const Color(0xFFFAF9F6)),
                _colorBtn(controller, const Color(0xFFFFF8E1)), // Yellowish
                _colorBtn(controller, const Color(0xFF263238), isDark: true), // Dark
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _colorBtn(ReaderController c, Color color, {bool isDark = false}) {
    return GestureDetector(
      onTap: () => c.setBackground(color),
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.grey),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
