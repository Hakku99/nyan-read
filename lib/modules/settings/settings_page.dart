import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_manager.dart';
import '../../core/services/feature_manager.dart';
import '../../core/services/reader_preferences_service.dart';
import '../../core/services/bookshelf_preferences_service.dart';
import '../../core/services/reading_reminder_service.dart';
import '../../core/services/language_manager.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import '../../core/theme/theme_presets.dart';
import '../../core/services/service_locator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../core/services/backup_recovery_service.dart';

Future<void> _handleExportData(BuildContext context) async {
  // 1. 挂载 Loading 遮罩
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final backupService = getIt<BackupRecoveryService>();
    final exportFilePath = await backupService.exportGlobalUserData();
    if (context.mounted) Navigator.pop(context); // 关闭 Loading

    if (!context.mounted) return;

    // 2. 弹出选择面板：保存到本地 or 系统分享
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        // 在 Builder 内从外层 context 取 loc（外层 context 的 Localizations已挂载完成）
        final loc = AppLocalizations.of(context)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: Text(loc.saveToDevice),
                subtitle: Text(loc.saveToDeviceSubtitle),
                onTap: () async {
                  Navigator.pop(sheetContext);
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
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: Text(loc.shareVia),
                subtitle: Text(loc.shareViaSubtitle),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final xFile =
                      XFile(exportFilePath, mimeType: 'application/json');
                  await Share.shareXFiles([xFile], subject: 'Nyan Read Export');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context); // 出错时关闭 Loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}

Future<void> _handleImportData(BuildContext context) async {
  final loc = AppLocalizations.of(context)!;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final backupService = getIt<BackupRecoveryService>();
    final restoredCount = await backupService.importGlobalUserData();

    if (context.mounted) Navigator.pop(context);
    if (!context.mounted) return;

    if (restoredCount == -1) return; // 用户取消，静默

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.importSuccess(restoredCount)),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
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
    final themeManager = context.watch<ThemeManager>();
    final featureManager = context.watch<FeatureManager>();
    final languageManager = context.watch<LanguageManager>();
    final readerPrefs = getIt<ReaderPreferencesService>();
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.settingsTitle),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          24,
          16,
          // SafeArea fix: 避免内容被底部导航栏遮挡
          16 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          // Appearance Section
          _SectionHeader(title: loc.appearance.toUpperCase()),
          _SettingsCard(
            children: [
              _SettingRow(
                title: loc.themePreset,
                verticalPadding: 10,
                trailing: DropdownButton<ThemePreset>(
                  value: themeManager.currentPreset,
                  underline: const SizedBox(),
                  onChanged: (ThemePreset? val) {
                    if (val != null) themeManager.setPreset(val);
                  },
                  items: themePresets.values.map((theme) {
                    return DropdownMenuItem<ThemePreset>(
                      value: theme.preset,
                      child: Text(_getThemeName(theme.preset, loc)),
                    );
                  }).toList(),
                ),
              ),
              Divider(
                  height: 1,
                  thickness: 0.5,
                  color: theme.dividerColor.withOpacity(0.15)),
              _SettingRow(
                title: loc.language,
                verticalPadding: 10,
                trailing: DropdownButton<Locale>(
                  value: languageManager.locale,
                  underline: const SizedBox(),
                  onChanged: (Locale? val) {
                    if (val != null) languageManager.setLocale(val);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: Locale('en'),
                      child: Text('English'),
                    ),
                    DropdownMenuItem(
                      value: Locale('zh'),
                      child: Text('中文', overflow: TextOverflow.clip),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Reading Section
          _SectionHeader(title: loc.readingSettings.toUpperCase()),
          ListenableBuilder(
            listenable: Listenable.merge(
                [readerPrefs, ReadingReminderService.instance]),
            builder: (context, child) {
              final reminderService = ReadingReminderService.instance;
              return _SettingsCard(
                children: [
                  _SettingRow(
                    title: loc.pageAnimation,
                    subtitle:
                        _getPageAnimationLabel(readerPrefs.pageAnimation, loc),
                    trailing: DropdownButton<PageAnimation>(
                      value: readerPrefs.pageAnimation,
                      underline: const SizedBox(),
                      onChanged: (PageAnimation? val) {
                        if (val != null) readerPrefs.setPageAnimation(val);
                      },
                      items: [
                        DropdownMenuItem(
                          value: PageAnimation.fade,
                          child: Text(loc.pageAnimFade),
                        ),
                        DropdownMenuItem(
                          value: PageAnimation.paper,
                          child: Text(loc.pageAnimPaper),
                        ),
                        DropdownMenuItem(
                          value: PageAnimation.none,
                          child: Text(loc.pageAnimNone),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                      height: 1,
                      thickness: 0.5,
                      color: theme.dividerColor.withOpacity(0.15)),
                  _SwitchRow(
                    title: loc.readingReminder,
                    subtitle: loc.readingReminderSubtitle,
                    value: reminderService.isEnabled,
                    onChanged: (val) {
                      setState(() {
                        reminderService.setEnabled(val);
                      });
                    },
                  ),
                  if (reminderService.isEnabled) ...[
                    Divider(
                        height: 1,
                        thickness: 0.5,
                        color: theme.dividerColor.withOpacity(0.15)),
                    _SettingRow(
                      title: loc.reminderInterval,
                      trailing: DropdownButton<int>(
                        value: reminderService.intervalMinutes,
                        underline: const SizedBox(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              reminderService.setIntervalMinutes(val);
                            });
                          }
                        },
                        items: [
                          DropdownMenuItem(
                            value: 30,
                            child: Text(loc.reminderMinutes(30)),
                          ),
                          DropdownMenuItem(
                            value: 60,
                            child: Text(loc.reminderMinutes(60)),
                          ),
                          DropdownMenuItem(
                            value: 90,
                            child: Text(loc.reminderMinutes(90)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Data & Privacy Section
          _SectionHeader(title: loc.dataManagement.toUpperCase()),
          _SettingsCard(
            children: [
              _SettingRow(
                icon: Icons.save_alt,
                title: loc.exportData,
                subtitle: loc.exportDataSubtitle,
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _handleExportData(context),
              ),
              Divider(
                  height: 1,
                  thickness: 0.5,
                  color: theme.dividerColor.withOpacity(0.15)),
              _SettingRow(
                icon: Icons.upload_file_rounded,
                title: loc.importData,
                subtitle: loc.importDataSubtitle,
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _handleImportData(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StatefulBuilder(
            builder: (context, setState) {
              final bookshelfPrefs = getIt<BookshelfPreferencesService>();
              return _SettingsCard(
                children: [
                  _SwitchRow(
                    title: loc.deleteFilesOnRemove,
                    subtitle: loc.deleteFilesOnRemoveSubtitle,
                    value: bookshelfPrefs.deleteFilesOnRemove,
                    onChanged: (val) async {
                      await bookshelfPrefs.setDeleteFilesOnRemove(val);
                      setState(() {});
                    },
                  ),
                  if (featureManager.isPro) ...[
                    Divider(
                        height: 1,
                        thickness: 0.5,
                        color: theme.dividerColor.withOpacity(0.15)),
                    _SwitchRow(
                      title: loc.lockPrivateShelf,
                      value: true,
                      onChanged: (val) {
                        // TODO: Implement lock private shelf
                      },
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Admin Panel
          _SettingsCard(
            children: [
              _SettingRow(
                icon: Icons.admin_panel_settings,
                title: loc.adminPanel,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push('/admin');
                },
              ),
            ],
          ),

          // Pro/Ads Section (if not pro)
          if (!featureManager.isPro) ...[
            const SizedBox(height: 24),
            _SettingsCard(
              children: [
                _SettingRow(
                  icon: Icons.star,
                  iconColor: Colors.amber,
                  title: loc.upgradeToPro,
                  trailing: const Icon(Icons.chevron_right),
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
        return loc.pageAnimationFade;
      case PageAnimation.paper:
        return loc.pageAnimationPaper;
      case PageAnimation.none:
        return loc.pageAnimationNone;
    }
  }

  String _getThemeName(ThemePreset preset, AppLocalizations loc) {
    switch (preset) {
      case ThemePreset.creamLight:
        return loc.themeCreamLight;
      case ThemePreset.sumiDark:
        return loc.themeSumiDark;
      case ThemePreset.sepiaWarm:
        return loc.themeSepiaWarm;
    }
  }
}

// Section Header Widget
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}

// Settings Card Widget
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : theme.dividerColor.withOpacity(0.3),
          width: 0.5,
        ),
        boxShadow: isDark
            ? [] // Remove shadow in dark mode for flat "ink on paper" look
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

// Setting Row Widget
class _SettingRow extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double? verticalPadding;

  const _SettingRow({
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.verticalPadding,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: 16, vertical: verticalPadding ?? 14),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

// Switch Row Widget
class _SwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
