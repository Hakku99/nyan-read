import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/backup_recovery_service.dart';
import '../../core/services/bookshelf_preferences_service.dart';
import '../../core/services/riverpod_providers.dart';
import 'reading_settings_page.dart';
import '../../core/services/service_locator.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/theme/nyan_typography.dart';
import '../../core/theme/theme_presets.dart';
import '../../core/ui/components/components.dart';
import '../../core/ui/nyan_icons.dart';
import '../../core/ui/nyan_theme_context.dart';
import '../../core/utils/snackbar_utils.dart';

const double _kSettingsHorizontalPadding = NyanSpacing.space16;
const double _kSettingsSectionGap = NyanSpacing.space24;

/// Hardcoded until package_info_plus is added to pubspec.yaml.
/// TODO(#package-info): replace with PackageInfo.fromPlatform() build string.
const String _kAppVersion = 'v1.0.0';

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
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
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
          left: _kSettingsHorizontalPadding,
          right: _kSettingsHorizontalPadding,
          top: NyanSpacing.space12,
          bottom: NyanSpacing.space16 +
              MediaQuery.of(sheetContext).padding.bottom,
        ),
        titleTopSpacing: NyanSpacing.space8,
        titleChildSpacing: NyanSpacing.space12,
        child: NyanSheetCard(
          children: [
            NyanActionSheetRow(
              icon: NyanIcons.download,
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
              icon: NyanIcons.share,
              title: loc.shareVia,
              subtitle: loc.shareViaSubtitle,
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final xFile =
                    XFile(exportFilePath, mimeType: 'application/json');
                await SharePlus.instance.share(
                  ShareParams(
                    files: [xFile],
                    subject: 'Nyan Read Export',
                  ),
                );
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

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final themeManager = ref.read(themeManagerRpProvider);
    final featureManager = ref.read(featureManagerRpProvider);
    final languageManager = ref.read(languageManagerRpProvider);
    final reminderService = ref.read(readingReminderRpProvider);
    final readerPrefs = ref.read(readerPreferencesRpProvider);

    return ListenableBuilder(
      listenable: Listenable.merge([
        themeManager,
        featureManager,
        languageManager,
        reminderService,
      ]),
      builder: (context, _) {
        final loc = AppLocalizations.of(context)!;
        final bottomInset = MediaQuery.paddingOf(context).bottom;

        // Show "Pro" section only when there is something actionable in it.
        final showProSection =
            !featureManager.isPro || featureManager.privacyShelfEnabled;

        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pinned header — stays fixed while the list scrolls.
              SafeArea(
                bottom: false,
                child: NyanPageHeader(
                  title: loc.settingsTitle,
                  leading: NyanRecessedIconButton(
                    icon: NyanIcons.back,
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    _kSettingsHorizontalPadding,
                    0,
                    _kSettingsHorizontalPadding,
                    _kSettingsHorizontalPadding + bottomInset,
                  ),
                  children: [
                    // ── Appearance ───────────────────────────────────────
                    NyanSectionHeader(title: loc.appearance),
                    NyanRowGroup(
                      children: [
                        NyanListRow(
                          leadingIcon: NyanIcons.palette,
                          title: loc.themePreset,
                          subtitle: _getThemeName(
                            themeManager.currentPreset,
                            loc,
                          ),
                          showChevron: true,
                          onTap: () async {
                            final preset =
                                await showNyanChipSelectionSheet<ThemePreset>(
                              context: context,
                              title: loc.themePreset,
                              currentValue: themeManager.currentPreset,
                              options: themePresets.values
                                  .map(
                                    (t) => NyanSelectionOption(
                                      value: t.preset,
                                      label: _getThemeName(t.preset, loc),
                                    ),
                                  )
                                  .toList(),
                            );
                            if (preset != null) {
                              await themeManager.setPreset(preset);
                            }
                          },
                        ),
                        NyanListRow(
                          leadingIcon: NyanIcons.language,
                          title: loc.language,
                          subtitle: languageManager.locale.languageCode == 'zh'
                              ? '中文'
                              : 'English',
                          showChevron: true,
                          onTap: () async {
                            final locale =
                                await showNyanChipSelectionSheet<Locale>(
                              context: context,
                              title: loc.language,
                              currentValue: languageManager.locale,
                              options: const [
                                NyanSelectionOption(
                                  value: Locale('zh'),
                                  label: '中文',
                                ),
                                NyanSelectionOption(
                                  value: Locale('en'),
                                  label: 'English',
                                ),
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

                    // ── Reading ──────────────────────────────────────────
                    NyanSectionHeader(title: loc.readingSettings),
                    ListenableBuilder(
                      listenable: Listenable.merge(
                        [readerPrefs, reminderService],
                      ),
                      builder: (context, _) {
                        // Subtitle summarises the two most user-visible prefs
                        // so the row is informative without needing to open it.
                        final fontLabel = readerPrefs.useSerif
                            ? loc.readerFontFamilySerif
                            : loc.readerFontFamilySans;
                        final sizeLabel =
                            '${readerPrefs.fontSize.toStringAsFixed(0)}pt';

                        return NyanRowGroup(
                          children: [
                            // Reading Settings shortcut — per SettingsScreen.jsx.
                            // Page Turn Mode now lives inside the reader sheet;
                            // font / size / layout prefs are set here.
                            NyanListRow(
                              leadingIcon: NyanIcons.book,
                              title: loc.readingSettings,
                              subtitle: '$sizeLabel · $fontLabel',
                              showChevron: true,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ReadingSettingsPage(),
                                ),
                              ),
                            ),
                            NyanListRow(
                              leadingIcon: NyanIcons.alarm,
                              title: loc.readingReminder,
                              subtitle: loc.readingReminderSubtitle,
                              trailing: NyanSwitch(
                                value: reminderService.isEnabled,
                                onChanged: (value) {
                                  reminderService.setEnabled(value);
                                },
                              ),
                            ),
                            if (reminderService.isEnabled)
                              NyanListRow(
                                title: loc.reminderInterval,
                                subtitle: loc.reminderMinutes(
                                  reminderService.intervalMinutes,
                                ),
                                // Sub-row indented under Reading Reminder —
                                // no icon chip, reduced left padding.
                                contentPadding: const EdgeInsets.fromLTRB(
                                  NyanSpacing.space16 + NyanSpacing.space16,
                                  NyanSpacing.space12,
                                  NyanSpacing.space16,
                                  NyanSpacing.space12,
                                ),
                                showChevron: true,
                                onTap: () async {
                                  final interval =
                                      await showNyanChipSelectionSheet<int>(
                                    context: context,
                                    title: loc.reminderInterval,
                                    currentValue:
                                        reminderService.intervalMinutes,
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
                                    reminderService.setIntervalMinutes(
                                      interval,
                                    );
                                  }
                                },
                              ),
                            StatefulBuilder(
                              builder: (context, setLocalState) {
                                final bookshelfPrefs =
                                    getIt<BookshelfPreferencesService>();
                                return NyanListRow(
                                  leadingIcon: NyanIcons.delete,
                                  title: loc.deleteFilesOnRemove,
                                  subtitle: loc.deleteFilesOnRemoveSubtitle,
                                  trailing: NyanSwitch(
                                    value: bookshelfPrefs.deleteFilesOnRemove,
                                    onChanged: (value) async {
                                      await bookshelfPrefs
                                          .setDeleteFilesOnRemove(value);
                                      setLocalState(() {});
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: _kSettingsSectionGap),

                    // ── Data Management ──────────────────────────────────
                    NyanSectionHeader(title: loc.dataManagement),
                    NyanRowGroup(
                      children: [
                        NyanListRow(
                          leadingIcon: NyanIcons.shareIos,
                          title: loc.exportData,
                          subtitle: loc.exportDataSubtitle,
                          showChevron: true,
                          onTap: () => _handleExportData(context),
                        ),
                        NyanListRow(
                          leadingIcon: NyanIcons.cloudDownload,
                          title: loc.importData,
                          subtitle: loc.importDataSubtitle,
                          showChevron: true,
                          onTap: () => _handleImportData(context),
                        ),
                        // Admin Panel removed from user-facing Settings per
                        // SettingsScreen.jsx spec — still accessible at /admin
                        // for internal use during development.
                      ],
                    ),

                    // ── Pro ──────────────────────────────────────────────
                    if (showProSection) ...[
                      const SizedBox(height: _kSettingsSectionGap),
                      NyanSectionHeader(title: loc.pro),
                      NyanRowGroup(
                        children: [
                          if (featureManager.privacyShelfEnabled)
                            NyanListRow(
                              leadingIcon: NyanIcons.lockOpen,
                              title: loc.lockPrivacyShelf,
                              subtitle: loc.lockPrivacyShelfSubtitle,
                              showChevron: true,
                              onTap: () => context.push('/admin'),
                            ),
                          if (!featureManager.isPro)
                            NyanListRow(
                              leadingIcon: NyanIcons.sparkle,
                              title: loc.upgradeToPro,
                              subtitle: loc.upgradeToProSubtitle,
                              showChevron: true,
                              onTap: () {
                                // TODO(#upgrade): implement upgrade flow.
                              },
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: _kSettingsSectionGap),

                    // ── About ────────────────────────────────────────────
                    NyanSectionHeader(title: loc.about),
                    _AboutCard(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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

/// About card — app identity block.
///
/// Logo is the redesigned flat One Paper brand mark `nyan_mark_v2.png`
/// (HANDOFF-flutter.md §3: the old gradient/3D render is retired). This
/// deliberately follows the bridge doc's explicit instruction over the older
/// `SettingsScreen.jsx` mock, which still referenced the retired logo asset.
class _AboutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    return NyanInfoCard(
      variant: NyanInfoCardVariant.grouped,
      padding: const EdgeInsets.symmetric(
        horizontal: NyanSpacing.space16,
        vertical: NyanSpacing.space20,
      ),
      child: Row(
        children: [
          // Logo — 56×56 flat One Paper brand mark (nyan_mark_v2).
          Image.asset(
            'assets/images/nyan_mark_v2.png',
            width: 56,
            height: 56,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nyan Read',
                style: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  // Spec: 18pt app name in About card.
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: nyan.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$_kAppVersion · ฅ^•ﻌ•^ฅ',
                style: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  fontSize: NyanTypography.meta,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                  color: nyan.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
