import 'package:flutter/material.dart';

import 'package:nyan_read/l10n/app_localizations.dart';

import '../../../../core/theme/nyan_radius.dart';
import '../../../../core/theme/nyan_spacing.dart';
import '../../../../core/ui/components/nyan_sheet_card.dart';

Color _themeLabelColor({
  required ThemeData theme,
  required Color preview,
  required bool isSelected,
}) {
  final previewDark = preview.computeLuminance() < 0.45;
  if (previewDark) {
    return Colors.white.withValues(alpha: isSelected ? 1.0 : 0.88);
  }
  return isSelected
      ? theme.colorScheme.primary
      : (theme.textTheme.bodySmall?.color?.withValues(alpha: 0.92) ??
          const Color(0xFF3D3D3D));
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

  static const _creamAlt = Color(0xFFFDFCF8);

  List<_ReaderThemeOption> _options(AppLocalizations loc) => [
        _ReaderThemeOption(
          label: loc.themeCream,
          background: const Color(0xFFF7F5EF),
          preview: const Color(0xFFFFFCF5),
          ink: const Color(0xFF4A453E),
        ),
        _ReaderThemeOption(
          label: loc.themeSepia,
          background: const Color(0xFFEDE3C7),
          preview: const Color(0xFFF5ECD8),
          ink: const Color(0xFF5C4F3F),
        ),
        _ReaderThemeOption(
          label: loc.themeSumi,
          background: const Color(0xFF262422),
          preview: const Color(0xFF302D2B),
          ink: const Color(0xFFE5DED3),
        ),
        _ReaderThemeOption(
          label: loc.themeCharcoal,
          background: const Color(0xFF141312),
          preview: const Color(0xFF1B1A19),
          ink: const Color(0xFFF1EBDD),
        ),
      ];

  bool _isSelected(Color controllerBg, _ReaderThemeOption option) {
    if (controllerBg.value == option.background.value) return true;
    if (option.label == loc.themeCream) {
      return controllerBg.value == _creamAlt.value;
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
              mainAxisExtent: 66,
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
    final darkPage = option.background.computeLuminance() < 0.35;
    final linePrimary = darkPage ? 0.34 : 0.16;
    final lineSecondary = darkPage ? 0.26 : 0.12;

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NyanRadius.input),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: option.preview,
              borderRadius: BorderRadius.circular(NyanRadius.input),
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
                    : theme.dividerColor.withValues(alpha: 0.16),
                width: isSelected ? 1.2 : 0.72,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: option.background,
                      borderRadius: BorderRadius.circular(NyanRadius.small),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 2,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color:
                                    option.ink.withValues(alpha: linePrimary),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Container(
                                height: 2,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: option.ink
                                      .withValues(alpha: lineSecondary),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          color: _themeLabelColor(
                            theme: theme,
                            preview: option.preview,
                            isSelected: isSelected,
                          ),
                        ),
                      ),
                    ),
                    if (isSelected)
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: theme.colorScheme.primary,
                        child: Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
