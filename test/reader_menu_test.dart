import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nyan_read/modules/reader/widgets/reader_menu.dart';
import 'package:nyan_read/core/theme/theme_manager.dart';
import 'package:nyan_read/modules/reader/reader_page.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/reader_error.dart';
import 'package:nyan_read/core/models/highlight.dart';
import 'dart:ui';
import 'package:nyan_read/modules/reader/controllers/content_meta_manager.dart';
import 'package:nyan_read/modules/reader/controllers/reader_settings_manager.dart';
import 'package:nyan_read/modules/reader/controllers/reading_progress_manager.dart';
import 'package:nyan_read/core/utils/lifecycle_registry.dart';
import 'mocks/mock_reader_settings_manager.dart';
import 'mocks/mock_content_meta_manager.dart';
import 'mocks/mock_reading_progress_manager.dart';
import 'package:nyan_read/modules/reader/brightness/brightness_orchestrator.dart';
import 'package:nyan_read/modules/reader/brightness/brightness_repository.dart';
import 'package:nyan_read/modules/reader/brightness/system_brightness_adapter.dart';
import 'package:nyan_read/modules/reader/controllers/brightness_controller.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeReadingPosition implements ReadingPosition {
  @override
  String toJson() => '{}';
}

class FakeReaderEngine implements ReaderEngine {
  @override
  Future<void> initialize() async {}

  @override
  Widget buildReader(BuildContext context) => const SizedBox.shrink();

  @override
  Future<void> goToPosition(ReadingPosition position) async {}

  @override
  ReadingPosition? getCurrentPosition() => FakeReadingPosition();

  @override
  void setConfig(ReaderConfig config) {}

  @override
  double? getProgress() => 0.5;

  @override
  Future<void> seekToProgress(double progress) async {}

  @override
  Future<String?> getSnippet() async => null;

  @override
  Future<String?> getTextAtPosition(ReadingPosition position) async => null;

  @override
  Future<List<dynamic>> getChapters() async => const [];

  @override
  Future<void> nextPage() async {}

  @override
  Future<void> previousPage() async {}

  @override
  int getPageCount() => 1;

  @override
  int getCurrentPageIndex() => 0;

  @override
  bool get hasBottomBar => false;

  @override
  void dispose() {}
}

class MockReaderController extends ChangeNotifier
    with WidgetsBindingObserver
    implements ReaderController {
  final ReaderEngine _engine = FakeReaderEngine();

  @override
  late final ReadingProgressManager progressManager;
  @override
  late final ReaderSettingsManager settingsManager;
  @override
  late final ContentMetaManager metaManager;

  MockReaderController() {
    final lifecycle = LifecycleRegistry();
    progressManager = MockReadingProgressManager(
      engine: engine,
      book: book,
      lifecycle: lifecycle,
      onProgressUpdated: () {},
    );
    settingsManager = MockReaderSettingsManager(
      engine: engine,
      lifecycle: lifecycle,
      onSettingsChanged: () {},
    );
    metaManager = MockContentMetaManager(
      engine: engine,
      book: book,
      onMetaChanged: () {},
    );
  }

  @override
  double get currentProgress => 0.5;
  @override
  double get brightness => 0.8;
  @override
  double get warmth => 0.3;
  @override
  double get fontSize => 18.0;
  @override
  double get lineHeight => 1.5;
  @override
  Color get backgroundColor => Colors.white;
  @override
  Color get textColor => Colors.black;
  @override
  bool get followSystem => false;
  @override
  Book get book => Book(
      id: 'test_id',
      title: 'Test Book',
      format: 'txt',
      author: 'Test Author',
      filePath: '/test/path');

  @override
  List<dynamic> get chapters => [];

  @override
  int get currentChapterIndex => 0;

  @override
  Future<void> seekTo(double value) async {}
  @override
  Future<void> setBrightness(double value) async {}
  @override
  Future<void> setWarmth(double value) async {}
  @override
  void setFontSize(double value) {}
  @override
  void setLineHeight(double value) {}
  @override
  Future<bool> addBookmark() async => true;
  @override
  Future<void> loadHighlights() async {}
  @override
  Future<void> openHighlight(Highlight highlight) async {}
  @override
  Future<void> toggleFollowSystem() async {}
  @override
  Future<void> jumpToPreviousChapter() async {}
  @override
  Future<void> jumpToNextChapter() async {}
  @override
  Future<void> refreshCurrentChapterIndex() async {}
  @override
  Future<void> init() async {}
  @override
  Future<void> nextPage() async {}
  @override
  Future<void> previousPage() async {}
  @override
  Future<void> jumpToChapter(int index, dynamic chapter) async {}
  @override
  Future<void> retry() async {}
  @override
  Future<void> updateHighlight(String id,
      {String? colorCode, String? note}) async {}
  @override
  Future<void> deleteHighlight(String id) async {}
  @override
  void didChangeAccessibilityFeatures() {}
  @override
  void didChangeLocales(List<Locale>? locales) {}
  @override
  void didChangeMetrics() {}
  @override
  void didChangePlatformBrightness() {}
  @override
  void didChangeTextScaleFactor() {}

  @override
  Future<void> addHighlight(int paragraphIndex, int start, int end, String text,
      String colorCode, String paragraphText) async {}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  @override
  void handleLayoutChange(Size size) {}

  @override
  Future<void> handleBookmarkSelection(Map<String, dynamic> bookmarkData) async {}

  @override
  Future<Highlight?> handleHighlightSelection(Highlight highlight) async =>
      highlight;

  @override
  Future<void> restorePosition(Map<String, dynamic> bookmarkData) async {}

  @override
  set engine(ReaderEngine engine) {}

  @override
  ReaderEngine get engine => _engine;

  @override
  ReaderErrorState? get errorState => null;

  @override
  void attachBrightnessController(dynamic bc) {}

  @override
  Future<void> saveBeforeExit() async {}

  @override
  void setBackground(Color color) {}

  @override
  List<Highlight> get highlights => [];

  @override
  Future<bool> didPopRoute() => Future.value(false);
  @override
  Future<bool> didPushRoute(String route) => Future.value(false);
  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) =>
      Future.value(false);
  @override
  Future<AppExitResponse> didRequestAppExit() async => AppExitResponse.cancel;
  @override
  void handleCancelBackGesture() {}
  @override
  void handleCommitBackGesture() {}
  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) => false;
  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {}
  @override
  void didHaveMemoryPressure() {}
}

