import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/reader_preferences_service.dart';
import '../../core/services/riverpod_providers.dart';
import '../../core/theme/nyan_colors.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/theme/nyan_typography.dart';
import '../../core/ui/components/components.dart';
import '../../core/ui/nyan_icons.dart';
import '../../core/ui/nyan_theme_context.dart';
import '../../l10n/app_localizations.dart';
import '../reader/widgets/reader_settings/reader_settings_text_panel.dart';

const double _kHPad = NyanSpacing.space16;

/// Standalone reading-preferences page reachable from the Settings screen.
///
/// Provides the same font / layout / page-turn controls as the in-reader
/// settings sheet but wired directly to [ReaderPreferencesService], so users
/// can configure their preferred reading style before opening a book.
class ReadingSettingsPage extends ConsumerWidget {
  const ReadingSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(readerPreferencesRpProvider);
    final loc = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) {
        // Derive text colour the same way ReaderSettingsManager does so the
        // preview tile matches the actual reader output.
        final isDark = prefs.backgroundColor.computeLuminance() < 0.5;
        final textColor =
            isDark ? NyanColors.readerInkDark : NyanColors.readerInkDefault;

        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SafeArea(
                bottom: false,
                child: NyanPageHeader(
                  title: loc.readingSettings,
                  leading: NyanRecessedIconButton(
                    icon: NyanIcons.back,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    _kHPad,
                    0,
                    _kHPad,
                    _kHPad + bottomInset,
                  ),
                  children: [
                    // ── Page Turn Mode ────────────────────────────────────
                    NyanSectionHeader(title: loc.pageTurnMode),
                    _PageTurnModeCard(prefs: prefs, loc: loc),

                    // ── Typography ────────────────────────────────────────
                    NyanSectionHeader(title: loc.readingSettings),
                    // Reuse the reader's Text panel — callbacks update prefs
                    // directly; the in-reader ReaderSettingsManager picks up
                    // the change via its PreferencesService listener.
                    ReaderSettingsTextPanel(
                      fontSize: prefs.fontSize,
                      lineHeight: prefs.lineHeight,
                      textColor: textColor,
                      backgroundColor: prefs.backgroundColor,
                      onSetFontSize: (v) => unawaited(prefs.setFontSize(v)),
                      onSetLineHeight: (v) =>
                          unawaited(prefs.setLineHeight(v)),
                      useSerif: prefs.useSerif,
                      onSetUseSerif: (v) => unawaited(prefs.setUseSerif(v)),
                      loc: loc,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Page Turn Mode pill knob — identical semantic to the one in
/// [ReaderSettingsDisplayPanel] but self-contained so this page does not
/// depend on the reader's [BrightnessController].
class _PageTurnModeCard extends StatelessWidget {
  const _PageTurnModeCard({required this.prefs, required this.loc});

  final ReaderPreferencesService prefs;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final modes = PageTurnMode.values;
    final labels = [loc.pageTurnTap, loc.pageTurnSwipe, loc.pageTurnDisabled];

    return NyanRowGroup(
      children: [
        Padding(
          padding: const EdgeInsets.all(NyanSpacing.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.pageTurnMode,
                style: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  fontSize: NyanTypography.meta,
                  fontWeight: FontWeight.w500,
                  color: nyan.textSecondary,
                ),
              ),
              const SizedBox(height: NyanSpacing.space8),
              Row(
                children: [
                  for (var i = 0; i < modes.length; i++) ...[
                    if (i > 0) const SizedBox(width: NyanSpacing.space8),
                    Expanded(
                      child: NyanPillButton(
                        label: labels[i],
                        selected: prefs.pageTurnMode == modes[i],
                        onPressed: () =>
                            unawaited(prefs.setPageTurnMode(modes[i])),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
