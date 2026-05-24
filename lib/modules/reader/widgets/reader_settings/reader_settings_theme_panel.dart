import 'package:flutter/material.dart';

import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/nyan_colors.dart';
import '../../../../core/theme/nyan_radius.dart';
import '../../../../core/theme/nyan_spacing.dart';
import '../../../../core/theme/nyan_typography.dart';
import '../../../../core/ui/components/nyan_sheet_card.dart';

Color _themeLabelColor({
  required ThemeData theme,
  required Color preview,
  required bool isSelected,
}) {
  final previewDark = preview.computeLuminance() < 0.45;
  if (previewDark) {
    return theme.colorScheme.onPrimary
        .withValues(alpha: isSelected ? 1.0 : 0.88);
  }
  return isSelected
      ? theme.colorScheme.primary
      : (theme.textTheme.bodySmall?.color?.withValues(alpha: 0.92) ??
          theme.colorScheme.onSurface.withValues(alpha: 0.9));
}

/// Reading background presets (Theme tab).
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

    return NyanSheetCard(
      key: const Key('reader-menu-theme-grid'),
      radius: NyanRadius.card,
      children: [
        Padding(
          padding: const EdgeInsets.all(NyanSpacing.space16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: options.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: NyanSpacing.space12,
              mainAxisSpacing: NyanSpacing.space12,
              // Spec ReaderSettingsSheet.jsx: theme card height 80pt with the
              // "Aa 永" sample inside the preview area.
              mainAxisExtent: 80,
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
        ),
      ],
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

    // Per Claude Design spec (`ReaderSettingsSheet.jsx`): the card uses the
    // theme's preview colour as its own background, with the name in the
    // theme's ink colour top-left, an "Aa 永" sample (serif) bottom-left,
    // and a 22pt check circle top-right when selected. The check uses
    // [Icons.check_rounded] with the [primary] colour for the circle so the
    // selection cue reads regardless of card luminance.
    final labelColor = _themeLabelColor(
      theme: theme,
      preview: option.preview,
      isSelected: isSelected,
    );

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticsLabel,
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: 0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(NyanSpacing.space12),
            decoration: BoxDecoration(
              color: option.preview,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : option.ink.withValues(alpha: 0.16),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: NyanTypography.uiFontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: labelColor,
                      ),
                    ),
                    Text(
                      'Aa 永',
                      style: TextStyle(
                        fontFamily: NyanTypography.readingSerifFontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                        color: option.ink.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                if (isSelected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        NyanIcons.checkFilled,
                        size: 14,
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
