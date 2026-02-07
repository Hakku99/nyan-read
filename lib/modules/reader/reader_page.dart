import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/book.dart';
import '../../core/services/database_service.dart';
import '../../core/services/reader_preferences_service.dart';
import '../../core/utils/layout_debouncer.dart';
import '../bookmark/bookmark_list_page.dart';
import 'reader_engine/reader_engine.dart';
import 'reader_engine/reader_factory.dart';
import 'reader_engine/epub/epub_position.dart';
import 'reader_engine/txt/txt_position.dart';

import 'reader_engine/pdf/pdf_position.dart';
import 'reader_error.dart';
import 'widgets/reader_error_view.dart';
import 'widgets/chapter_list_widget.dart';
import 'dart:async';
import 'dart:io';

class ReaderController extends ChangeNotifier with WidgetsBindingObserver {
  final Book book;
  late ReaderEngine engine;

  double _fontSize = 18.0;
  double _lineHeight = 1.5;
  double _brightness = 1.0;
  Color _backgroundColor = const Color(0xFFFAF9F6);
  Color _textColor = Colors.black87;
  Timer? _reminderTimer;
  Timer? _progressTimer;
  Timer? _autoSaveTimer;
  int _readSeconds = 0;
  bool _showControls = false;
  double _currentProgress = 0.0;
  ReaderErrorState? _errorState;
  List<dynamic> _chapters = [];
  int? _currentChapterIndex;
  final Debouncer _layoutDebouncer =
      Debouncer(delay: const Duration(milliseconds: 300));
  Size? _lastLayoutSize;

