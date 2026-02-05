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
import 'reader_error.dart';
import 'widgets/reader_error_view.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ReaderController extends ChangeNotifier {
  final Book book;
  late ReaderEngine engine;

  double _fontSize = 18.0;
  double _lineHeight = 1.5;
  double _brightness = 1.0; 
  Color _backgroundColor = const Color(0xFFFAF9F6);
  Color _textColor = Colors.black87;
  Timer? _reminderTimer;
  Timer? _progressTimer;
  int _readSeconds = 0;
  bool _showControls = false; 
  double _currentProgress = 0.0;
  ReaderErrorState? _errorState;

  ReaderController(this.book) {
    engine = ReaderEngineFactory.create(book);
    _updateEngineConfig();
  }

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  double get brightness => _brightness;
  Color get backgroundColor => _backgroundColor;
  Color get textColor => _textColor;
  bool get showControls => _showControls;
  double get currentProgress => _currentProgress;
  ReaderErrorState? get errorState => _errorState;

  void init() {
    _startTimer();
    _loadBook();
  }

  void _startTimer() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _readSeconds++;
      if (_readSeconds > 0 && _readSeconds % 3600 == 0) {
        notifyListeners(); 
      }
    });
  }

  Future<void> _loadBook() async {
    try {
      _errorState = null;
      notifyListeners();
      await engine.initialize();
      notifyListeners();
    } catch (e, stack) {
      ReaderErrorType type = ReaderErrorType.unknown;
      final errorStr = e.toString().toLowerCase();
      
      if (e is FileSystemException || errorStr.contains('file not found')) {
        type = ReaderErrorType.fileNotFound;
      } else if (e is FormatException || errorStr.contains('format')) {
        type = ReaderErrorType.parseFailed;
      } else if (errorStr.contains('unsupported')) {
        type = ReaderErrorType.unsupportedFormat;
      }

      _errorState = ReaderErrorState(
        type: type,
        technicalMessage: "$e\n$stack",
      );
      notifyListeners();
    }
  }

  void retry() {
    _loadBook();
  }

  void _updateEngineConfig() {
    // Defined Preset Colors
    const lightSet = [
      Color(0xFFFAF9F6), // Off-white
      Color(0xFFFFF8E1), // Light Yellow
      Color(0xFFE0F7FA), // Light Cyan
    ];
    
    // Check strict sets first
    if (lightSet.any((c) => c.value == _backgroundColor.value)) {
      _textColor = Colors.black;
    } else if (_backgroundColor.value == 0xFF2E2A3A || _backgroundColor.value == 0xFF000000) {
      // Midnight Blue or Black
      _textColor = Colors.white;
    } else {
      // Fallback luminance check
      _textColor = _backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    }

    engine.setConfig(ReaderConfig(
      backgroundColor: _backgroundColor,
      textColor: _textColor,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
    ));
  }

  bool get shouldShowReminder => _readSeconds > 0 && _readSeconds % 3600 == 0;

  void toggleControls() {
    _showControls = !_showControls;
    if (_showControls) {
      _syncProgress();
      _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) => _syncProgress());
    } else {
      _progressTimer?.cancel();
    }
    notifyListeners();
  }

  void _syncProgress() {
    final p = engine.getProgress() ?? 0.0;
    if (p != _currentProgress) {
      _currentProgress = p;
      notifyListeners();
    }
  }

  Future<void> seekTo(double val) async {
    _currentProgress = val;
    notifyListeners(); // Optimistic update
    await engine.seekToProgress(val);
  }

  Future<void> addBookmark(BuildContext context) async {
    final position = engine.getCurrentPosition();
    if (position == null) return;

    final bookmark = {
      'id': const Uuid().v4(),
      'book_id': book.id,
      'page_index': 0, 
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
    final type = (bookmarkData['position_type'] ?? book.format).toString().toLowerCase();
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
    _updateEngineConfig();
    notifyListeners();
  }

  void setLineHeight(double height) {
    _lineHeight = height;
    _updateEngineConfig();
    notifyListeners();
  }

  void setBackground(Color color) {
    _backgroundColor = color;
    _updateEngineConfig();
    notifyListeners();
  }

  void setBrightness(double b) {
    _brightness = b;
    notifyListeners();
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    _progressTimer?.cancel();
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
          
          if (controller.errorState != null) {
            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor, // Or let the View handle it
              body: ReaderErrorView(
                errorState: controller.errorState!,
                onBack: () => Navigator.pop(context),
                onRetry: controller.retry,
              ),
            );
          }

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
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        textTheme: Theme.of(context).textTheme.apply(
                          bodyColor: controller.textColor,
                          displayColor: controller.textColor,
                        ),
                        iconTheme: IconThemeData(color: controller.textColor),
                      ),
                      child: controller.engine.buildReader(context),
                    ),
                  ),
                ),

                // Brightness Overlay (Dimmer)
                IgnorePointer(
                  child: Container(
                    color: Colors.black.withOpacity(1.0 - controller.brightness),
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
                  bottom: controller.showControls ? 0 : -350,
                  left: 0, right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress
                        Row(
                          children: [
                             SizedBox(
                               width: 40, 
                               child: Text("${(controller.currentProgress * 100).toInt()}%", style: const TextStyle(fontSize: 12))
                             ),
                             Expanded(
                               child: Slider(
                                 value: controller.currentProgress,
                                 min: 0.0, max: 1.0,
                                 onChanged: (val) => controller.seekTo(val),
                               ),
                             ),
                          ],
                        ),
                        
                        // Brightness
                        Row(
                          children: [
                            const Icon(Icons.brightness_low, size: 20),
                            Expanded(
                              child: Slider(
                                value: controller.brightness,
                                min: 0.2, 
                                max: 1.0,
                                onChanged: controller.setBrightness,
                              ),
                            ),
                            const Icon(Icons.brightness_high, size: 20),
                          ],
                        ),
                        
                        const Divider(),

                        // Font Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                             // Size
                             Row(
                               children: [
                                 const Icon(Icons.text_fields, size: 18),
                                 IconButton(
                                   icon: const Icon(Icons.remove),
                                   onPressed: () => controller.setFontSize(controller.fontSize - 1),
                                   visualDensity: VisualDensity.compact,
                                 ),
                                 Text(controller.fontSize.toStringAsFixed(0)),
                                 IconButton(
                                   icon: const Icon(Icons.add),
                                   onPressed: () => controller.setFontSize(controller.fontSize + 1),
                                   visualDensity: VisualDensity.compact,
                                 ),
                               ],
                             ),
                             // Height
                             Row(
                               children: [
                                 const Icon(Icons.format_line_spacing, size: 18),
                                 IconButton(
                                   icon: const Icon(Icons.remove),
                                   onPressed: () => controller.setLineHeight(controller.lineHeight - 0.1),
                                   visualDensity: VisualDensity.compact,
                                 ),
                                 Text(controller.lineHeight.toStringAsFixed(1)),
                                 IconButton(
                                   icon: const Icon(Icons.add),
                                   onPressed: () => controller.setLineHeight(controller.lineHeight + 0.1),
                                   visualDensity: VisualDensity.compact,
                                 ),
                               ],
                             ),
                          ],
                        ),
                        
                        const SizedBox(height: 10),
                        
                        // Background Colors
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _colorBtn(controller, const Color(0xFFFAF9F6)), 
                              const SizedBox(width: 12),
                              _colorBtn(controller, const Color(0xFFFFF8E1)), 
                              const SizedBox(width: 12),
                              _colorBtn(controller, const Color(0xFFE0F7FA)), 
                              const SizedBox(width: 12),
                              _colorBtn(controller, const Color(0xFF2E2A3A), isDark: true), 
                              const SizedBox(width: 12),
                              _colorBtn(controller, const Color(0xFF000000), isDark: true), 
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
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.grey.withOpacity(0.5)),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: c.backgroundColor == color 
            ? Icon(Icons.check, color: isDark ? Colors.white : Colors.black) 
            : null,
      ),
    );
  }
}
