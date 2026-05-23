import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/nyan_radius.dart';
import 'package:nyan_read/core/theme/nyan_spacing.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_info_card.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    NyanInfoCardTone tone = NyanInfoCardTone.surface,
    NyanInfoCardVariant variant = NyanInfoCardVariant.standard,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themePresets[ThemePreset.creamLight]!.themeData,
        home: Scaffold(
          body: NyanInfoCard(
            tone: tone,
            variant: variant,
            onTap: onTap,
            child: const Text('content'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  BoxDecoration cardDecoration(WidgetTester tester) {
    final containers = tester.widgetList<Container>(find.byType(Container));
    for (final c in containers) {
      final d = c.decoration;
      if (d is BoxDecoration && d.borderRadius != null) return d;
    }
    throw TestFailure('decorated Container not found');
  }

  // ── Standard card ─────────────────────────────────────────────────────────
  group('NyanInfoCard standard variant', () {
    testWidgets('uses NyanRadius.card (20) border-radius', (tester) async {
      await pumpCard(tester);
      final d = cardDecoration(tester);
      expect(d.borderRadius, BorderRadius.circular(NyanRadius.card));
    });

    testWidgets('has lightCard shadow in light mode', (tester) async {
      await pumpCard(tester);
      final d = cardDecoration(tester);
      expect(d.boxShadow, isNotEmpty);
    });

    testWidgets('default padding is NyanSpacing.space16', (tester) async {
      await pumpCard(tester);
      final paddings = tester.widgetList<Padding>(find.byType(Padding));
      final contentPadding = paddings.firstWhere(
        (p) => p.padding == const EdgeInsets.all(NyanSpacing.space16),
        orElse: () => throw TestFailure(
          'No Padding(all: 16) found — default card padding drift',
        ),
      );
      expect(contentPadding.padding, const EdgeInsets.all(NyanSpacing.space16));
    });

    testWidgets('renders child', (tester) async {
      await pumpCard(tester);
      expect(find.text('content'), findsOneWidget);
    });
  });

  // ── Grouped card ──────────────────────────────────────────────────────────
  group('NyanInfoCard grouped variant', () {
    testWidgets('uses NyanRadius.input (16) border-radius', (tester) async {
      await pumpCard(tester, variant: NyanInfoCardVariant.grouped);
      final d = cardDecoration(tester);
      expect(d.borderRadius, BorderRadius.circular(NyanRadius.input));
    });

    testWidgets('has settingsGrouped shadow in light mode', (tester) async {
      await pumpCard(tester, variant: NyanInfoCardVariant.grouped);
      final d = cardDecoration(tester);
      expect(d.boxShadow, isNotEmpty);
    });
  });

  // ── Muted tone — spec: no shadow ──────────────────────────────────────────
  group('NyanInfoCard muted tone', () {
    testWidgets('has NO shadow (spec: muted cards are flat)', (tester) async {
      await pumpCard(tester, tone: NyanInfoCardTone.muted);
      final d = cardDecoration(tester);
      expect(
        d.boxShadow,
        anyOf(isNull, isEmpty),
        reason: 'muted-tone card must not have a shadow per design spec',
      );
    });

    testWidgets('still uses NyanRadius.card border-radius', (tester) async {
      await pumpCard(tester, tone: NyanInfoCardTone.muted);
      final d = cardDecoration(tester);
      expect(d.borderRadius, BorderRadius.circular(NyanRadius.card));
    });

    testWidgets('surface-tone card DOES have a shadow (regression guard)',
        (tester) async {
      await pumpCard(tester, tone: NyanInfoCardTone.surface);
      final d = cardDecoration(tester);
      expect(d.boxShadow, isNotEmpty);
    });
  });

  // ── Tappable variant ──────────────────────────────────────────────────────
  group('NyanInfoCard tappable', () {
    testWidgets('wraps in InkWell when onTap is provided', (tester) async {
      await pumpCard(tester, onTap: () {});
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('no InkWell when onTap is null', (tester) async {
      await pumpCard(tester);
      expect(find.byType(InkWell), findsNothing);
    });
  });
}
