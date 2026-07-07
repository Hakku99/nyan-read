import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/modules/reader/widgets/reader_menu.dart';
import 'package:nyan_read/core/ui/components/nyan_overlay_style.dart';
import 'package:nyan_read/core/ui/components/nyan_switch.dart';
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

class FakeReadingPosition extends ReadingPosition {
  const FakeReadingPosition();

  @override
  String toJson() => '{}';
}

class FakeReaderEngine
    implements ReaderEngine, TextExtractionCapability, PageMetricsCapability {
  FakeReaderEngine({
    this.capabilities = const ReaderCapabilities(
      typography: CapabilityLevel.full,
      theme: CapabilityLevel.full,
      highlights: CapabilityLevel.full,
      annotations: CapabilityLevel.full,
      pageAnimation: CapabilityLevel.none,
      chapterNavigation: ReaderChapterNavigation.semantic,
    ),
  });

  @override
  final ReaderCapabilities capabilities;

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
  Future<List<ReaderChapter>> getChapters() async => const [];

  @override
  Future<void> goToChapter(ChapterLocator locator) async {}

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
  final ReaderEngine _engine;

  @override
  late final ReadingProgressManager progressManager;
  @override
  late final ReaderSettingsManager settingsManager;
  @override
  late final ContentMetaManager metaManager;

  MockReaderController({ReaderEngine? engine})
      : _engine = engine ?? FakeReaderEngine() {
    final lifecycle = LifecycleRegistry();
    progressManager = MockReadingProgressManager(
      engine: _engine,
      book: book,
      lifecycle: lifecycle,
      onProgressUpdated: () {},
    );
    settingsManager = MockReaderSettingsManager(
      engine: _engine,
      lifecycle: lifecycle,
      onSettingsChanged: () {},
    );
    metaManager = MockContentMetaManager(
      engine: _engine,
      book: book,
      onMetaChanged: () {},
    );
  }

  @override
  double get currentProgress => 0.5;
  @override
  ValueListenable<double> get progressListenable =>
      progressManager.progressListenable;
  @override
  int get renderEpoch => 0;
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
  ReaderCapabilities get capabilities => _engine.capabilities;
  @override
  Book get book => Book(
      id: 'test_id',
      title: 'Test Book',
      format: 'txt',
      author: 'Test Author',
      filePath: '/test/path');

  @override
  List<ReaderChapter> get chapters => const [];

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
  Future<void> syncChapterAfterScroll() async {}
  @override
  Future<void> init() async {}
  @override
  Future<void> nextPage() async {}
  @override
  Future<void> previousPage() async {}
  @override
  Future<void> jumpToChapter(int index, ChapterLocator locator) async {}
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
  Future<void> handleBookmarkSelection(
      Map<String, dynamic> bookmarkData) async {}

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
  void setPageTurnMode(PageTurnMode mode) {}

  @override
  void setUseSerif(bool value) {}

  @override
  List<Highlight> get highlights => [];

  bool resetDisplayCalled = false;

  @override
  Future<void> resetReaderAppearanceDefaults() async {}

  @override
  Future<void> resetReaderDisplayDefaults() async {
    resetDisplayCalled = true;
  }

  @override
  void resetReaderTextDefaults() {}

  @override
  void resetReaderThemeDefaults() {}

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
  NyanTheme get currentNyanTheme => themePresets[currentPreset]!;
  @override
  ThemeData get currentThemeData => currentNyanTheme.themeData;
  @override
  ThemeData get darkTheme => currentThemeData;
  @override
  ThemeData get lightTheme => currentThemeData;
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
    await brightnessController.initialize();

    final mockController = MockReaderController();
    final mockThemeManager = MockThemeManager();

    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      MaterialApp(
          theme: mockThemeManager.currentThemeData,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            key: scaffoldKey,
            body: ReaderMenu(
              controller: mockController,
              scaffoldKey: scaffoldKey,
              brightnessController: brightnessController,
            ),
          ),
      ),
    );

    await tester.pumpAndSettle();

    final loc = AppLocalizations.of(tester.element(find.byType(ReaderMenu)))!;

    expect(find.text(loc.readingSettings), findsWidgets);
    expect(find.text('Reset Display'), findsOneWidget);
    expect(find.byIcon(NyanIcons.refresh), findsOneWidget);
    // One Paper display panel: brightness knob with slider + follow-system
    // switch (the old sun icon / Auto chip moved to the top-bar popover).
    expect(find.text(loc.readerBrightness), findsOneWidget);
    expect(find.text(loc.readerFollowSystemBrightness), findsOneWidget);
    expect(find.byType(NyanSwitch), findsOneWidget);
    expect(find.text(loc.fontSize), findsNothing);
    expect(find.text(loc.themeCream), findsNothing);
    expect(find.byType(Slider), findsWidgets);
  });

  testWidgets('ReaderMenu switches between compact setting panels',
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
    await brightnessController.initialize();

    final mockController = MockReaderController();
    final mockThemeManager = MockThemeManager();
    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      MaterialApp(
          theme: mockThemeManager.currentThemeData,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            key: scaffoldKey,
            body: ReaderMenu(
              controller: mockController,
              scaffoldKey: scaffoldKey,
              brightnessController: brightnessController,
            ),
          ),
      ),
    );

    await tester.pumpAndSettle();

    final loc = AppLocalizations.of(tester.element(find.byType(ReaderMenu)))!;

    expect(find.text(loc.readerBrightness), findsOneWidget);
    expect(find.text(loc.fontSize), findsNothing);
    expect(find.text(loc.themeCream), findsNothing);

    await tester.pumpAndSettle();

    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();

    expect(find.text(loc.fontSize), findsOneWidget);
    expect(find.text(loc.lineHeight), findsOneWidget);
    expect(find.text('Reset Text'), findsOneWidget);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    expect(find.text(loc.themeCream), findsOneWidget);
    expect(find.byKey(const Key('reader-menu-theme-grid')), findsOneWidget);
    expect(find.text('Reset Theme'), findsOneWidget);
  });

  testWidgets(
      'ReaderMenu hides unsupported typography theme and notes controls',
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
    await brightnessController.initialize();

    final mockController = MockReaderController(
      engine: FakeReaderEngine(
        capabilities: const ReaderCapabilities(
          typography: CapabilityLevel.none,
          theme: CapabilityLevel.none,
          highlights: CapabilityLevel.none,
          annotations: CapabilityLevel.none,
          pageAnimation: CapabilityLevel.none,
          chapterNavigation: ReaderChapterNavigation.none,
        ),
      ),
    );
    final mockThemeManager = MockThemeManager();
    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      MaterialApp(
          theme: mockThemeManager.currentThemeData,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            key: scaffoldKey,
            body: ReaderMenu(
              controller: mockController,
              scaffoldKey: scaffoldKey,
              brightnessController: brightnessController,
            ),
          ),
      ),
    );

    await tester.pumpAndSettle();

    final loc = AppLocalizations.of(tester.element(find.byType(ReaderMenu)))!;

    expect(find.text('Text'), findsNothing);
    expect(find.text('Theme'), findsNothing);
    expect(find.text(loc.fontSize), findsNothing);
    expect(find.text(loc.lineHeight), findsNothing);
    expect(find.text(loc.themeCream), findsNothing);
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets(
      'ReaderMenu omits chapter chevrons (progress lives on reader overlay)',
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
    await brightnessController.initialize();

    final mockController = MockReaderController(
      engine: FakeReaderEngine(
        capabilities: const ReaderCapabilities(
          typography: CapabilityLevel.none,
          theme: CapabilityLevel.none,
          highlights: CapabilityLevel.none,
          annotations: CapabilityLevel.none,
          pageAnimation: CapabilityLevel.none,
          chapterNavigation: ReaderChapterNavigation.synthetic,
        ),
      ),
    );
    final mockThemeManager = MockThemeManager();
    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      MaterialApp(
          theme: mockThemeManager.currentThemeData,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            key: scaffoldKey,
            body: ReaderMenu(
              controller: mockController,
              scaffoldKey: scaffoldKey,
              brightnessController: brightnessController,
            ),
          ),
      ),
    );

    await tester.pumpAndSettle();

    final loc = AppLocalizations.of(tester.element(find.byType(ReaderMenu)))!;

    expect(find.text('Text'), findsNothing);
    expect(find.text('Theme'), findsNothing);
    expect(find.text(loc.fontSize), findsNothing);
    expect(find.text(loc.lineHeight), findsNothing);
    expect(find.text(loc.themeCream), findsNothing);
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets('ReaderMenu shows capability-gated controls for TXT-like engines',
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
    await brightnessController.initialize();

    final mockController = MockReaderController();
    final mockThemeManager = MockThemeManager();
    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      MaterialApp(
          theme: mockThemeManager.currentThemeData,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            key: scaffoldKey,
            body: ReaderMenu(
              controller: mockController,
              scaffoldKey: scaffoldKey,
              brightnessController: brightnessController,
            ),
          ),
      ),
    );

    await tester.pumpAndSettle();

    final loc = AppLocalizations.of(tester.element(find.byType(ReaderMenu)))!;

    expect(find.text(loc.readerBrightness), findsOneWidget);
    expect(find.text(loc.fontSize), findsNothing);
    expect(find.text(loc.lineHeight), findsNothing);
    expect(find.text(loc.themeCream), findsNothing);
    expect(find.byKey(const Key('reader-menu-theme-grid')), findsNothing);
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();

    expect(find.text(loc.fontSize), findsOneWidget);
    expect(find.text(loc.lineHeight), findsOneWidget);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    expect(find.text(loc.themeCream), findsOneWidget);
    expect(find.byKey(const Key('reader-menu-theme-grid')), findsOneWidget);
  });

  testWidgets('ReaderMenu renders text panel without overflow on narrow phones',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 740);
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
    await brightnessController.initialize();

    final mockController = MockReaderController();
    final mockThemeManager = MockThemeManager();
    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      MaterialApp(
          theme: mockThemeManager.currentThemeData,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            key: scaffoldKey,
            body: ReaderMenu(
              controller: mockController,
              scaffoldKey: scaffoldKey,
              brightnessController: brightnessController,
            ),
          ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();

    final loc = AppLocalizations.of(tester.element(find.byType(ReaderMenu)))!;
    expect(find.text(loc.fontSize), findsOneWidget);
    expect(find.text(loc.lineHeight), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ReaderMenu follow-system switch toggles brightness mode',
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
    await brightnessController.initialize();

    final mockController = MockReaderController();
    final mockThemeManager = MockThemeManager();
    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      MaterialApp(
          theme: mockThemeManager.currentThemeData,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            key: scaffoldKey,
            body: ReaderMenu(
              controller: mockController,
              scaffoldKey: scaffoldKey,
              brightnessController: brightnessController,
            ),
          ),
      ),
    );

    await tester.pumpAndSettle();

    // Follow-system is the default mode (BrightnessState initial state).
    final initial = brightnessController.followSystem;
    expect(tester.widget<NyanSwitch>(find.byType(NyanSwitch)).value, initial);
    await tester.tap(find.byType(NyanSwitch));
    await tester.pumpAndSettle();
    expect(brightnessController.followSystem, !initial);
    expect(
        tester.widget<NyanSwitch>(find.byType(NyanSwitch)).value, !initial);
  });

  testWidgets('ReaderMenu keeps reset visible on common phone heights',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
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
    await brightnessController.initialize();

    final mockController = MockReaderController();
    final mockThemeManager = MockThemeManager();
    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      MaterialApp(
          theme: mockThemeManager.currentThemeData,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            key: scaffoldKey,
            body: ReaderMenu(
              controller: mockController,
              scaffoldKey: scaffoldKey,
              brightnessController: brightnessController,
            ),
          ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Reset Display'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reader settings sheet dismisses on barrier tap',
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
    await brightnessController.initialize();

    final mockController = MockReaderController();
    final mockThemeManager = MockThemeManager();
    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      MaterialApp(
          theme: mockThemeManager.currentThemeData,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      isDismissible: true,
                      enableDrag: true,
                      backgroundColor: Colors.transparent,
                      barrierColor: NyanOverlayStyle.modalBarrierColor(context),
                      builder: (_) => FractionallySizedBox(
                        heightFactor: 0.68,
                        alignment: Alignment.bottomCenter,
                        child: ReaderMenu(
                          controller: mockController,
                          scaffoldKey: scaffoldKey,
                          brightnessController: brightnessController,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open settings'),
                );
              },
            ),
          ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderMenu), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(ReaderMenu), findsNothing);
  });

  testWidgets('ReaderMenu reset button resets the current section',
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
    await brightnessController.initialize();

    final mockController = MockReaderController();
    final mockThemeManager = MockThemeManager();
    final scaffoldKey = GlobalKey<ScaffoldState>();

    await tester.pumpWidget(
      MaterialApp(
          theme: mockThemeManager.currentThemeData,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            key: scaffoldKey,
            body: ReaderMenu(
              controller: mockController,
              scaffoldKey: scaffoldKey,
              brightnessController: brightnessController,
            ),
          ),
      ),
    );

    await tester.pumpAndSettle();
    // One Paper design: per-section reset, applied directly without a
    // confirmation dialog (the old global "Reset all" dialog was removed).
    await tester.tap(find.text('Reset Display'));
    await tester.pumpAndSettle();

    expect(mockController.resetDisplayCalled, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
