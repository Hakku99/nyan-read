import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_list_row.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';

void main() {
  // Pump a row inside the cream-light theme so NyanTheme tokens resolve.
  Future<void> pumpRow(WidgetTester tester, Widget row) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themePresets[ThemePreset.creamLight]!.themeData,
        home: Scaffold(body: row),
      ),
    );
    await tester.pump();
  }

  // ── Basic structure ─────────────────────────────────────────────────────
  group('NyanListRow basic structure', () {
    testWidgets('renders title only', (tester) async {
      await pumpRow(tester, const NyanListRow(title: 'Just a title'));
      expect(find.text('Just a title'), findsOneWidget);
    });

    testWidgets('renders title + subtitle', (tester) async {
      await pumpRow(
        tester,
        const NyanListRow(title: 'Title', subtitle: 'Sub'),
      );
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Sub'), findsOneWidget);
    });

    testWidgets('title uses w600 + 1.2 line-height by default',
        (tester) async {
      await pumpRow(tester, const NyanListRow(title: 'Hello'));
      final text = tester.widget<Text>(find.text('Hello'));
      expect(text.style?.fontWeight, FontWeight.w600);
      expect(text.style?.height, 1.2);
    });

    testWidgets('subtitle uses 1.3 line-height', (tester) async {
      await pumpRow(
        tester,
        const NyanListRow(title: 'T', subtitle: 'S'),
      );
      final sub = tester.widget<Text>(find.text('S'));
      expect(sub.style?.height, 1.3);
    });

    testWidgets('custom titleStyle overrides default', (tester) async {
      await pumpRow(
        tester,
        const NyanListRow(
          title: 'Custom',
          titleStyle: TextStyle(fontWeight: FontWeight.w400, fontSize: 22),
        ),
      );
      final text = tester.widget<Text>(find.text('Custom'));
      expect(text.style?.fontWeight, FontWeight.w400);
      expect(text.style?.fontSize, 22);
    });
  });

  // ── leadingIcon (built-in 36×36 chip) ───────────────────────────────────
  group('NyanListRow leadingIcon (built-in chip)', () {
    testWidgets('renders 36×36 chip with primary tint when set',
        (tester) async {
      final nyan = themePresets[ThemePreset.creamLight]!;
      await pumpRow(
        tester,
        const NyanListRow(
          leadingIcon: NyanIcons.file,
          title: 'Files',
        ),
      );

      // Chip Container is the Container ancestor of the icon.
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byIcon(NyanIcons.file),
          matching: find.byType(Container),
        ).first,
      );
      expect(container.constraints?.maxWidth, 36);
      expect(container.constraints?.maxHeight, 36);

      // Icon is at 17pt in primary color.
      final icon = tester.widget<Icon>(find.byIcon(NyanIcons.file));
      expect(icon.size, 17);
      expect(icon.color, nyan.primary);
    });

    testWidgets('no chip when leadingIcon is null', (tester) async {
      await pumpRow(tester, const NyanListRow(title: 'Bare'));
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('explicit leading widget wins over leadingIcon',
        (tester) async {
      await pumpRow(
        tester,
        const NyanListRow(
          leading: Icon(NyanIcons.book, key: ValueKey('custom-leading')),
          leadingIcon: NyanIcons.file, // should be ignored
          title: 'X',
        ),
      );
      expect(find.byKey(const ValueKey('custom-leading')), findsOneWidget);
      // The built-in chip's `file` icon must NOT appear.
      expect(find.byIcon(NyanIcons.file), findsNothing);
    });
  });

  // ── showChevron (built-in trailing caret) ───────────────────────────────
  group('NyanListRow showChevron (built-in trailing caret)', () {
    testWidgets('renders chevron at 18pt when showChevron is true',
        (tester) async {
      await pumpRow(
        tester,
        const NyanListRow(title: 'Go', showChevron: true),
      );
      final icon = tester.widget<Icon>(find.byIcon(NyanIcons.chevronRight));
      expect(icon.size, 18);
    });

    testWidgets('no chevron by default', (tester) async {
      await pumpRow(tester, const NyanListRow(title: 'Static'));
      expect(find.byIcon(NyanIcons.chevronRight), findsNothing);
    });

    testWidgets('explicit trailing widget wins over showChevron',
        (tester) async {
      await pumpRow(
        tester,
        const NyanListRow(
          title: 'X',
          showChevron: true,
          trailing: Icon(NyanIcons.book, key: ValueKey('custom-trailing')),
        ),
      );
      expect(find.byKey(const ValueKey('custom-trailing')), findsOneWidget);
      expect(find.byIcon(NyanIcons.chevronRight), findsNothing);
    });
  });

  // ── danger variant ──────────────────────────────────────────────────────
  group('NyanListRow danger variant', () {
    testWidgets('title uses errorPrimaryTextColor when danger', (tester) async {
      final nyan = themePresets[ThemePreset.creamLight]!;
      await pumpRow(
        tester,
        const NyanListRow(title: 'Delete book', danger: true),
      );
      final text = tester.widget<Text>(find.text('Delete book'));
      expect(text.style?.color, nyan.errorPrimaryTextColor);
    });

    testWidgets('chip uses error palette when danger + leadingIcon',
        (tester) async {
      final nyan = themePresets[ThemePreset.creamLight]!;
      await pumpRow(
        tester,
        const NyanListRow(
          title: 'Delete',
          leadingIcon: NyanIcons.delete,
          danger: true,
        ),
      );
      final icon = tester.widget<Icon>(find.byIcon(NyanIcons.delete));
      expect(icon.color, nyan.errorPrimaryTextColor);
    });

    testWidgets('non-danger title uses default body color', (tester) async {
      await pumpRow(tester, const NyanListRow(title: 'Normal'));
      final text = tester.widget<Text>(find.text('Normal'));
      // Not the error color — should be the theme's body color.
      final nyan = themePresets[ThemePreset.creamLight]!;
      expect(text.style?.color, isNot(nyan.errorPrimaryTextColor));
    });
  });

  // ── Behavior: tap ────────────────────────────────────────────────────────
  group('NyanListRow behavior', () {
    testWidgets('tap fires onTap callback', (tester) async {
      var taps = 0;
      await pumpRow(
        tester,
        NyanListRow(title: 'Hit', onTap: () => taps++),
      );
      await tester.tap(find.byType(NyanListRow));
      expect(taps, 1);
    });
  });
}