  ReaderController(this.book) {
    engine = ReaderEngineFactory.create(book);
    _updateEngineConfig();
    WidgetsBinding.instance.addObserver(this);
  }

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  double get brightness => _brightness;
  Color get backgroundColor => _backgroundColor;
  Color get textColor => _textColor;
  bool get showControls => _showControls;
  double get currentProgress => _currentProgress;
  ReaderErrorState? get errorState => _errorState;
  List<dynamic> get chapters => _chapters;
  int? get currentChapterIndex => _currentChapterIndex;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveCurrentPosition();
    }
  }

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

      // 加载章节信息
      _chapters = await engine.getChapters();

      // 恢复上次阅读位置
      await _restoreLastPosition();

      // 启动自动保存定时器 (每30秒保存一次,防抖)
      _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _saveCurrentPosition();
      });

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

  Future<void> _restoreLastPosition() async {
    try {
      debugPrint("DEBUG: _restoreLastPosition called for book ${book.id}");
      final positionData = await DatabaseService().getBookPosition(book.id);
      if (positionData == null) {
        debugPrint("DEBUG: No saved position found in DB");
        return;
      }

      final type = positionData['position_type'] as String;
      final payload = positionData['position_payload'] as String;
      debugPrint("DEBUG: RESTORING position: type=$type, payload=$payload");

      ReadingPosition? position;
      if (type == 'epub') {
        position = EpubReadingPosition.fromJson(payload);
      } else if (type == 'pdf') {
        position = PdfReadingPosition.fromJson(payload);
      } else if (type == 'txt') {
        position = TxtReadingPosition.fromJson(payload);
      }

      if (position != null) {
        await engine.goToPosition(position);
        debugPrint("DEBUG: Position restored to engine successfully");
      }
    } catch (e) {
      debugPrint('Error restoring position: $e');
    }
  }

  Future<void> _saveCurrentPosition() async {
    try {
      final position = engine.getCurrentPosition();
      debugPrint(
          "DEBUG: _saveCurrentPosition called. Engine returned: ${position?.toJson()}");

      if (position != null) {
        await DatabaseService().updateBookPosition(
          book.id,
          book.format,
          position.toJson(),
        );
        debugPrint("DEBUG: Position saved to DB");
      } else {
        debugPrint("DEBUG: Engine returned null position, NOT saving.");
      }
    } catch (e) {
      debugPrint('Error saving position: $e');
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
    } else if (_backgroundColor.value == 0xFF2E2A3A ||
        _backgroundColor.value == 0xFF000000) {
      // Midnight Blue or Black
      _textColor = Colors.white;
    } else {
      // Fallback luminance check
      _textColor = _backgroundColor.computeLuminance() > 0.5
          ? Colors.black
          : Colors.white;
    }

    final prefs = ReaderPreferencesService.instance;
    engine.setConfig(ReaderConfig(
      backgroundColor: _backgroundColor,
      textColor: _textColor,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      pageTurnMode: prefs.pageTurnMode,
      pageAnimation: prefs.pageAnimation,
    ));
  }

  bool get shouldShowReminder => _readSeconds > 0 && _readSeconds % 3600 == 0;

  void toggleControls() {
    _showControls = !_showControls;
    if (_showControls) {
      _syncProgress();
      _progressTimer =
          Timer.periodic(const Duration(seconds: 1), (_) => _syncProgress());
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
    await _saveCurrentPosition(); // 保存进度
  }

  Future<void> jumpToChapter(int index, dynamic chapterData) async {
    try {
      _currentChapterIndex = index;

      // 根据不同格式跳转
      if (book.format == 'epub' && chapterData['anchor'] != null) {
        final cfi = chapterData['anchor'] as String;
        await engine.goToPosition(EpubReadingPosition(cfi: cfi));
      } else if (book.format == 'txt' &&
          chapterData['paragraphIndex'] != null) {
        final paragraphIndex = chapterData['paragraphIndex'] as int;
        await engine
            .goToPosition(TxtReadingPosition(paragraphIndex: paragraphIndex));
      } else if (book.format == 'pdf' && chapterData['pageNumber'] != null) {
        final pageNumber = chapterData['pageNumber'] as int;
        await engine.goToPosition(PdfReadingPosition(pageNumber: pageNumber));
      }

      await _saveCurrentPosition(); // 保存进度
      notifyListeners();
    } catch (e) {
      debugPrint('Error jumping to chapter: $e');
    }
  }

  Future<void> previousPage() async {
    await engine.previousPage();
  }

  Future<void> nextPage() async {
    await engine.nextPage();
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Bookmark Added!")));
    }
  }

  Future<void> restorePosition(Map<String, dynamic> bookmarkData) async {
    final type =
        (bookmarkData['position_type'] ?? book.format).toString().toLowerCase();
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

  void handleLayoutChange(Size newSize) {
    // Skip if size hasn't changed significantly
    if (_lastLayoutSize != null &&
        (newSize.width - _lastLayoutSize!.width).abs() < 10 &&
        (newSize.height - _lastLayoutSize!.height).abs() < 10) {
      return;
    }

    _lastLayoutSize = newSize;

    // Debounce layout recalculation to avoid excessive updates
    _layoutDebouncer.run(() {
      _recalculateLayout(newSize);
    });
  }

  void _recalculateLayout(Size size) {
    // Adjust font size based on screen width
    // Base width is 800px, scale font size proportionally
    final baseFontSize = 18.0;
    final scaleFactor = (size.width / 800).clamp(0.7, 1.5);
    final adjustedFontSize = (baseFontSize * scaleFactor).clamp(12.0, 32.0);

    if ((adjustedFontSize - _fontSize).abs() > 1.0) {
      _fontSize = adjustedFontSize;
      _updateEngineConfig();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _saveCurrentPosition(); // 最后保存一次
    _reminderTimer?.cancel();
    _progressTimer?.cancel();
    _autoSaveTimer?.cancel();
    _layoutDebouncer.dispose();
    WidgetsBinding.instance.removeObserver(this);
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

          // Handle errors
          if (controller.errorState != null) {
            return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: ReaderErrorView(
                errorState: controller.errorState!,
                onBack: () => Navigator.pop(context),
                onRetry: controller.retry,
              ),
            );
          }

          // Show reading reminder if needed
          if (controller.shouldShowReminder) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("ฅ^•ﻌ•^ฅ"),
                  content: const Text(
                      "You've been reading for an hour! Time to stretch."),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"))
                  ],
                ),
              );
            });
          }

          return Scaffold(
            backgroundColor: controller.backgroundColor,
            body: Stack(
              children: [
                // Content Area with Tap Zones
                GestureDetector(
                  onTapUp: (details) {
                    final screenHeight = MediaQuery.of(context).size.height;
                    final tapY = details.globalPosition.dy;

                    // Divide screen into 3 vertical zones:
                    // Top (0-45%): Previous
                    // Middle (45-55%): Menu (10% height)
                    // Bottom (55-100%): Next
                    if (tapY < screenHeight * 0.45) {
                      // Top zone - Previous page
                      controller.previousPage();
                    } else if (tapY > screenHeight * 0.55) {
                      // Bottom zone - Next page
                      controller.nextPage();
                    } else {
                      // Center zone - Toggle controls
                      controller.toggleControls();
                    }
                  },
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
                      child: SafeArea(
                        child: controller.engine.buildReader(context),
                      ),
                    ),
                  ),
                ),

                // Brightness Overlay (Dimmer)
                IgnorePointer(
                  child: Container(
                    color:
                        Colors.black.withOpacity(1.0 - controller.brightness),
                  ),
                ),

                // Top Toolbar
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  top: controller.showControls ? 0 : -100,
                  left: 0,
                  right: 0,
                  child: AppBar(
                    backgroundColor: theme.primaryColor,
                    title:
                        Text(book.title, style: const TextStyle(fontSize: 16)),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.list),
                        tooltip: 'Table of Contents',
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => DraggableScrollableSheet(
                              initialChildSize: 0.6,
                              minChildSize: 0.3,
                              maxChildSize: 0.9,
                              builder: (context, scrollController) =>
                                  ChapterListWidget(
                                chapters: controller.chapters,
                                currentChapterIndex:
                                    controller.currentChapterIndex,
                                currentProgress: controller.currentProgress,
                                onChapterTap: (index, chapterData) {
                                  Navigator.pop(context);
                                  controller.jumpToChapter(index, chapterData);
                                },
                              ),
                            ),
                          );
                        },
                      ),
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
                                  builder: (_) => BookmarkListPage(
                                      bookId: book.id, bookTitle: book.title)));
                          if (result != null &&
                              result is Map<String, dynamic>) {
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
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            spreadRadius: 2)
                      ],
                    ),
                    padding: EdgeInsets.fromLTRB(
                        16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress
                        Row(
                          children: [
                            SizedBox(
                                width: 40,
                                child: Text(
                                    "${(controller.currentProgress * 100).toInt()}%",
                                    style: const TextStyle(fontSize: 12))),
                            Expanded(
                              child: Slider(
                                value: controller.currentProgress,
                                min: 0.0,
                                max: 1.0,
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
                                  onPressed: () => controller
                                      .setFontSize(controller.fontSize - 1),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Text(controller.fontSize.toStringAsFixed(0)),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () => controller
                                      .setFontSize(controller.fontSize + 1),
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
                                  onPressed: () => controller.setLineHeight(
                                      controller.lineHeight - 0.1),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Text(controller.lineHeight.toStringAsFixed(1)),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () => controller.setLineHeight(
                                      controller.lineHeight + 0.1),
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
                              _colorBtn(controller, const Color(0xFF2E2A3A),
                                  isDark: true),
                              const SizedBox(width: 12),
                              _colorBtn(controller, const Color(0xFF000000),
                                  isDark: true),
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.grey.withOpacity(0.5)),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: c.backgroundColor == color
            ? Icon(Icons.check, color: isDark ? Colors.white : Colors.black)
            : null,
      ),
    );
  }
}
