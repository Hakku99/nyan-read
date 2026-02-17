import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nyan_read/modules/reader/widgets/reader_menu.dart';
import 'package:nyan_read/core/theme/theme_manager.dart';
import 'package:nyan_read/modules/reader/reader_page.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/models/book.dart';
import 'package:mockito/mockito.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

class MockReaderController extends Mock implements ReaderController {
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
  bool get followSystem => false;

  @override
  Book get book => const Book(
      id: 'test_id',
      title: 'Test Book',
      path: '/test/path',
      format: 'txt',
      size: 1000,
      lastReadPosition: '',
      addedAt: 0);

  @override
  List<dynamic> get chapters => [];

  @override
  int get currentChapterIndex => 0;

  @override
  void seekTo(double value) {}
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
}

class MockThemeManager extends Mock implements ThemeManager {
  @override
  ThemePreset get currentPreset => ThemePreset.creamLight;
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
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ReaderMenu()),
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
