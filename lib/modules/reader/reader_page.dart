import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/book.dart';
import '../../core/services/database_service.dart';
import '../bookmark/bookmark_list_page.dart';
import 'reader_engine/reader_engine.dart';
import 'reader_engine/reader_factory.dart';
import 'reader_engine/epub/epub_position.dart';
import 'reader_engine/txt/txt_position.dart';
import 'reader_engine/pdf/pdf_position.dart';
import 'dart:async';
import 'dart:convert';

class ReaderController extends ChangeNotifier {
  final Book book;
  late ReaderEngine engine;

  double _fontSize = 18.0;
  double _lineHeight = 1.5;
  double _brightness = 1.0; 
  Color _backgroundColor = const Color(0xFFFAF9F6);
  Timer? _reminderTimer;
  int _readSeconds = 0;
  bool _showControls = false; // Hidden by default for better immersion

  ReaderController(this.book) {
    engine = ReaderEngineFactory.create(book);
  }

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  double get brightness => _brightness;
  Color get backgroundColor => _backgroundColor;
  bool get showControls => _showControls;

  void init() {
    _reminderTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _readSeconds++;
      if (_readSeconds > 0 && _readSeconds % 3600 == 0) {
        notifyListeners(); 
      }
    });
  }

  bool get shouldShowReminder => _readSeconds > 0 && _readSeconds % 3600 == 0;

  void toggleControls() {
    _showControls = !_showControls;
    notifyListeners();
  }

  Future<void> addBookmark(BuildContext context) async {
    final position = engine.getCurrentPosition();
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot determine position")));
      return;
    }

    final bookmark = {
      'id': const Uuid().v4(),
      'book_id': book.id,
      'page_index': 0, // Legacy support, mostly irrelevant now
      'position_type': book.format,
      'position_payload': position.toJson(),
      'note': '',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
    
    await DatabaseService().insertBookmark(bookmark);
    if (context.mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bookmark Added!")));
    }
  }

  Future<void> restorePosition(Map<String, dynamic> bookmarkData) async {
    final type = bookmarkData['position_type'] ?? book.format;
    final payload = bookmarkData['position_payload'];
    
    if (payload == null) return;

    ReadingPosition? pos;
    try {
      if (type == 'epub') {
        pos = EpubReadingPosition.fromJson(payload);
      } else if (type == 'pdf') {
        pos = PdfReadingPosition.fromJson(payload);
      } else if (type == 'txt') {
        pos = TxtReadingPosition.fromJson(payload);
      }
      
      if (pos != null) {
        await engine.goToPosition(pos);
      }
    } catch (e) {
      debugPrint("Error restoring position: $e");
    }
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
    engine.dispose();
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
                    color: controller.backgroundColor,
                    width: double.infinity,
                    height: double.infinity,
                    child: controller.engine.buildReader(context),
                  ),
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
                        onPressed: () => controller.addBookmark(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmarks),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (_) => BookmarkListPage(bookId: book.id, bookTitle: book.title)
                            )
                          );
                          if (result != null && result is Map<String, dynamic>) {
                             controller.restorePosition(result);
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
                        // Font Size (Visual only for now, engine needs to listen)
                        if (book.format == 'txt') ...[
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
                        ],
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
