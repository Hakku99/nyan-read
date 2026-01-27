import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/book.dart';
import '../../core/services/database_service.dart';
import '../bookmark/bookmark_list_page.dart'; // For navigation
import 'dart:async';

class ReaderController extends ChangeNotifier {
  final Book book;
  double _fontSize = 18.0;
  double _lineHeight = 1.5;
  double _brightness = 1.0; // 0.0 to 1.0
  Color _backgroundColor = const Color(0xFFFAF9F6); // Off-white
  int _currentPage = 0;
  Timer? _reminderTimer;
  int _readSeconds = 0;
  bool _showControls = true;

  ReaderController(this.book);

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  double get brightness => _brightness;
  Color get backgroundColor => _backgroundColor;
  int get currentPage => _currentPage;
  bool get showControls => _showControls;

  void init() {
    // Start reading timer
    _reminderTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _readSeconds++;
      if (_readSeconds > 0 && _readSeconds % 3600 == 0) { // 60 mins
        notifyListeners(); 
      }
    });
  }

  bool get shouldShowReminder => _readSeconds > 0 && _readSeconds % 3600 == 0;

  void toggleControls() {
    _showControls = !_showControls;
    notifyListeners();
  }

  void nextPage() {
    _currentPage++;
    notifyListeners();
  }

  void prevPage() {
    if (_currentPage > 0) _currentPage--;
    notifyListeners();
  }

  void jumpToPage(int page) {
    _currentPage = page;
    notifyListeners();
  }

  Future<void> addBookmark() async {
    final bookmark = {
      'id': const Uuid().v4(),
      'book_id': book.id,
      'page_index': _currentPage,
      'note': '',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
    await DatabaseService().insertBookmark(bookmark);
  }

  void setFontSize(double size) {
    _fontSize = size;
    notifyListeners();
  }

  void setLineHeight(double height) {
    _lineHeight = height;
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
          final theme = Theme.of(context);
          
          // Reminder Popup Logic
          if (controller.shouldShowReminder) {
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
            body: Stack(
              children: [
                // Content Area
                GestureDetector(
                  onTap: controller.toggleControls,
                  child: Container(
                    color: controller.backgroundColor, // Fill for tap detection
                    width: double.infinity,
                    height: double.infinity,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          "This is page ${controller.currentPage + 1} of ${book.title}.\n\n"
                          "Imagine actual EPUB content here rendered with:\n"
                          "- Font Size: ${controller.fontSize.toStringAsFixed(1)}\n"
                          "- Line Height: ${controller.lineHeight.toStringAsFixed(1)}",
                          style: TextStyle(
                            fontSize: controller.fontSize,
                            height: controller.lineHeight,
                            fontFamily: 'Roboto', 
                            color: Colors.black87, // Needs to contrast with background
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Tap Zones for turning pages (if controls hidden)
                if (!controller.showControls)
                  Row(
                    children: [
                      Expanded(child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: controller.prevPage,
                      )),
                      Expanded(child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: controller.nextPage,
                      )),
                    ],
                  ),

                // Top Toolbar
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  top: controller.showControls ? 0 : -100,
                  left: 0, right: 0,
                  child: AppBar(
                    backgroundColor: theme.primaryColor,
                    title: Text(book.title, style: const TextStyle(fontSize: 16)),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.bookmark_add_outlined),
                        onPressed: () async {
                           await controller.addBookmark();
                           if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bookmark Added!")));
                           }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmarks),
                        onPressed: () async {
                          final page = await Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (_) => BookmarkListPage(bookId: book.id, bookTitle: book.title)
                            )
                          );
                          if (page != null && page is int) {
                            controller.jumpToPage(page);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // Bottom Toolbar
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  bottom: controller.showControls ? 0 : -200,
                  left: 0, right: 0,
                  child: Container(
                    color: theme.cardColor,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Font Size
                        Row(
                          children: [
                            const Text("A", style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: Slider(
                                value: controller.fontSize,
                                min: 12,
                                max: 32,
                                onChanged: controller.setFontSize,
                              ),
                            ),
                            const Text("A", style: TextStyle(fontSize: 24)),
                          ],
                        ),
                        // Line Height & Spacing
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             const Text("Line Height"),
                             Row(
                               children: [
                                 IconButton(
                                   icon: const Icon(Icons.remove),
                                   onPressed: () => controller.setLineHeight(controller.lineHeight - 0.1),
                                 ),
                                 Text(controller.lineHeight.toStringAsFixed(1)),
                                 IconButton(
                                   icon: const Icon(Icons.add),
                                   onPressed: () => controller.setLineHeight(controller.lineHeight + 0.1),
                                 ),
                               ],
                             )
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Background Colors
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _colorBtn(controller, const Color(0xFFFAF9F6)),
                              const SizedBox(width: 10),
                              _colorBtn(controller, const Color(0xFFFFF8E1)),
                              const SizedBox(width: 10),
                              _colorBtn(controller, const Color(0xFFE0F7FA)),
                              const SizedBox(width: 10),
                              _colorBtn(controller, const Color(0xFFF3E5F5)),
                              const SizedBox(width: 10),
                              _colorBtn(controller, const Color(0xFF263238), isDark: true),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
        child: c.backgroundColor == color 
            ? Icon(Icons.check, color: isDark ? Colors.white : Colors.black) 
            : null,
      ),
    );
  }
}
