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

const double _kSettingsCardRadius = NyanRadius.input;
const double _kSettingsHorizontalPadding = NyanSpacing.space16;
const double _kSettingsSectionGap = NyanSpacing.space24;
const double _kSettingsCardGap = NyanSpacing.space12;
const double _kSettingsRowVerticalPadding = NyanSpacing.space12;
const double _kSettingsSheetVerticalPadding = NyanSpacing.space12;
const double _kSettingsSheetContentGap = 21;
const double _kSettingsSheetOuterPadding = _kSettingsSheetContentGap;

void _showSettingsLoadingDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);

      return PopScope(
        canPop: false,
        child: Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(NyanRadius.panel),
                border: Border.all(
                  color: theme.dividerColor.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.24 : 0.16,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _closeSettingsDialog(BuildContext context) {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (navigator.canPop()) {
    navigator.pop();
  }
}

Future<T?> _showSelectionSheet<T>({
  required BuildContext context,
  required String title,
  String? description,
  required T currentValue,
  required List<_SelectionOption<T>> options,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _SettingsSheetFrame(
        title: title,
        description: description,
        child: _SheetCard(
          children: [
            for (var index = 0; index < options.length; index++) ...[
              _SelectionSheetRow<T>(
                option: options[index],
                isSelected: options[index].value == currentValue,
                onTap: () => Navigator.of(sheetContext).pop(options[index].value),
              ),
              if (index != options.length - 1) const _SheetDivider(),
            ],
          ],
        ),
      );
    },
  );
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
      return _SettingsSheetFrame(
        title: loc.exportData,
        description: loc.exportDataSubtitle,
        child: _SheetCard(
          children: [
            _SheetActionRow(
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved to: $savedPath')),
                  );
                }
              },
            ),
            const _SheetDivider(),
            _SheetActionRow(
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
  _showSettingsLoadingDialog(context);

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}

Future<void> _handleImportData(BuildContext context) async {
  final loc = AppLocalizations.of(context)!;

  _showSettingsLoadingDialog(context);

  try {
    final backupService = getIt<BackupRecoveryService>();
    final restoredCount = await backupService.importGlobalUserData();

    if (context.mounted) {
      _closeSettingsDialog(context);
    }
    if (!context.mounted) return;

    if (restoredCount == -1) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.importSuccess(restoredCount)),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (context.mounted) {
      _closeSettingsDialog(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.importFailed(e.toString())),
          backgroundColor: Colors.red,
        ),
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
                  final preset = await _showSelectionSheet<ThemePreset>(
                    context: context,
                    title: loc.themePreset,
                    currentValue: themeManager.currentPreset,
                    options: themePresets.values
                        .map(
                          (theme) => _SelectionOption(
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
                    ? '中文'
                    : 'English',
                onTap: () async {
                  final locale = await _showSelectionSheet<Locale>(
                    context: context,
                    title: loc.language,
                    currentValue: languageManager.locale,
                    options: const [
                      _SelectionOption(value: Locale('zh'), label: '中文'),
                      _SelectionOption(value: Locale('en'), label: 'English'),
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
                      final animation = await _showSelectionSheet<PageAnimation>(
                        context: context,
                        title: loc.pageAnimation,
                        currentValue: readerPrefs.pageAnimation,
                        options: [
                          _SelectionOption(
                            value: PageAnimation.fade,
                            label: loc.pageAnimFade,
                          ),
                          _SelectionOption(
                            value: PageAnimation.paper,
                            label: loc.pageAnimPaper,
                          ),
                          _SelectionOption(
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
                        final interval = await _showSelectionSheet<int>(
                          context: context,
                          title: loc.reminderInterval,
                          currentValue: reminderService.intervalMinutes,
                          options: [
                            _SelectionOption(
                              value: 30,
                              label: loc.reminderMinutes(30),
                            ),
                            _SelectionOption(
                              value: 60,
                              label: loc.reminderMinutes(60),
                            ),
                            _SelectionOption(
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

              return _SettingsCard(
                children: [
                  _SwitchRow(
                    title: loc.deleteFilesOnRemove,
                    subtitle: loc.deleteFilesOnRemoveSubtitle,
                    value: bookshelfPrefs.deleteFilesOnRemove,
                    onChanged: (value) async {
                      await bookshelfPrefs.setDeleteFilesOnRemove(value);
                      setLocalState(() {});
                    },
                  ),
                  if (featureManager.isPro) ...[
                    const _SettingsDivider(),
                    _SwitchRow(
                      title: loc.lockPrivateShelf,
                      value: true,
                      onChanged: (value) {
                        // TODO: Implement lock private shelf
                      },
                    ),
                  ],
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
              children: [
                _ActionRow(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: Theme.of(context).colorScheme.primary,
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
          fontWeight: FontWeight.w600,
          letterSpacing: 0.16,
          color: theme.colorScheme.primary.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.78 : 0.82,
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(_kSettingsCardRadius),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: isDark ? 0.2 : 0.16),
          width: 0.72,
        ),
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.014),
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

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
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
                      fontWeight: inset ? FontWeight.w500 : FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color?.withValues(
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
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.textTheme.bodyLarge?.color?.withValues(
                        alpha: inset ? 0.58 : 0.66,
                      ),
                    ),
                  ),
                  const SizedBox(width: NyanSpacing.space4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.46,
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
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

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
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.54)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.78);
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return theme.colorScheme.primary.withValues(
                      alpha: isDark ? 0.64 : 0.68,
                    );
                  }
                  return theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: isDark ? 0.52 : 0.72,
                  );
                }),
                trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.transparent;
                  }
                  return theme.dividerColor.withValues(
                    alpha: isDark ? 0.18 : 0.24,
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
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

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
                  alpha: theme.brightness == Brightness.dark ? 0.12 : 0.08,
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: NyanSpacing.space4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.3,
                        color: theme.textTheme.bodySmall?.color?.withValues(
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
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.56),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetCard extends StatelessWidget {
  const _SheetCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(_kSettingsCardRadius),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.14),
        ),
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

class _SettingsSheetFrame extends StatelessWidget {
  const _SettingsSheetFrame({
    required this.title,
    required this.child,
    this.description,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final sheetTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.copyWith(
        titleLarge: baseTheme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: baseTheme.textTheme.titleMedium?.color?.withValues(alpha: 0.92),
          height: 1.1,
        ),
        bodyMedium: baseTheme.textTheme.bodySmall?.copyWith(
          color: baseTheme.textTheme.bodySmall?.color?.withValues(alpha: 0.72),
          height: 1.3,
        ),
      ),
    );

    return Theme(
      data: sheetTheme,
      child: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            final theme = Theme.of(context);

            return DecoratedBox(
              decoration: BoxDecoration(
                color: theme.bottomSheetTheme.backgroundColor ?? theme.cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(NyanRadius.panel),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _kSettingsSheetOuterPadding,
                  NyanSpacing.space12,
                  _kSettingsSheetOuterPadding,
                  _kSettingsSheetContentGap,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: NyanSpacing.space4,
                        decoration: BoxDecoration(
                          color: theme.dividerColor.withValues(alpha: 0.44),
                          borderRadius: BorderRadius.circular(NyanRadius.small),
                        ),
                      ),
                    ),
                    const SizedBox(height: NyanSpacing.space8),
                    Text(title, style: theme.textTheme.titleLarge),
                    if (description != null) ...[
                      const SizedBox(height: NyanSpacing.space4),
                      Text(
                        description!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: _kSettingsSheetContentGap),
                    child,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SheetDivider extends StatelessWidget {
  const _SheetDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.55,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
    );
  }
}

class _SelectionSheetRow<T> extends StatelessWidget {
  const _SelectionSheetRow({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _SelectionOption<T> option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      color: isSelected
          ? theme.colorScheme.primary.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.09 : 0.055,
            )
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _kSettingsHorizontalPadding,
            vertical: _kSettingsSheetVerticalPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.88)
                            : theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    if (option.description != null) ...[
                      const SizedBox(height: NyanSpacing.space4),
                      Text(
                        option.description!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: NyanSpacing.space12),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: isSelected ? 1 : 0,
                child: Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: theme.colorScheme.primary.withValues(alpha: 0.84),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetActionRow extends StatelessWidget {
  const _SheetActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _kSettingsHorizontalPadding,
          vertical: _kSettingsSheetVerticalPadding,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(NyanRadius.small),
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 17,
              ),
            ),
            const SizedBox(width: NyanSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: NyanSpacing.space4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
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

class _SelectionOption<T> {
  const _SelectionOption({
    required this.value,
    required this.label,
    this.description,
  });

  final T value;
  final String label;
  final String? description;
}
