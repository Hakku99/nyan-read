import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:nyan_read/modules/reader/reader_error.dart';
import 'package:nyan_read/modules/reader/widgets/reader_error_view.dart';

void main() {
  final preset = themePresets[ThemePreset.creamLight]!;

  // Regression: Back + Retry sat in a Row and overflowed by 19px on a
  // 1256px-wide phone, clipping Retry. The test font (Ahem) is much wider than
  // Noto Sans SC, so 400 forces the wrapped layout and 800 the single row;
  // narrower widths overflow the unrelated "Report" row only under Ahem.
  for (final width in [400.0, 800.0]) {
    testWidgets('error view buttons do not overflow at ${width}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: preset.themeData,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: ReaderErrorView(
            errorState: ReaderErrorState(type: ReaderErrorType.parseFailed),
            onBack: () {},
            onRetry: () {},
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      final loc = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(loc.retry), findsOneWidget);
      expect(find.text(loc.backToBookshelf), findsOneWidget);
    });
  }
}
