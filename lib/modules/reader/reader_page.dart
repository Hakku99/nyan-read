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
  Color _backgroundColor = const Color(0xFFFDFCF8); // Default Cream Paper
  Color _textColor = const Color(0xFF4A453E); // Default Sumi Ink
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
    // Determine text color based on background luminance
    // Japanese Cream constraints: No pure black on large surfaces if possible, but for text strict contrast is needed.
    // However, we can use the sumi ink color for light backgrounds.

    final bg = _backgroundColor;
    // Check for Dark Mode backgrounds
    bool isDark = bg.computeLuminance() < 0.5;

    if (isDark) {
      _textColor = const Color(0xFFE6E2D8); // Cream White
    } else {
      _textColor = const Color(0xFF4A453E); // Sumi Ink
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
      child: Builder(
        builder: (context) {
          // Selector for background color prevents rebuilding Scaffold on progress changes
          return Selector<ReaderController, Color>(
            selector: (_, c) => c.backgroundColor,
            builder: (context, bgColor, _) {
              return Scaffold(
                backgroundColor: bgColor,
                resizeToAvoidBottomInset: false,
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Reader Content - Rebuilds when controller notifies
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) => _handleTap(context, details),
                        child: Consumer<ReaderController>(
                          builder: (context, controller, _) {
                            // Debug the constraints passed to reader
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                debugPrint(
                                    "DEBUG READER_PAGE: LayoutBuilder constraints: maxWidth=${constraints.maxWidth}, maxHeight=${constraints.maxHeight}");
                                final padding = MediaQuery.of(context).padding;
                                return Padding(
                                  padding: EdgeInsets.only(
                                    top: padding.top,
                                    bottom: padding.bottom,
                                  ),
                                  child: controller.engine.buildReader(context),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),

                    // 2. Error View
                    Selector<ReaderController, ReaderErrorState?>(
                      selector: (_, c) => c.errorState,
                      builder: (context, errorState, _) {
                        if (errorState == null) return const SizedBox.shrink();
                        // Wrap in Positioned.fill to ensure it has size in the Stack
                        return Positioned.fill(
                          child: Container(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: ReaderErrorView(
                              errorState: errorState,
                              onBack: () => Navigator.pop(context),
                              onRetry: () =>
                                  context.read<ReaderController>().retry(),
                            ),
                          ),
                        );
                      },
                    ),

                    // 3. UI Overlays (AppBar, Status Bar, Bottom Panel) - Rebuilds on showControls notify
                    Positioned.fill(child: Consumer<ReaderController>(
                      builder: (context, controller, child) {
                        // Check if we should show controls (engine is always present)
                        final theme = Theme.of(context);
                        final topPadding = MediaQuery.of(context).padding.top;

                        return Stack(
                          children: [
                            // Status Bar Helper
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: topPadding,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: controller.showControls ? 1.0 : 0.0,
                                child: Container(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.95)),
                              ),
                            ),

                            // Top Toolbar
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 200),
                              top: controller.showControls ? 0 : -100,
                              left: 0,
                              right: 0,
                              height: kToolbarHeight +
                                  topPadding, // Explicit height to prevent layout errors
                              child: AppBar(
                                backgroundColor:
                                    theme.colorScheme.primary.withOpacity(0.95),
                                elevation: 0,
                                primary: true, // Use internal padding
                                bottom: PreferredSize(
                                  preferredSize: const Size.fromHeight(1),
                                  child: Divider(
                                      height: 1,
                                      thickness: 1,
                                      color:
                                          theme.dividerColor.withOpacity(0.2)),
                                ),
                                title: Text(book.title,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onPrimary
                                          .withOpacity(0.9),
                                    )),
                                iconTheme: IconThemeData(
                                    color: theme.colorScheme.onPrimary),
                                actions: [
                                  IconButton(
                                    icon: const Icon(Icons.list),
                                    tooltip: 'Table of Contents',
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) => GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => Navigator.pop(context),
                                          child: DraggableScrollableSheet(
                                            initialChildSize: 0.6,
                                            minChildSize: 0.3,
                                            maxChildSize: 0.9,
                                            builder:
                                                (context, scrollController) =>
                                                    GestureDetector(
                                              onTap:
                                                  () {}, // Prevent dismissal when tapping content
                                              child: ChapterListWidget(
                                                chapters: controller.chapters,
                                                currentChapterIndex: controller
                                                    .currentChapterIndex,
                                                currentProgress:
                                                    controller.currentProgress,
                                                scrollController:
                                                    scrollController,
                                                onChapterTap:
                                                    (index, chapterData) {
                                                  Navigator.pop(context);
                                                  controller.jumpToChapter(
                                                      index, chapterData);
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon:
                                        const Icon(Icons.bookmark_add_outlined),
                                    onPressed: () =>
                                        controller.addBookmark(context),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.bookmarks),
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => BookmarkListPage(
                                                  bookId: book.id,
                                                  bookTitle: book.title)));
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
                              bottom: controller.showControls ? 0 : -400,
                              left: 0,
                              right: 0,
                              child: SafeArea(
                                bottom: true,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16)),
                                    border: Border(
                                        top: BorderSide(
                                            color: theme.dividerColor)),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Progress
                                      Row(
                                        children: [
                                          Text(
                                              "${(controller.currentProgress * 100).toInt()}%",
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withOpacity(0.7))),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: SliderTheme(
                                              data: SliderTheme.of(context)
                                                  .copyWith(
                                                trackHeight: 4,
                                                thumbShape:
                                                    const RoundSliderThumbShape(
                                                        enabledThumbRadius: 8),
                                                overlayShape:
                                                    const RoundSliderOverlayShape(
                                                        overlayRadius: 16),
                                                activeTrackColor:
                                                    theme.colorScheme.primary,
                                                inactiveTrackColor: theme
                                                    .colorScheme.primary
                                                    .withOpacity(0.3),
                                                thumbColor:
                                                    theme.colorScheme.primary,
                                              ),
                                              child: Slider(
                                                value:
                                                    controller.currentProgress,
                                                min: 0.0,
                                                max: 1.0,
                                                onChanged: (val) =>
                                                    controller.seekTo(val),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Divider(
                                          height: 1,
                                          color: theme.dividerColor
                                              .withOpacity(0.2)),
                                      const SizedBox(height: 12),

                                      // Brightness
                                      Row(
                                        children: [
                                          Icon(Icons.brightness_low,
                                              size: 20,
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.6)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: SliderTheme(
                                              data: SliderTheme.of(context)
                                                  .copyWith(
                                                trackHeight: 4,
                                                thumbShape:
                                                    const RoundSliderThumbShape(
                                                        enabledThumbRadius: 8),
                                                activeTrackColor:
                                                    theme.colorScheme.primary,
                                                inactiveTrackColor: theme
                                                    .colorScheme.primary
                                                    .withOpacity(0.3),
                                                thumbColor:
                                                    theme.colorScheme.primary,
                                              ),
                                              child: Slider(
                                                value: controller.brightness,
                                                min: 0.2,
                                                max: 1.0,
                                                onChanged:
                                                    controller.setBrightness,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Icon(Icons.brightness_high,
                                              size: 20,
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.6)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Divider(
                                          height: 1,
                                          color: theme.dividerColor
                                              .withOpacity(0.2)),
                                      const SizedBox(height: 12),

                                      // Typography
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Font Size
                                          Row(
                                            children: [
                                              Icon(Icons.format_size,
                                                  size: 20,
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withOpacity(0.6)),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons
                                                    .remove_circle_outline),
                                                onPressed: () =>
                                                    controller.setFontSize(
                                                        controller.fontSize -
                                                            1),
                                                color:
                                                    theme.colorScheme.primary,
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                              SizedBox(
                                                  width: 30,
                                                  child: Text(
                                                      controller.fontSize
                                                          .toStringAsFixed(0),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight
                                                              .w600))),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.add_circle_outline),
                                                onPressed: () =>
                                                    controller.setFontSize(
                                                        controller.fontSize +
                                                            1),
                                                color:
                                                    theme.colorScheme.primary,
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            ],
                                          ),
                                          // Line Height
                                          Row(
                                            children: [
                                              Icon(Icons.format_line_spacing,
                                                  size: 20,
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withOpacity(0.6)),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons
                                                    .remove_circle_outline),
                                                onPressed: () =>
                                                    controller.setLineHeight(
                                                        controller.lineHeight -
                                                            0.1),
                                                color:
                                                    theme.colorScheme.primary,
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                              SizedBox(
                                                  width: 30,
                                                  child: Text(
                                                      controller.lineHeight
                                                          .toStringAsFixed(1),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight
                                                              .w600))),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.add_circle_outline),
                                                onPressed: () =>
                                                    controller.setLineHeight(
                                                        controller.lineHeight +
                                                            0.1),
                                                color:
                                                    theme.colorScheme.primary,
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Divider(
                                          height: 1,
                                          color: theme.dividerColor
                                              .withOpacity(0.2)),
                                      const SizedBox(height: 16),

                                      // Themes
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _colorBtn(context, controller,
                                                const Color(0xFFFDFCF8)),
                                            const SizedBox(width: 16),
                                            _colorBtn(context, controller,
                                                const Color(0xFFF5F5DC)),
                                            const SizedBox(width: 16),
                                            _colorBtn(context, controller,
                                                const Color(0xFF262422),
                                                isDark: true),
                                            const SizedBox(width: 16),
                                            _colorBtn(context, controller,
                                                const Color(0xFF1C1B1A),
                                                isDark: true),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    )),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _handleTap(BuildContext context, TapUpDetails details) {
    final controller = context.read<ReaderController>();
    if (controller.showControls) {
      controller.toggleControls();
      return;
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final tapY = details.globalPosition.dy;

    if (tapY < screenHeight * 0.45) {
      controller.previousPage();
    } else if (tapY > screenHeight * 0.55) {
      controller.nextPage();
    } else {
      controller.toggleControls();
    }
  }

  Widget _colorBtn(BuildContext context, ReaderController c, Color color,
      {bool isDark = false}) {
    final isSelected = c.backgroundColor.value == color.value;

    return GestureDetector(
      onTap: () => c.setBackground(color),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: isSelected ? 1.2 : 1.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).dividerColor.withOpacity(0.5),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: isSelected
                  ? Icon(Icons.check,
                      color: isDark ? Colors.white : Colors.black, size: 20)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
