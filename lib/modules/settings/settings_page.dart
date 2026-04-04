import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/backup_recovery_service.dart';
import '../../core/services/bookshelf_preferences_service.dart';
import '../../core/services/feature_manager.dart';
import '../../core/services/language_manager.dart';
import '../../core/services/reader_preferences_service.dart';
import '../../core/services/reading_reminder_service.dart';
import '../../core/services/service_locator.dart';
import '../../core/theme/nyan_radius.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/theme/nyan_typography.dart';
import '../../core/theme/theme_manager.dart';
import '../../core/theme/theme_presets.dart';
import '../../core/ui/components/components.dart';
import '../../core/utils/snackbar_utils.dart';

const double _kSettingsCardRadius = NyanRadius.input;
const double _kSettingsHorizontalPadding = NyanSpacing.space16;
const double _kSettingsSectionGap = NyanSpacing.space24;
const double _kSettingsCardGap = NyanSpacing.space12;
const double _kSettingsRowVerticalPadding = NyanSpacing.space12;
const double _kSettingsSubRowIndent = NyanSpacing.space16;
const double _kSettingsSheetContentGap = 21;
const double _kSettingsSheetOuterPadding = _kSettingsSheetContentGap;
const double _kSettingsSheetBottomPadding = NyanSpacing.space16;
const double _kSettingsSheetHeaderGap = NyanSpacing.space12;

void _showSettingsLoadingDialog(
  BuildContext context, {
  required String title,
  required String description,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: NyanOverlayStyle.modalBarrierColor(context),
    builder: (dialogContext) => NyanProgressDialog(
      title: title,
      description: description,
    ),
  );
}

void _closeSettingsDialog(BuildContext context) {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (navigator.canPop()) {
    navigator.pop();
  }
}

