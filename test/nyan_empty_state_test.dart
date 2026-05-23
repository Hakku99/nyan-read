import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/nyan_radius.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_empty_state.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';

void main() {
  Future<void> pumpState(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themePresets[ThemePreset.creamLight]!.themeData,
        home: Scaffold(body: widget),
      ),
    );
    await tester.pump();
  }

  // ── iconData — canonical chip ────────────────────────────────────────────
  group('NyanEmptyState iconData (canonical rounded-square chip)', () {
    testWidgets('renders the icon glyph at 34pt', (tester) async {
      await pumpState(
        tester,
        const NyanEmptyState(
          iconData: NyanIcons.bookCollection,
          title: 'Empty',
        ),
      );
      final icon = tester.widget<Icon>(find.byIcon(NyanIcons.bookCollection));
      expect(icon.size, 34);
    });

    testWidgets('icon container uses NyanRadius.card (20pt)', (tester) async {
      await pumpState(
        tester,
        const NyanEmptyState(
          iconData: NyanIcons.bookCollection,
          title: 'Empty',
        ),
      );
      // The Container wrapping the icon uses border-radius card.
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byIcon(NyanIcons.bookCollection),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(NyanRadius.card),
      );
    });

    testWidgets('explicit icon widget wins over iconData', (tester) async {
      await pumpState(
        tester,
        NyanEmptyState(
          icon: const Icon(NyanIcons.book, key: ValueKey('custom')),
          iconData: NyanIcons.bookCollection, // should be ignored
          title: 'X',
        ),
      );
      expect(find.byKey(const ValueKey('custom')), findsOneWidget);
      expect(find.byIcon(NyanIcons.bookCollection), findsNothing);
    });
  });

  // ── Default title style ──────────────────────────────────────────────────
  group('NyanEmptyState default title style (spec: 600 20/1.3)', () {
    testWidgets('title is 20pt w600 height 1.3 by default', (tester) async {
      await pumpState(
        tester,
        const NyanEmptyState(
          iconData: NyanIcons.bookCollection,
          title: 'Waiting for stories',
        ),
      );
      final text = tester.widget<Text>(find.text('Waiting for stories'));
      expect(text.style?.fontSize, NyanTypography.section); // 20
      expect(text.style?.fontWeight, FontWeight.w600);
      expect(text.style?.height, 1.3);
    });

    testWidgets('custom titleStyle overrides default', (tester) async {
      await pumpState(
        tester,
        NyanEmptyState(
          iconData: NyanIcons.bookCollection,
          title: 'Custom',
          titleStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
        ),
      );
      final text = tester.widget<Text>(find.text('Custom'));
      expect(text.style?.fontSize, 24);
      expect(text.style?.fontWeight, FontWeight.w400);
    });
  });

  // ── Default description style ────────────────────────────────────────────
  group('NyanEmptyState default description style (spec: 400 14/1.5 textSecondary)', () {
    testWidgets('description has height 1.5 by default', (tester) async {
      await pumpState(
        tester,
        const NyanEmptyState(
          iconData: NyanIcons.bookCollection,
          title: 'T',
          description: 'Import a book',
        ),
      );
      final text = tester.widget<Text>(find.text('Import a book'));
      expect(text.style?.height, 1.5);
    });

    testWidgets('description color is nyan.textSecondary by default',
        (tester) async {
      final nyan = themePresets[ThemePreset.creamLight]!;
      await pumpState(
        tester,
        const NyanEmptyState(
          iconData: NyanIcons.bookCollection,
          title: 'T',
          description: 'Subtitle',
        ),
      );
      final text = tester.widget<Text>(find.text('Subtitle'));
      expect(text.style?.color, nyan.textSecondary);
    });

    testWidgets('custom descriptionStyle overrides default', (tester) async {
      await pumpState(
        tester,
        NyanEmptyState(
          iconData: NyanIcons.bookCollection,
          title: 'T',
          description: 'Desc',
          descriptionStyle: const TextStyle(height: 2.0, fontSize: 18),
        ),
      );
      final text = tester.widget<Text>(find.text('Desc'));
      expect(text.style?.height, 2.0);
      expect(text.style?.fontSize, 18);
    });
  });

  // ── assert: must supply icon or iconData ─────────────────────────────────
  testWidgets('assert fires when neither icon nor iconData given',
      (tester) async {
    expect(
      () => NyanEmptyState(title: 'Bad'),
      throwsAssertionError,
    );
  });

  // ── Smoke: icon Widget path still works ──────────────────────────────────
  testWidgets('icon Widget path renders without error', (tester) async {
    await pumpState(
      tester,
      NyanEmptyState(
        icon: const Icon(NyanIcons.book),
        title: 'No books',
        description: 'Add one',
        action: TextButton(onPressed: () {}, child: const Text('Import')),
      ),
    );
    expect(find.text('No books'), findsOneWidget);
    expect(find.text('Add one'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
  });
}
