import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nyan_read/core/services/bookshelf_preferences_service.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/components/nyan_chip_selection_sheet.dart';
import 'package:nyan_read/core/ui/components/nyan_pill_button.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/bookshelf/widgets/bookshelf_sort_sheet.dart';
import 'package:nyan_read/modules/bookshelf/widgets/segmented_tab_control.dart';

ThemeData get _theme => themePresets[ThemePreset.creamLight]!.themeData;

Widget _host(Widget Function(BuildContext) onPressed) {
  return MaterialApp(
    theme: _theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => onPressed(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('NyanChipSelectionSheet', () {
    testWidgets('renders options as pill chips and pops the tapped value',
        (tester) async {
      int? result;
      await tester.pumpWidget(
        _host((context) {
          showNyanChipSelectionSheet<int>(
            context: context,
            title: 'Interval',
            currentValue: 30,
            options: const [
              NyanSelectionOption(value: 30, label: '30 min'),
              NyanSelectionOption(value: 60, label: '60 min'),
              NyanSelectionOption(value: 90, label: '90 min'),
            ],
          ).then((v) => result = v);
          return const SizedBox.shrink();
        }),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Outline-on-select chips, not list rows with checkmarks.
      expect(find.byType(NyanPillButton), findsNWidgets(3));
      expect(find.byIcon(Icons.check), findsNothing);

      await tester.tap(find.text('60 min'));
      await tester.pumpAndSettle();

      expect(result, 60);
    });
  });

  group('BookshelfSortSheet', () {
    testWidgets('key chips + order segmented apply live via onChanged',
        (tester) async {
      final changes = <(SortBy, bool)>[];
      await tester.pumpWidget(
        _host((context) {
          showBookshelfSortSheet(
            context: context,
            currentSortBy: SortBy.recency,
            currentAscending: false,
            onChanged: (sortBy, asc) => changes.add((sortBy, asc)),
          );
          return const SizedBox.shrink();
        }),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final loc = AppLocalizations.of(
        tester.element(find.byType(SegmentedTabControl)),
      )!;

      // 3 key chips + the Ascending/Descending segmented control.
      expect(find.byType(NyanPillButton), findsNWidgets(3));
      expect(find.text(loc.lastRead), findsOneWidget);
      expect(find.text(loc.added), findsOneWidget);
      expect(find.text(loc.title), findsOneWidget);

      // Tapping a key chip applies immediately, sheet stays open.
      await tester.tap(find.text(loc.title));
      await tester.pumpAndSettle();
      expect(changes.last, (SortBy.title, false));

      // Switching order applies immediately too.
      await tester.tap(find.text(loc.sortOrderAsc));
      await tester.pumpAndSettle();
      expect(changes.last, (SortBy.title, true));
    });
  });
}
