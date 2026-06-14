import 'package:flutter/material.dart';

import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../../../core/theme/nyan_colors.dart';
import '../../../../core/theme/nyan_radius.dart';
import '../../../../core/theme/nyan_spacing.dart';
import '../../../../core/theme/nyan_typography.dart';
import 'reader_settings_common.dart';

/// Reading background presets (Theme tab).
///
/// Layout per spec `reader.jsx` `ThemePanel`:
///   "Reading Theme" Knob (surfaceMuted) containing a 2×2 grid of swatches.
class ReaderSettingsThemePanel extends StatelessWidget {
  const ReaderSettingsThemePanel({
    super.key,
    required this.currentBackground,
    required this.onSelectBackground,
    required this.loc,
  });

  final Color currentBackground;
  final ValueChanged<Color> onSelectBackground;
  final AppLocalizations loc;

  static const _creamAlt = NyanColors.readerPaperDefault;

  List<_ReaderThemeOption> _options(AppLocalizations loc) => [
        _ReaderThemeOption(
          label: loc.themeCream,
          background: NyanColors.readerBgCream,
          preview: NyanColors.readerPreviewCream,
          ink: NyanColors.readerInkCream,
        ),
        _ReaderThemeOption(
          label: loc.themeSepia,
          background: NyanColors.readerBgSepia,
          preview: NyanColors.readerPreviewSepia,
          ink: NyanColors.readerInkSepia,
        ),
        _ReaderThemeOption(
          label: loc.themeSumi,
          background: NyanColors.readerBgSumi,
          preview: NyanColors.readerPreviewSumi,
          ink: NyanColors.readerInkSumi,
        ),
        _ReaderThemeOption(
          label: loc.themeCharcoal,
          background: NyanColors.readerBgCharcoal,
          preview: NyanColors.readerPreviewCharcoal,
          ink: NyanColors.readerInkCharcoal,
        ),
      ];

  bool _isSelected(Color controllerBg, _ReaderThemeOption option) {
    if (controllerBg == option.background) return true;
    if (option.label == loc.themeCream) {
      return controllerBg == _creamAlt;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final options = _options(loc);

    return ReaderSettingsKnob(
      key: const Key('reader-menu-theme-grid'),
      label: loc.readingTheme,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        // Explicit zero padding prevents Flutter from injecting MediaQuery
        // safe-area insets into the grid's scroll viewport, which would inflate
        // the Knob height (common in sheet/overlay contexts).
        padding: EdgeInsets.zero,
        itemCount: options.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          // Spec reader.jsx ThemePanel grid: gap 10 (§4.6 override of space12).
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 74,
        ),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = _isSelected(currentBackground, option);
          return _ThemeCard(
            option: option,
            isSelected: selected,
            onTap: () => onSelectBackground(option.background),
            semanticsLabel: '${loc.readerMenuTheme}: ${option.label}',
          );
        },
      ),
    );
  }
}

class _ReaderThemeOption {
  const _ReaderThemeOption({
    required this.label,
    required this.background,
    required this.preview,
    required this.ink,
  });

  final String label;
  final Color background;
  final Color preview;
  final Color ink;
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
    required this.semanticsLabel,
  });

  final _ReaderThemeOption option;
  final bool isSelected;
  final VoidCallback onTap;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NyanRadius.cardNested),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: option.preview,
              borderRadius: BorderRadius.circular(NyanRadius.cardNested),
              // Spec ThemePanel: selected = 1.5px primary border, unselected = transparent.
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            // Stack outside the content padding so Positioned(top:8,right:8) is
            // relative to the card edge, not the content area edge.
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(NyanSpacing.space12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Spec: label always uses s.ink color (no luminance switching).
                      Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: NyanTypography.uiFontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: option.ink,
                        ),
                      ),
                      // Spec: "400 13px/1 var(--font-serif)", opacity 0.72.
                      Text(
                        'Aa 永',
                        style: TextStyle(
                          fontFamily: NyanTypography.readingSerifFontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.0,
                          color: option.ink.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                // Spec: badge at top:8, right:8 from card edge; icon size 13pt.
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        NyanIcons.check,
                        size: 13,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
