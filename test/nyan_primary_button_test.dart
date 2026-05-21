import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_primary_button.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';

void main() {
  // Pump a button inside the cream-light theme so NyanTheme tokens resolve.
  Future<void> pumpButton(
    WidgetTester tester,
    Widget button,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themePresets[ThemePreset.creamLight]!.themeData,
        home: Scaffold(
          body: Center(child: button),
        ),
      ),
    );
    await tester.pump();
  }

  // ── Size matrix — heights are LOCKED per Claude Design spec ───────────
  group('NyanPrimaryButton size matrix (locked heights)', () {
    testWidgets('compact renders at 36pt height', (tester) async {
      await pumpButton(
        tester,
        NyanPrimaryButton(
          label: 'Continue',
          onPressed: () {},
          size: NyanPrimaryButtonSize.compact,
        ),
      );
      final box = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(NyanPrimaryButton),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(box.height, 36.0);
    });

    testWidgets('standard renders at 44pt height', (tester) async {
      await pumpButton(
        tester,
        NyanPrimaryButton(
          label: 'Confirm',
          onPressed: () {},
          size: NyanPrimaryButtonSize.standard,
        ),
      );
      final box = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(NyanPrimaryButton),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(box.height, 44.0);
    });

    testWidgets('comfortable renders at 52pt height', (tester) async {
      await pumpButton(
        tester,
        NyanPrimaryButton(
          label: 'Start Reading',
          onPressed: () {},
          size: NyanPrimaryButtonSize.comfortable,
        ),
      );
      final box = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(NyanPrimaryButton),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(box.height, 52.0);
    });

    testWidgets('default size is standard (44pt)', (tester) async {
      await pumpButton(
        tester,
        NyanPrimaryButton(label: 'Tap', onPressed: () {}),
      );
      final box = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(NyanPrimaryButton),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(box.height, 44.0);
    });
  });

  // ── Variant matrix — primary / deep / ghost ───────────────────────────
  group('NyanPrimaryButton variant matrix', () {
    final nyan = themePresets[ThemePreset.creamLight]!;

    testWidgets('primary uses matcha fill + cream label', (tester) async {
      await pumpButton(
        tester,
        NyanPrimaryButton(
          label: 'Primary',
          onPressed: () {},
          variant: NyanPrimaryButtonVariant.primary,
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(NyanPrimaryButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, nyan.primary);

      final text = tester.widget<Text>(find.text('Primary'));
      expect(text.style?.color, nyan.surface);
      expect(text.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('deep uses primaryDeep fill + cream label', (tester) async {
      await pumpButton(
        tester,
        NyanPrimaryButton(
          label: 'Deep',
          onPressed: () {},
          variant: NyanPrimaryButtonVariant.deep,
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(NyanPrimaryButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, nyan.primaryDeep);

      final text = tester.widget<Text>(find.text('Deep'));
      expect(text.style?.color, nyan.surface);
      expect(text.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('ghost uses transparent fill + primaryDeep label (w600)',
        (tester) async {
      await pumpButton(
        tester,
        NyanPrimaryButton(
          label: 'Ghost',
          onPressed: () {},
          variant: NyanPrimaryButtonVariant.ghost,
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(NyanPrimaryButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, Colors.transparent);

      final text = tester.widget<Text>(find.text('Ghost'));
      expect(text.style?.color, nyan.primaryDeep);
      expect(text.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('default variant is primary', (tester) async {
      await pumpButton(
        tester,
        NyanPrimaryButton(label: 'Default', onPressed: () {}),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(NyanPrimaryButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, nyan.primary);
    });
  });

  // ── Font sizes (Claude Design exception per AGENTS.md §4.2.5) ─────────
  group('NyanPrimaryButton font sizes per size variant', () {
    testWidgets('compact uses 14pt label', (tester) async {
      await pumpButton(
        tester,
        NyanPrimaryButton(
          label: 'sm',
          onPressed: () {},
          size: NyanPrimaryButtonSize.compact,
        ),
      );
      final text = tester.widget<Text>(find.text('sm'));
      expect(text.style?.fontSize, 14.0);
    });

    testWidgets('standard uses 16pt label', (tester) async {
      await pumpButton(
        tester,
        NyanPrimaryButton(
          label: 'md',
          onPressed: () {},
          size: NyanPrimaryButtonSize.standard,
        ),
      );
      final text = tester.widget<Text>(find.text('md'));
      expect(text.style?.fontSize, 16.0);
    });

    testWidgets('comfortable uses 17pt label', (tester) async {
      await pumpButton(
        tester,
        NyanPrimaryButton(
          label: 'lg',
          onPressed: () {},
          size: NyanPrimaryButtonSize.comfortable,
        ),
      );
      final text = tester.widget<Text>(find.text('lg'));
      expect(text.style?.fontSize, 17.0);
    });
  });

  // ── Behavior: expanded, disabled, icon, ellipsis ──────────────────────
  group('NyanPrimaryButton behavior', () {
    testWidgets('expanded wraps in full-width SizedBox', (tester) async {
      await pumpButton(
        tester,
        NyanPrimaryButton(
          label: 'Wide',
          onPressed: () {},
          expanded: true,
        ),
      );
      final boxes = tester
          .widgetList<SizedBox>(find.descendant(
            of: find.byType(NyanPrimaryButton),
            matching: find.byType(SizedBox),
          ))
          .toList();
      // Expect at least one SizedBox with infinite width (the wrapper).
      expect(
        boxes.any((b) => b.width == double.infinity),
        isTrue,
      );
    });

    testWidgets('non-expanded does not constrain width', (tester) async {
      await pumpButton(
        tester,
        NyanPrimaryButton(label: 'Tight', onPressed: () {}),
      );
      final boxes = tester
          .widgetList<SizedBox>(find.descendant(
            of: find.byType(NyanPrimaryButton),
            matching: find.byType(SizedBox),
          ))
          .toList();
      expect(
        boxes.any((b) => b.width == double.infinity),
        isFalse,
      );
    });

    testWidgets('disabled (onPressed null) dims fill and label',
        (tester) async {
      final nyan = themePresets[ThemePreset.creamLight]!;
      await pumpButton(
        tester,
        const NyanPrimaryButton(label: 'Off', onPressed: null),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(NyanPrimaryButton),
          matching: find.byType(Material),
        ),
      );
      // Fill is dimmed to ~40% alpha.
      expect(material.color, nyan.primary.withValues(alpha: 0.4));
      // Label is dimmed to ~50% alpha.
      final text = tester.widget<Text>(find.text('Off'));
      expect(text.style?.color, nyan.surface.withValues(alpha: 0.5));
    });

    testWidgets('ghost disabled keeps transparent fill', (tester) async {
      await pumpButton(
        tester,
        const NyanPrimaryButton(
          label: 'Ghost off',
          onPressed: null,
          variant: NyanPrimaryButtonVariant.ghost,
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(NyanPrimaryButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, Colors.transparent);
    });

    testWidgets('icon + label both render', (tester) async {
      await pumpButton(
        tester,
        NyanPrimaryButton(
          label: 'Save',
          onPressed: () {},
          icon: const Icon(NyanIcons.save),
        ),
      );
      expect(find.text('Save'), findsOneWidget);
      expect(find.byIcon(NyanIcons.save), findsOneWidget);
    });

    testWidgets('label uses single-line ellipsis overflow', (tester) async {
      await pumpButton(
        tester,
        NyanPrimaryButton(
          label: 'A very long label that should be ellipsised when it overflows the available width',
          onPressed: () {},
        ),
      );
      final text = tester.widget<Text>(find.textContaining('A very long label'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('tap fires onPressed when enabled', (tester) async {
      var taps = 0;
      await pumpButton(
        tester,
        NyanPrimaryButton(label: 'Hit', onPressed: () => taps++),
      );
      await tester.tap(find.byType(NyanPrimaryButton));
      expect(taps, 1);
    });
  });
}
