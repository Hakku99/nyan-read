import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nyan_read/core/theme/nyan_radius.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_square_action_button.dart';

void main() {
  final preset = themePresets[ThemePreset.creamLight]!;

  Future<void> pump(WidgetTester tester, {VoidCallback? onPressed}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: preset.themeData,
        home: Scaffold(
          body: Center(
            child: NyanSquareActionButton(
              icon: Icons.sort,
              tooltip: 'Sort',
              onPressed: onPressed ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the icon', (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.sort), findsOneWidget);
  });

  testWidgets('is a bordered surface square (not a borderless recessed fill)',
      (tester) async {
    await pump(tester);
    final decoration = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.border != null);

    expect(decoration.color, preset.surface);
    expect(decoration.border, isNotNull);
    expect(
      decoration.borderRadius,
      BorderRadius.circular(NyanRadius.control),
    );
  });

  testWidgets('fires onPressed when tapped', (tester) async {
    var taps = 0;
    await pump(tester, onPressed: () => taps++);
    await tester.tap(find.byIcon(Icons.sort));
    expect(taps, 1);
  });
}
