import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/nyan_radius.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_row_group.dart';

void main() {
  final preset = themePresets[ThemePreset.creamLight]!;

  Future<void> pumpGroup(
    WidgetTester tester,
    List<Widget> children,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: preset.themeData,
        home: Scaffold(
          body: NyanRowGroup(children: children),
        ),
      ),
    );
    await tester.pump();
  }

  BoxDecoration outerDecoration(WidgetTester tester) {
    final containers = tester.widgetList<Container>(find.byType(Container));
    for (final c in containers) {
      final d = c.decoration;
      if (d is BoxDecoration && d.borderRadius != null) return d;
    }
    throw TestFailure('outer Container decoration not found');
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  testWidgets('renders SizedBox.shrink when empty', (tester) async {
    await pumpGroup(tester, []);
    expect(find.byType(NyanRowGroup), findsOneWidget);
    // No outer Container should exist with a card decoration
    final containers = tester.widgetList<Container>(find.byType(Container));
    final decorated =
        containers.where((c) => c.decoration is BoxDecoration).toList();
    expect(decorated, isEmpty);
  });

  // ── Outer container ────────────────────────────────────────────────────────
  group('NyanRowGroup outer container', () {
    testWidgets('uses NyanRadius.card border-radius', (tester) async {
      await pumpGroup(tester, [
        const Text('a', key: Key('a')),
        const Text('b', key: Key('b')),
      ]);
      final d = outerDecoration(tester);
      expect(d.borderRadius, BorderRadius.circular(NyanRadius.card));
    });

    testWidgets('background is nyan.surface', (tester) async {
      await pumpGroup(tester, [const Text('a', key: Key('a'))]);
      final d = outerDecoration(tester);
      expect(d.color, preset.surface);
    });

    testWidgets('border uses nyan.divider token', (tester) async {
      await pumpGroup(tester, [const Text('a', key: Key('a'))]);
      final d = outerDecoration(tester);
      final border = d.border as Border;
      final expected = preset.divider.withValues(alpha: 0.3);
      expect(border.top.color, expected);
    });
  });

  // ── Separators ─────────────────────────────────────────────────────────────
  group('NyanRowGroup separators', () {
    testWidgets('no separator with a single child', (tester) async {
      await pumpGroup(tester, [const Text('only', key: Key('a'))]);
      // Find Containers with height=1 (separators)
      final separators = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.constraints?.maxHeight == 1)
          .toList();
      expect(separators, isEmpty);
    });

    testWidgets('N-1 separators for N children', (tester) async {
      await pumpGroup(tester, [
        const Text('a', key: Key('a')),
        const Text('b', key: Key('b')),
        const Text('c', key: Key('c')),
      ]);
      // Look for 1px-tall Containers (separators)
      final separators = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.constraints?.maxHeight == 1)
          .toList();
      expect(separators, hasLength(2));
    });

    testWidgets('separator colour is nyan.divider', (tester) async {
      await pumpGroup(tester, [
        const Text('a', key: Key('a')),
        const Text('b', key: Key('b')),
      ]);
      final separator = tester
          .widgetList<Container>(find.byType(Container))
          .firstWhere((c) => c.constraints?.maxHeight == 1);
      final expected = preset.divider.withValues(alpha: 0.6);
      expect(separator.color, expected);
    });

    testWidgets('does NOT use Material Divider widget', (tester) async {
      await pumpGroup(tester, [
        const Text('a', key: Key('a')),
        const Text('b', key: Key('b')),
      ]);
      expect(
        find.byType(Divider),
        findsNothing,
        reason: 'design rule: row groups must not use Material Divider',
      );
    });
  });

  // ── Children rendering ─────────────────────────────────────────────────────
  testWidgets('renders all children in order', (tester) async {
    await pumpGroup(tester, [
      const Text('first', key: Key('first')),
      const Text('second', key: Key('second')),
      const Text('third', key: Key('third')),
    ]);
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('third'), findsOneWidget);
  });
}
