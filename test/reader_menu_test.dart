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

class MockReaderController extends ChangeNotifier
    with WidgetsBindingObserver
    implements ReaderController {
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
  bool get showControls => true;
  @override
  bool get isPanning => false;
  @override
  Offset? get tapDownPosition => null;
  @override
  @override
  bool get isAdjustingBrightness => false;

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
  void setFontSize(double value) {}
  @override
  void setLineHeight(double value) {}
  @override
  Future<void> addBookmark(BuildContext context) async {}
  @override
  Future<void> loadHighlights() async {}
  @override
  Future<void> toggleFollowSystem() async {}
  @override
  Future<void> jumpToPreviousChapter() async {}
  @override
  Future<void> jumpToNextChapter() async {}
  @override
  Future<void> init() async {}
  @override
  void toggleControls() {}
  @override
  Future<void> nextPage() async {}
  @override
  Future<void> previousPage() async {}
  @override
  void setTapDownPosition(Offset pos) {}
  @override
  void updatePanPosition(Offset pos) {}
  @override
  void resetPanState() {}
  @override
  Future<void> jumpToChapter(int index, dynamic chapter) async {}
  @override
  Future<void> retry() async {}
  @override
  void showNoteDialog(BuildContext context, dynamic highlight) {}
  @override
  Future<void> updateHighlight(String id,
      {String? colorCode, String? note}) async {}
  @override
  Future<void> deleteHighlight(String id) async {}
  @override
  void updateProgress(double progress) {}
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
  Future<void> addHighlight(int start, int end, int colorValue,
      String chapterId, String note) async {}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  @override
  void handleLayoutChange(Size size) {}

  @override
  Future<void> restorePosition(Map<String, dynamic> bookmarkData) async {}

  @override
  set engine(ReaderEngine engine) {}

  @override
  ReaderEngine get engine => throw UnimplementedError('Mock engine');

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
  Function(Offset)? get onContentTapDelegate => null;

  @override
  set onContentTapDelegate(Function(Offset)? delegate) {}

  @override
  Function(Highlight)? get onShowNoteDialog => null;

  @override
  set onShowNoteDialog(Function(Highlight)? delegate) {}

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

void main() {
  testWidgets('ReaderMenu has correct styling for Cream Light theme',
      (WidgetTester tester) async {
    final mockController = MockReaderController();
    final mockThemeManager = MockThemeManager();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ReaderController>.value(value: mockController),
          Provider<ThemeManager>.value(value: mockThemeManager),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
              body: ReaderMenu(scaffoldKey: GlobalKey<ScaffoldState>())),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Panel Decoration
    final containerFinder = find.byType(Container).first;
    final container = tester.widget<Container>(containerFinder);
    final decoration = container.decoration as BoxDecoration;

    expect(decoration.color, const Color(0xFFFAF9F6),
        reason: 'Panel background should be Cream+');
    expect((decoration.border as Border).top.color, const Color(0xFFD8D4C8),
        reason: 'Panel border should be solid beige');

    // Verify Control Island (The one wrapping typography)
    final islandFinder = find.byWidgetPredicate((widget) =>
        widget is Container &&
        (widget.decoration as BoxDecoration?)?.color ==
            const Color(0xFFF2F0EB));
    expect(islandFinder, findsOneWidget, reason: 'Control Island should exist');

    // Verify Stepper Button (White BG)
    final stepperBtnFinder = find.byWidgetPredicate((widget) =>
        widget is Container &&
        (widget.decoration as BoxDecoration?)?.color == Colors.white);
    expect(stepperBtnFinder, findsNWidgets(2),
        reason: 'Two white stepper inputs should exist');
  });
}
