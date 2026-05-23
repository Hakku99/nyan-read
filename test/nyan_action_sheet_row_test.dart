import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/nyan_radius.dart';
import 'package:nyan_read/core/theme/nyan_spacing.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_action_sheet_row.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';

void main() {
  Future<void> pumpRow(
    WidgetTester tester, {
    bool showChevron = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themePresets[ThemePreset.creamLight]!.themeData,
        home: Scaffold(
          body: NyanActionSheetRow(
            icon: NyanIcons.book,
            title: 'Import',
            subtitle: 'Add a book file',
            onTap: () {},
            showChevron: showChevron,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // ── Smoke ────────────────────────────────────────────────────────────────
  testWidgets('renders title and subtitle', (tester) async {
    await pumpRow(tester);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Add a book file'), findsOneWidget);
  });

  // ── Title style (spec: 600 16/1.2) ──────────────────────────────────────
  group('NyanActionSheetRow title style (spec: 600 16/1.2)', () {
    testWidgets('title is w600, 16pt, height 1.2', (tester) async {
      await pumpRow(tester);
      final text = tester.widget<Text>(find.text('Import'));
      expect(text.style?.fontWeight, FontWeight.w600);
      expect(text.style?.fontSize, 16.0);
      expect(text.style?.height, 1.2);
    });
  });

  // ── Icon chip ────────────────────────────────────────────────────────────
  group('NyanActionSheetRow icon chip', () {
    testWidgets('chip is 36×36 with NyanRadius.small', (tester) async {
      await pumpRow(tester);
      // The chip is the Container ancestor of the icon.
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(NyanIcons.book),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(container.constraints?.maxWidth, 36);
      expect(container.constraints?.maxHeight, 36);
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(NyanRadius.small),
      );
    });

    testWidgets('icon glyph is 17pt', (tester) async {
      await pumpRow(tester);
      final icon = tester.widget<Icon>(find.byIcon(NyanIcons.book));
      expect(icon.size, 17);
    });
  });

  // ── Chevron ──────────────────────────────────────────────────────────────
  group('NyanActionSheetRow chevron', () {
    testWidgets('chevron is visible by default', (tester) async {
      await pumpRow(tester);
      expect(find.byIcon(NyanIcons.chevronRight), findsOneWidget);
    });

    testWidgets('chevron is hidden when showChevron=false', (tester) async {
      await pumpRow(tester, showChevron: false);
      expect(find.byIcon(NyanIcons.chevronRight), findsNothing);
    });

    testWidgets('chevron color is nyan.textSecondary @ 44%', (tester) async {
      final nyan = themePresets[ThemePreset.creamLight]!;
      await pumpRow(tester);
      final icon = tester.widget<Icon>(
        find.byIcon(NyanIcons.chevronRight),
      );
      expect(
        icon.color,
        nyan.textSecondary.withValues(alpha: 0.44),
      );
    });

    testWidgets('chevron is 18pt', (tester) async {
      await pumpRow(tester);
      final icon = tester.widget<Icon>(
        find.byIcon(NyanIcons.chevronRight),
      );
      expect(icon.size, 18);
    });
  });

  // ── Row padding ──────────────────────────────────────────────────────────
  group('NyanActionSheetRow padding', () {
    testWidgets('uses compactRowHorizontalPadding and compactRowVerticalPadding',
        (tester) async {
      await pumpRow(tester);
      final padding = tester.widget<Padding>(
        find
            .ancestor(
              of: find.byType(Row),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(
        padding.padding,
        const EdgeInsets.symmetric(
          horizontal: NyanSpacing.space16,
          vertical: NyanSpacing.space12,
        ),
      );
    });
  });

  // ── Tap callback ─────────────────────────────────────────────────────────
  testWidgets('onTap fires when row is tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: themePresets[ThemePreset.creamLight]!.themeData,
        home: Scaffold(
          body: NyanActionSheetRow(
            icon: NyanIcons.book,
            title: 'Go',
            subtitle: 'Sub',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });
}