Future<void> _showExportActionsSheet(
  BuildContext context,
  String exportFilePath,
) async {
  final loc = AppLocalizations.of(context)!;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);

      return NyanBottomSheet(
        title: loc.exportData,
        titleStyle: NyanSheetAppearance.compactTitleStyle(theme),
        description: loc.exportDataSubtitle,
        descriptionStyle: NyanSheetAppearance.compactDescriptionStyle(theme),
        handleColor: NyanSheetAppearance.compactHandleColor(theme),
        contentPadding: EdgeInsets.only(
          left: _kSettingsSheetOuterPadding,
          right: _kSettingsSheetOuterPadding,
          top: NyanSpacing.space12,
          bottom:
              _kSettingsSheetBottomPadding +
              MediaQuery.of(sheetContext).padding.bottom,
        ),
        titleTopSpacing: NyanSpacing.space8,
        titleChildSpacing: _kSettingsSheetHeaderGap,
        child: NyanSheetCard(
          children: [
            NyanActionSheetRow(
              icon: Icons.download_rounded,
              title: loc.saveToDevice,
              subtitle: loc.saveToDeviceSubtitle,
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final savedPath = await FilePicker.platform.saveFile(
                  dialogTitle: loc.saveToDevice,
                  fileName: 'nyan_read_export.json',
                  bytes: await File(exportFilePath).readAsBytes(),
                );
                if (savedPath != null && context.mounted) {
                  SnackBarUtils.show(context, 'Saved to: $savedPath');
                }
              },
            ),
            const NyanSheetDivider(),
            NyanActionSheetRow(
              icon: Icons.share_rounded,
              title: loc.shareVia,
              subtitle: loc.shareViaSubtitle,
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final xFile =
                    XFile(exportFilePath, mimeType: 'application/json');
                await Share.shareXFiles([xFile], subject: 'Nyan Read Export');
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _handleExportData(BuildContext context) async {
  final loc = AppLocalizations.of(context)!;
  _showSettingsLoadingDialog(
    context,
    title: loc.exportData,
    description: loc.exportDataSubtitle,
  );

  try {
    final backupService = getIt<BackupRecoveryService>();
    final exportFilePath = await backupService.exportGlobalUserData();
    if (context.mounted) {
      _closeSettingsDialog(context);
    }

    if (!context.mounted) return;
    await _showExportActionsSheet(context, exportFilePath);
  } catch (e) {
    if (context.mounted) {
      _closeSettingsDialog(context);
      SnackBarUtils.show(
        context,
        'Export failed: $e',
        tone: NyanSnackTone.error,
      );
    }
  }
}

Future<void> _handleImportData(BuildContext context) async {
  final loc = AppLocalizations.of(context)!;

  _showSettingsLoadingDialog(
    context,
    title: loc.importData,
    description: loc.importDataSubtitle,
  );

  try {
    final backupService = getIt<BackupRecoveryService>();
    final restoredCount = await backupService.importGlobalUserData();

    if (context.mounted) {
      _closeSettingsDialog(context);
    }
    if (!context.mounted) return;

    if (restoredCount == -1) return;
    SnackBarUtils.show(
      context,
      loc.importSuccess(restoredCount),
      tone: NyanSnackTone.success,
    );
  } catch (e) {
    if (context.mounted) {
      _closeSettingsDialog(context);
      SnackBarUtils.show(
        context,
        loc.importFailed(e.toString()),
        tone: NyanSnackTone.error,
      );
    }
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    ReadingReminderService.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeManager = context.watch<ThemeManager>();
    final featureManager = context.watch<FeatureManager>();
    final languageManager = context.watch<LanguageManager>();
    final readerPrefs = getIt<ReaderPreferencesService>();
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: NyanSpacing.minTapTarget + NyanSpacing.space12,
        titleSpacing: NyanSpacing.space4,
        centerTitle: false,
        title: Text(
          loc.settingsTitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          _kSettingsHorizontalPadding,
          _kSettingsHorizontalPadding,
          _kSettingsHorizontalPadding,
          _kSettingsHorizontalPadding + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          _SectionHeader(title: loc.appearance),
          _SettingsCard(
            children: [
              _SelectionRow(
                title: loc.themePreset,
                valueLabel: _getThemeName(themeManager.currentPreset, loc),
                onTap: () async {
                  final preset = await showNyanSelectionSheet<ThemePreset>(
                    context: context,
                    title: loc.themePreset,
                    currentValue: themeManager.currentPreset,
                    options: themePresets.values
                        .map(
                          (theme) => NyanSelectionOption(
                            value: theme.preset,
                            label: _getThemeName(theme.preset, loc),
                          ),
                        )
                        .toList(),
                  );
                  if (preset != null) {
                    await themeManager.setPreset(preset);
                  }
                },
              ),
              const _SettingsDivider(),
              _SelectionRow(
                title: loc.language,
                valueLabel: languageManager.locale.languageCode == 'zh'
                    ? '\u4E2D\u6587'
                    : 'English',
                onTap: () async {
                  final locale = await showNyanSelectionSheet<Locale>(
                    context: context,
                    title: loc.language,
                    currentValue: languageManager.locale,
                    options: const [
                      NyanSelectionOption(value: Locale('zh'), label: '\u4E2D\u6587'),
                      NyanSelectionOption(value: Locale('en'), label: 'English'),
                    ],
                  );
                  if (locale != null) {
                    await languageManager.setLocale(locale);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: _kSettingsSectionGap),
          _SectionHeader(title: loc.readingSettings),
          ListenableBuilder(
            listenable: Listenable.merge(
              [readerPrefs, ReadingReminderService.instance],
            ),
            builder: (context, child) {
              final reminderService = ReadingReminderService.instance;

              return _SettingsCard(
                children: [
                  _SelectionRow(
                    title: loc.pageAnimation,
                    valueLabel: _getPageAnimationLabel(
                      readerPrefs.pageAnimation,
                      loc,
                    ),
                    onTap: () async {
                      final animation = await showNyanSelectionSheet<PageAnimation>(
                        context: context,
                        title: loc.pageAnimation,
                        currentValue: readerPrefs.pageAnimation,
                        options: [
                          NyanSelectionOption(
                            value: PageAnimation.fade,
                            label: loc.pageAnimFade,
                          ),
                          NyanSelectionOption(
                            value: PageAnimation.paper,
                            label: loc.pageAnimPaper,
                          ),
                          NyanSelectionOption(
                            value: PageAnimation.none,
                            label: loc.pageAnimNone,
                          ),
                        ],
                      );
                      if (animation != null) {
                        await readerPrefs.setPageAnimation(animation);
                      }
                    },
                  ),
                  const _SettingsDivider(),
                  _SwitchRow(
                    title: loc.readingReminder,
                    subtitle: loc.readingReminderSubtitle,
                    value: reminderService.isEnabled,
                    onChanged: (value) {
                      setState(() {
                        reminderService.setEnabled(value);
                      });
                    },
                  ),
                  if (reminderService.isEnabled) ...[
                    const _SettingsDivider(),
                    _SelectionRow(
                      title: loc.reminderInterval,
                      valueLabel:
                          loc.reminderMinutes(reminderService.intervalMinutes),
                      inset: true,
                      onTap: () async {
                        final interval = await showNyanSelectionSheet<int>(
                          context: context,
                          title: loc.reminderInterval,
                          currentValue: reminderService.intervalMinutes,
                          options: [
                            NyanSelectionOption(
                              value: 30,
                              label: loc.reminderMinutes(30),
                            ),
                            NyanSelectionOption(
                              value: 60,
                              label: loc.reminderMinutes(60),
                            ),
                            NyanSelectionOption(
                              value: 90,
                              label: loc.reminderMinutes(90),
                            ),
                          ],
                        );
                        if (interval != null) {
                          setState(() {
                            reminderService.setIntervalMinutes(interval);
                          });
                        }
                      },
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: _kSettingsSectionGap),
          _SectionHeader(title: loc.dataManagement),
          _SettingsCard(
            children: [
              _ActionRow(
                icon: Icons.save_alt_rounded,
                title: loc.exportData,
                subtitle: loc.exportDataSubtitle,
                onTap: () => _handleExportData(context),
              ),
              const _SettingsDivider(),
              _ActionRow(
                icon: Icons.upload_file_rounded,
                title: loc.importData,
                subtitle: loc.importDataSubtitle,
                onTap: () => _handleImportData(context),
              ),
            ],
          ),
          const SizedBox(height: _kSettingsCardGap),
          StatefulBuilder(
            builder: (context, setLocalState) {
              final bookshelfPrefs = getIt<BookshelfPreferencesService>();
              final theme = Theme.of(context);
              final isDark = theme.brightness == Brightness.dark;
              final cautionSubtitleColor = theme.colorScheme.error.withValues(
                alpha: isDark ? 0.72 : 0.66,
              );

              return _SettingsCard(
                children: [
                  _SwitchRow(
                    title: loc.deleteFilesOnRemove,
                    subtitle: loc.deleteFilesOnRemoveSubtitle,
                    subtitleColor: cautionSubtitleColor.withValues(
                      alpha: isDark ? 0.88 : 0.8,
                    ),
                    value: bookshelfPrefs.deleteFilesOnRemove,
                    onChanged: (value) async {
                      await bookshelfPrefs.setDeleteFilesOnRemove(value);
                      setLocalState(() {});
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: _kSettingsCardGap),
          _SettingsCard(
            children: [
              _ActionRow(
                icon: Icons.admin_panel_settings_rounded,
                iconColor: Theme.of(context).textTheme.bodySmall?.color,
                title: loc.adminPanel,
                onTap: () => context.push('/admin'),
              ),
            ],
          ),
          if (!featureManager.isPro) ...[
            const SizedBox(height: _kSettingsCardGap),
            _SettingsCard(
              backgroundColor: Color.alphaBlend(
                theme.colorScheme.primary.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.11 : 0.045,
                ),
                theme.cardColor,
              ),
              borderColor: theme.colorScheme.primary.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.2 : 0.12,
              ),
              shadowAlpha: theme.brightness == Brightness.dark ? 0 : 0.024,
              children: [
                _ActionRow(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: Theme.of(context).colorScheme.primary,
                  iconBackgroundAlpha: theme.brightness == Brightness.dark ? 0.2 : 0.14,
                  titleColor: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.94),
                  chevronColor: theme.colorScheme.primary.withValues(alpha: 0.58),
                  title: loc.upgradeToPro,
                  onTap: () {
                    // TODO: Implement upgrade flow
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getPageAnimationLabel(PageAnimation animation, AppLocalizations loc) {
    switch (animation) {
      case PageAnimation.fade:
        return loc.pageAnimFade;
      case PageAnimation.paper:
        return loc.pageAnimPaper;
      case PageAnimation.none:
        return loc.pageAnimNone;
    }
  }

  String _getThemeName(ThemePreset preset, AppLocalizations loc) {
    switch (preset) {
      case ThemePreset.creamLight:
        return loc.themeCreamLight;
      case ThemePreset.sumiDark:
        return loc.themeSumiDark;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kSettingsHorizontalPadding,
        0,
        _kSettingsHorizontalPadding,
        _kSettingsCardGap,
      ),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: NyanTypography.meta,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.22,
          color: theme.colorScheme.primary.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.9 : 0.9,
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.children,
    this.backgroundColor,
    this.borderColor,
    this.shadowAlpha,
  });

  final List<Widget> children;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? shadowAlpha;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resolvedBorderColor =
        borderColor ??
        theme.dividerColor.withValues(alpha: isDark ? 0.2 : 0.16);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardColor,
        borderRadius: BorderRadius.circular(_kSettingsCardRadius),
        border: Border.all(
          color: resolvedBorderColor,
          width: 0.72,
        ),
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: shadowAlpha ?? 0.014),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kSettingsCardRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.55,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
    );
  }
}

class _SelectionRow extends StatelessWidget {
  const _SelectionRow({
    required this.title,
    required this.valueLabel,
    required this.onTap,
    this.subtitle,
    this.inset = false,
  });

  final String title;
  final String valueLabel;
  final String? subtitle;
  final VoidCallback onTap;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = theme.textTheme.bodyLarge?.color;
    final valueColorAlpha = inset ? 0.5 : 0.58;
    final chevronColorAlpha = inset ? 0.3 : 0.38;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _kSettingsHorizontalPadding + (inset ? _kSettingsSubRowIndent : 0),
          _kSettingsRowVerticalPadding,
          _kSettingsHorizontalPadding,
          _kSettingsRowVerticalPadding,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: (inset
                            ? theme.textTheme.bodyMedium
                            : theme.textTheme.bodyLarge)
                        ?.copyWith(
                      fontWeight: inset ? FontWeight.w500 : FontWeight.w600,
                      color: titleColor?.withValues(
                        alpha: inset ? 0.82 : 1,
                      ),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: NyanSpacing.space4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.3,
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: NyanSpacing.space12),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: NyanSpacing.minTapTarget,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    valueLabel,
                    style: (inset
                            ? theme.textTheme.bodyMedium
                            : theme.textTheme.bodyLarge)
                        ?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: titleColor?.withValues(
                        alpha: valueColorAlpha,
                      ),
                    ),
                  ),
                  const SizedBox(width: NyanSpacing.space4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: chevronColorAlpha,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.titleColor,
    this.subtitleColor,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? titleColor;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kSettingsHorizontalPadding,
        _kSettingsRowVerticalPadding,
        _kSettingsHorizontalPadding,
        _kSettingsRowVerticalPadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: NyanSpacing.space4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.3,
                      color:
                          subtitleColor ??
                          theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.8,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: NyanSpacing.space12),
          Theme(
            data: theme.copyWith(
              switchTheme: SwitchThemeData(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                splashRadius: 24,
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return isDark
                        ? theme.colorScheme.onPrimary.withValues(alpha: 0.96)
                        : theme.cardColor;
                  }
                  return isDark
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.46)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6);
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return theme.colorScheme.primary.withValues(
                      alpha: isDark ? 0.64 : 0.68,
                    );
                  }
                  return theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: isDark ? 0.38 : 0.46,
                  );
                }),
                trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.transparent;
                  }
                  return theme.dividerColor.withValues(
                    alpha: isDark ? 0.14 : 0.18,
                  );
                }),
                overlayColor: WidgetStateProperty.all(Colors.transparent),
              ),
            ),
            child: Switch(
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.titleColor,
    this.titleWeight = FontWeight.w600,
    this.subtitleColor,
    this.chevronColor,
    this.iconBackgroundAlpha,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;
  final FontWeight titleWeight;
  final Color? subtitleColor;
  final Color? chevronColor;
  final double? iconBackgroundAlpha;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = iconColor ?? theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _kSettingsHorizontalPadding,
          _kSettingsRowVerticalPadding,
          _kSettingsHorizontalPadding,
          _kSettingsRowVerticalPadding,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tone.withValues(
                  alpha:
                      iconBackgroundAlpha ??
                      (theme.brightness == Brightness.dark ? 0.12 : 0.08),
                ),
                borderRadius: BorderRadius.circular(NyanRadius.small),
              ),
              child: Icon(icon, color: tone, size: 17),
            ),
            const SizedBox(width: NyanSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: titleWeight,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: NyanSpacing.space4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.3,
                        color:
                            subtitleColor ??
                            theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.78,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: NyanSpacing.space12),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color:
                  chevronColor ??
                  theme.textTheme.bodySmall?.color?.withValues(alpha: 0.56),
            ),
          ],
        ),
      ),
    );
  }
}