class MockThemeManager extends ChangeNotifier implements ThemeManager {
  @override
  ThemePreset get currentPreset => ThemePreset.creamLight;
  @override
  ThemeData get currentThemeData => ThemeData.light();
  @override
  ThemeData get darkTheme => ThemeData.dark();
  @override
  ThemeData get lightTheme => ThemeData.light();
  @override
  ThemeMode get themeMode => ThemeMode.light;

  @override
  Future<void> init() async {}
  @override
  Future<void> setPreset(ThemePreset preset) async {}
}

class FakeSystemBrightnessAdapter extends SystemBrightnessAdapter {
  FakeSystemBrightnessAdapter({this.currentValue = 0.5});

  double currentValue;

  @override
  Future<double> currentBrightness() async => currentValue;

  @override
  Stream<double> brightnessChanges() => const Stream<double>.empty();

  @override
  Future<void> setSystemBrightness(double brightness) async {
    currentValue = brightness;
  }

  @override
  Future<void> resetSystemBrightness() async {
    currentValue = 0.5;
  }
}

void main() {
  testWidgets('ReaderMenu renders brightness controls',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = ReaderPreferencesService();
    await prefs.initialize();
    final brightnessController = BrightnessController(
      BrightnessOrchestrator(
        repository: BrightnessRepository(prefs),
        systemAdapter: FakeSystemBrightnessAdapter(),
      ),
    );

    final mockController = MockReaderController();
    final mockThemeManager = MockThemeManager();

    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ReaderController>.value(value: mockController),
          ChangeNotifierProvider<ThemeManager>.value(value: mockThemeManager),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            key: scaffoldKey,
            body: ReaderMenu(
              scaffoldKey: scaffoldKey,
              brightnessController: brightnessController,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

        expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
    expect(find.byIcon(Icons.brightness_auto), findsOneWidget);
    expect(find.byType(Slider), findsWidgets);
  });

  testWidgets('ReaderMenu shows closeable bookmark feedback',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = ReaderPreferencesService();
    await prefs.initialize();
    final brightnessController = BrightnessController(
      BrightnessOrchestrator(
        repository: BrightnessRepository(prefs),
        systemAdapter: FakeSystemBrightnessAdapter(),
      ),
    );

    final mockController = MockReaderController();
    final mockThemeManager = MockThemeManager();
    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ReaderController>.value(value: mockController),
          ChangeNotifierProvider<ThemeManager>.value(value: mockThemeManager),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            key: scaffoldKey,
            body: ReaderMenu(
              scaffoldKey: scaffoldKey,
              brightnessController: brightnessController,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final bookmarkButton = find.byIcon(Icons.bookmark_border_rounded);
    await tester.ensureVisible(bookmarkButton);
    await tester.pumpAndSettle();

    await tester.tap(bookmarkButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Bookmark Added!'), findsOneWidget);
    final closeButton = find.byIcon(Icons.close);
    expect(closeButton, findsOneWidget);

    await tester.ensureVisible(closeButton);
    await tester.pumpAndSettle();
    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    expect(find.text('Bookmark Added!'), findsNothing);
  });

}






