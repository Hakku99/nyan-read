import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/reader/widgets/one_paper_dock.dart';

void main() {
  final preset = themePresets[ThemePreset.creamLight]!;

  Future<void> pumpFooter(
    WidgetTester tester, {
    required int chapterIndex,
    required int chapterCount,
    bool sheetOpen = false,
    double progress = 0.42,
    DockAction? activeAction,
    void Function(DockAction)? onAction,
    VoidCallback? onPrev,
    VoidCallback? onNext,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: preset.themeData,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DockFooter(
            sheetOpen: sheetOpen,
            chapterIndex: chapterIndex,
            chapterCount: chapterCount,
            chapterLabel: 'The lacquer cup',
            progressListenable: ValueNotifier<double>(progress),
            activeAction: activeAction,
            onAction: onAction ?? (_) {},
            onPrevChapter: onPrev,
            onNextChapter: onNext,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('DockFooter actions', () {
    testWidgets('renders the three dock actions', (tester) async {
      await pumpFooter(tester, chapterIndex: 3, chapterCount: 18);
      final loc = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(loc.readerDockChapters), findsOneWidget);
      expect(find.text(loc.bookmarks), findsOneWidget);
      expect(find.text(loc.settingsTitle), findsOneWidget);
    });

    testWidgets('does NOT render a brightness action', (tester) async {
      await pumpFooter(tester, chapterIndex: 3, chapterCount: 18);
      final loc = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(loc.readerBrightness), findsNothing);
    });

    testWidgets('onAction fires with the tapped action', (tester) async {
      DockAction? tapped;
      await pumpFooter(
        tester,
        chapterIndex: 3,
        chapterCount: 18,
        onAction: (a) => tapped = a,
      );
      final loc = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(loc.settingsTitle));
      expect(tapped, DockAction.settings);
    });
  });

  group('DockFooter chapter stepper', () {
    testWidgets('shows the stepper + progress bar when collapsed', (tester) async {
      await pumpFooter(tester, chapterIndex: 3, chapterCount: 18);
      expect(find.byIcon(NyanIcons.chevronLeft), findsOneWidget);
      expect(find.byIcon(NyanIcons.chevronRight), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
    });

    testWidgets('hides the stepper + progress bar when grown into a sheet',
        (tester) async {
      await pumpFooter(
        tester,
        chapterIndex: 3,
        chapterCount: 18,
        sheetOpen: true,
      );
      expect(find.byIcon(NyanIcons.chevronLeft), findsNothing);
      expect(find.byIcon(NyanIcons.chevronRight), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('previous is disabled on the first chapter', (tester) async {
      var prevFired = 0;
      await pumpFooter(
        tester,
        chapterIndex: 0,
        chapterCount: 18,
        onPrev: () => prevFired++,
      );
      await tester.tap(find.byIcon(NyanIcons.chevronLeft));
      expect(prevFired, 0, reason: 'prev caret is disabled at chapter 0');
    });

    testWidgets('next is disabled on the last chapter', (tester) async {
      var nextFired = 0;
      await pumpFooter(
        tester,
        chapterIndex: 17,
        chapterCount: 18,
        onNext: () => nextFired++,
      );
      await tester.tap(find.byIcon(NyanIcons.chevronRight));
      expect(nextFired, 0, reason: 'next caret is disabled at the last chapter');
    });

    testWidgets('stepper carets fire in the middle of the book',
        (tester) async {
      var prev = 0;
      var next = 0;
      await pumpFooter(
        tester,
        chapterIndex: 5,
        chapterCount: 18,
        onPrev: () => prev++,
        onNext: () => next++,
      );
      await tester.tap(find.byIcon(NyanIcons.chevronLeft));
      await tester.tap(find.byIcon(NyanIcons.chevronRight));
      expect(prev, 1);
      expect(next, 1);
    });
  });

  group('OnePaperDock', () {
    Future<void> pumpDock(
      WidgetTester tester, {
      required bool visible,
      required bool sheetOpen,
      String? title,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: preset.themeData,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                OnePaperDock(
                  visible: visible,
                  sheetOpen: sheetOpen,
                  title: title,
                  meta: sheetOpen ? '42% read' : null,
                  footer: DockFooter(
                    sheetOpen: sheetOpen,
                    chapterIndex: 3,
                    chapterCount: 18,
                    chapterLabel: 'The lacquer cup',
                    progressListenable: ValueNotifier<double>(0.42),
                    activeAction: null,
                    onAction: (_) {},
                  ),
                  child: sheetOpen ? const Text('SHEET BODY') : null,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the footer is always present (dock or sheet)', (tester) async {
      await pumpDock(tester, visible: true, sheetOpen: false);
      expect(find.byType(DockFooter), findsOneWidget);
    });

    testWidgets('shows the title + body only when grown into a sheet',
        (tester) async {
      await pumpDock(
        tester,
        visible: true,
        sheetOpen: true,
        title: 'Reading Settings',
      );
      expect(find.text('Reading Settings'), findsOneWidget);
      expect(find.text('SHEET BODY'), findsOneWidget);
    });

    testWidgets('ignores pointers when hidden (immersive)', (tester) async {
      await pumpDock(tester, visible: false, sheetOpen: false);
      final ignorePointer = tester.widget<IgnorePointer>(
        find
            .ancestor(
              of: find.byType(DockFooter),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(ignorePointer.ignoring, isTrue);
    });
  });
}
