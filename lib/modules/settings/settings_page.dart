import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/reader_preferences_service.dart';
import '../../core/services/riverpod_providers.dart';
import '../../core/theme/nyan_colors.dart';
import '../../core/theme/nyan_radius.dart';
import '../../core/theme/nyan_shadows.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/theme/nyan_typography.dart';
import '../../core/theme/theme_presets.dart';
import '../../core/ui/components/components.dart';
import '../../core/ui/nyan_icons.dart';
import '../../core/ui/nyan_theme_context.dart';
import '../../core/utils/snackbar_utils.dart';

const double _kHPad = NyanSpacing.space16;

/// Hardcoded until package_info_plus is added to pubspec.yaml.
/// TODO(#package-info): replace with PackageInfo.fromPlatform() build string.
const String _kAppVersion = 'v1.0.0';

// ── Valid reminder interval values (minutes) in picker order ─────────────────
const List<int> _kReminderIntervals = [15, 30, 45, 60, 90];

// ── Loading / dismiss helpers ─────────────────────────────────────────────────

void _showLoadingDialog(
  BuildContext context, {
  required String title,
  required String description,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: NyanOverlayStyle.modalBarrierColor(context),
    builder: (_) => NyanProgressDialog(title: title, description: description),
  );
}

void _closeDialog(BuildContext context) {
  final nav = Navigator.of(context, rootNavigator: true);
  if (nav.canPop()) nav.pop();
}

// ── Export flow ───────────────────────────────────────────────────────────────

Future<void> _handleExportData(BuildContext context, WidgetRef ref) async {
  final loc = AppLocalizations.of(context)!;
  final backupService = ref.read(backupRecoveryServiceRpProvider);

  // Privacy gate: the export bundles every shelf including private books
  // (excluding them would make restores silently lossy), so exporting while
  // the private shelf is locked must re-prove the PIN first — otherwise
  // Settings → Export → Share walks the private catalogue out in three taps.
  final bool gateRequired;
  try {
    gateRequired = !ref.read(featureManagerRpProvider).isPrivateShelfUnlocked &&
        await ref.read(privacyLockServiceRpProvider).hasPassword() &&
        await backupService.hasPrivateBooks();
  } catch (e) {
    debugPrint('Export privacy gate check failed: $e');
    if (context.mounted) {
      SnackBarUtils.show(context, loc.exportFailed(e.toString()),
          tone: NyanSnackTone.error);
    }
    return;
  }
  if (gateRequired) {
    if (!context.mounted) return;
    final verified =
        await ref.read(privacyLockServiceRpProvider).showPinVerify(context);
    if (!verified) return;
  }

  if (!context.mounted) return;
  _showLoadingDialog(
    context,
    title: loc.exportData,
    description: loc.exportDataSubtitle,
  );

  try {
    final exportFilePath = await backupService.exportGlobalUserData();
    if (context.mounted) _closeDialog(context);
    if (!context.mounted) return;
    await _showExportSheet(context, exportFilePath, loc);
  } catch (e) {
    if (context.mounted) {
      _closeDialog(context);
      SnackBarUtils.show(context, loc.exportFailed(e.toString()), tone: NyanSnackTone.error);
    }
  }
}

Future<void> _showExportSheet(
  BuildContext context,
  String exportFilePath,
  AppLocalizations loc,
) async {
  await showNyanOptionSheet<String>(
    context: context,
    title: loc.exportData,
    subtitle: loc.exportDataSheetSubtitle,
    isActionSheet: true,
    options: [
      NyanOptionItem(
        value: 'save',
        label: loc.saveToDevice,
        hint: loc.saveToDeviceSubtitle,
        icon: NyanIcons.download,
        action: () => unawaited(_saveToDevice(context, exportFilePath, loc)),
      ),
      NyanOptionItem(
        value: 'share',
        label: loc.shareVia,
        hint: loc.shareViaSubtitle,
        icon: NyanIcons.share,
        action: () => unawaited(_shareFile(exportFilePath)),
      ),
    ],
  );
}

Future<void> _saveToDevice(
  BuildContext context,
  String exportFilePath,
  AppLocalizations loc,
) async {
  final savedPath = await FilePicker.platform.saveFile(
    dialogTitle: loc.saveToDevice,
    fileName: 'nyan_read_export.json',
    bytes: await File(exportFilePath).readAsBytes(),
  );
  if (savedPath != null && context.mounted) {
    SnackBarUtils.show(context, loc.exportSaved, tone: NyanSnackTone.success);
  }
}

Future<void> _shareFile(String exportFilePath) async {
  final xFile = XFile(exportFilePath, mimeType: 'application/json');
  await SharePlus.instance.share(
    ShareParams(files: [xFile], subject: 'Nyan Read Export'),
  );
}

// ── Import flow ───────────────────────────────────────────────────────────────

Future<void> _handleImportData(BuildContext context, WidgetRef ref) async {
  final loc = AppLocalizations.of(context)!;
  _showLoadingDialog(
    context,
    title: loc.importData,
    description: loc.importDataSubtitle,
  );

  try {
    final backupService = ref.read(backupRecoveryServiceRpProvider);
    final restoredCount = await backupService.importGlobalUserData();
    if (context.mounted) _closeDialog(context);
    if (!context.mounted) return;
    if (restoredCount == -1) return;
    SnackBarUtils.show(
      context,
      loc.importSuccess(restoredCount),
      tone: NyanSnackTone.success,
    );
  } catch (e) {
    if (context.mounted) {
      _closeDialog(context);
      SnackBarUtils.show(
        context,
        loc.importFailed(e.toString()),
        tone: NyanSnackTone.error,
      );
    }
  }
}

// ── Main page ─────────────────────────────────────────────────────────────────

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
        readerPrefs,
      ]),
      builder: (context, _) {
        final loc = AppLocalizations.of(context)!;
        final bottomInset = MediaQuery.paddingOf(context).bottom;

        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SafeArea(
                bottom: false,
                child: NyanPageHeader(
                  title: loc.settingsTitle,
                  leading: NyanRecessedIconButton(
                    icon: NyanIcons.back,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => context.pop(),
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
                    // ── Appearance ────────────────────────────────────────
                    NyanSectionHeader(
                      title: loc.appearance,
                      withLeadingDot: true,
                    ),
                    NyanRowGroup(
                      children: [
                        NyanListRow(
                          leadingIcon: NyanIcons.palette,
                          title: loc.themePreset,
                          subtitle: _themeName(themeManager.currentPreset, loc),
                          showChevron: true,
                          onTap: () => _pickTheme(context, themeManager, loc),
                        ),
                        NyanListRow(
                          leadingIcon: NyanIcons.language,
                          title: loc.language,
                          subtitle:
                              languageManager.locale.languageCode == 'zh'
                                  ? '中文'
                                  : 'English',
                          showChevron: true,
                          onTap: () =>
                              _pickLanguage(context, languageManager, loc),
                        ),
                      ],
                    ),

                    // ── Reading ───────────────────────────────────────────
                    NyanSectionHeader(
                      title: loc.reading,
                      withLeadingDot: true,
                    ),
                    ListenableBuilder(
                      listenable:
                          Listenable.merge([readerPrefs, reminderService]),
                      builder: (context, _) {
                        return NyanRowGroup(
                          children: [
                            // Page Turn Mode — spec: first row in Reading section.
                            NyanListRow(
                              leadingIcon: NyanIcons.book,
                              title: loc.pageTurnMode,
                              subtitle: _pageTurnSubtitle(
                                readerPrefs.pageTurnMode,
                                loc,
                              ),
                              showChevron: true,
                              onTap: () => _pickPageTurnMode(
                                context,
                                readerPrefs,
                                loc,
                              ),
                            ),
                            NyanListRow(
                              leadingIcon: NyanIcons.bell,
                              title: loc.readingReminder,
                              subtitle: loc.readingReminderSubtitle,
                              trailing: NyanSwitch(
                                value: reminderService.isEnabled,
                                onChanged: reminderService.setEnabled,
                              ),
                            ),
                            if (reminderService.isEnabled)
                              NyanListRow(
                                title: loc.reminderInterval,
                                subtitle: _reminderIntervalLabel(
                                  reminderService.intervalMinutes,
                                  loc,
                                ),
                                // Spec: `padding: "12px 16px 12px 52px"` —
                                // 52pt left aligns the text after the icon-chip
                                // area (36pt chip + 12pt gap + 4pt nudge = 52).
                                contentPadding: const EdgeInsets.fromLTRB(
                                  52,
                                  NyanSpacing.space12,
                                  NyanSpacing.space16,
                                  NyanSpacing.space12,
                                ),
                                showChevron: true,
                                onTap: () => _pickReminderInterval(
                                  context,
                                  reminderService,
                                  loc,
                                ),
                              ),
                            StatefulBuilder(
                              builder: (context, setLocalState) {
                                final bookshelfPrefs =
                                    ref.read(bookshelfPreferencesRpProvider);
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
                    // ── Data Management ───────────────────────────────────
                    NyanSectionHeader(
                      title: loc.dataManagement,
                      withLeadingDot: true,
                    ),
                    NyanRowGroup(
                      children: [
                        NyanListRow(
                          leadingIcon: NyanIcons.exportData,
                          title: loc.exportData,
                          subtitle: loc.exportDataSubtitle,
                          showChevron: true,
                          onTap: () => _handleExportData(context, ref),
                        ),
                        NyanListRow(
                          leadingIcon: NyanIcons.cloudDownload,
                          title: loc.importData,
                          subtitle: loc.importDataSubtitle,
                          showChevron: true,
                          onTap: () => _handleImportData(context, ref),
                        ),
                      ],
                    ),

                    // ── Admin — only shown when the user is Pro ───────────
                    // Spec (bundle4.jsx): Admin section with subtitle only when isPro=true.
                    if (featureManager.isPro) ...[
                      NyanSectionHeader(
                        title: loc.admin,
                        withLeadingDot: true,
                      ),
                      NyanRowGroup(
                        children: [
                          NyanListRow(
                            leadingIcon: NyanIcons.adminPanel,
                            title: loc.adminPanel,
                            subtitle: loc.adminPanelSubtitle,
                            showChevron: true,
                            onTap: () => context.push('/admin'),
                          ),
                        ],
                      ),
                    ],

                    // ── About ─────────────────────────────────────────────
                    NyanSectionHeader(
                      title: loc.about,
                      withLeadingDot: true,
                    ),
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

  // ── Picker launchers ────────────────────────────────────────────────────────

  Future<void> _pickTheme(
    BuildContext context,
    dynamic themeManager,
    AppLocalizations loc,
  ) async {
    final preset = await showNyanOptionSheet<ThemePreset>(
      context: context,
      title: loc.themePreset,
      subtitle: loc.themePresetSubtitle,
      options: [
        NyanOptionItem(
          value: ThemePreset.creamLight,
          label: loc.themeCreamLight,
          hint: loc.themeCreamLightHint,
          swatch: NyanColors.creamBackground,
        ),
        NyanOptionItem(
          value: ThemePreset.sumiDark,
          label: loc.themeSumiDark,
          hint: loc.themeSumiDarkHint,
          swatch: NyanColors.inkNightBackground,
        ),
        NyanOptionItem(
          value: ThemePreset.matchSystem,
          label: loc.themeMatchSystem,
          hint: loc.themeMatchSystemHint,
          // Half-cream/half-dark diagonal gradient swatch.
          swatchGradient: matchSystemSwatchGradient,
        ),
      ],
      currentValue: themeManager.currentPreset,
    );
    if (preset != null) await themeManager.setPreset(preset);
  }

  Future<void> _pickLanguage(
    BuildContext context,
    dynamic languageManager,
    AppLocalizations loc,
  ) async {
    final locale = await showNyanOptionSheet<Locale>(
      context: context,
      title: loc.language,
      subtitle: loc.languageSubtitle,
      options: [
        // Spec: English first, then 中文.
        NyanOptionItem(
          value: const Locale('en'),
          label: 'English',
          hint: loc.languageEnglishHint,
        ),
        NyanOptionItem(
          value: const Locale('zh'),
          label: '中文',
          hint: loc.languageChineseHint,
        ),
      ],
      currentValue: languageManager.locale,
    );
    if (locale != null) await languageManager.setLocale(locale);
  }

  Future<void> _pickPageTurnMode(
    BuildContext context,
    ReaderPreferencesService readerPrefs,
    AppLocalizations loc,
  ) async {
    final mode = await showNyanOptionSheet<PageTurnMode>(
      context: context,
      title: loc.pageTurnMode,
      subtitle: loc.pageTurnModeSubtitle,
      options: [
        NyanOptionItem(
          value: PageTurnMode.tap,
          label: loc.pageTurnLeftRight,
          hint: loc.pageTurnLeftRightHint,
          icon: NyanIcons.pageTurnHorizontal,
        ),
        NyanOptionItem(
          value: PageTurnMode.swipe,
          label: loc.pageTurnUpDown,
          hint: loc.pageTurnUpDownHint,
          icon: NyanIcons.pageTurnVertical,
        ),
      ],
      currentValue: readerPrefs.pageTurnMode,
    );
    if (mode != null) await readerPrefs.setPageTurnMode(mode);
  }

  Future<void> _pickReminderInterval(
    BuildContext context,
    dynamic reminderService,
    AppLocalizations loc,
  ) async {
    final interval = await showNyanOptionSheet<int>(
      context: context,
      title: loc.reminderInterval,
      subtitle: loc.reminderIntervalSubtitle,
      options: _kReminderIntervals
          .map(
            (m) => NyanOptionItem(
              value: m,
              label: _reminderIntervalLabel(m, loc),
            ),
          )
          .toList(),
      currentValue: reminderService.intervalMinutes,
    );
    if (interval != null) reminderService.setIntervalMinutes(interval);
  }

  // ── Label helpers ───────────────────────────────────────────────────────────

  String _themeName(ThemePreset preset, AppLocalizations loc) {
    switch (preset) {
      case ThemePreset.creamLight:
        return loc.themeCreamLight;
      case ThemePreset.sumiDark:
        return loc.themeSumiDark;
      case ThemePreset.matchSystem:
        return loc.themeMatchSystem;
    }
  }

  String _pageTurnSubtitle(PageTurnMode mode, AppLocalizations loc) {
    switch (mode) {
      case PageTurnMode.tap:
        return loc.pageTurnLeftRight;
      case PageTurnMode.swipe:
        return loc.pageTurnUpDown;
      case PageTurnMode.disabled:
        return loc.pageTurnDisabled;
    }
  }

  String _reminderIntervalLabel(int minutes, AppLocalizations loc) {
    switch (minutes) {
      case 15:
        return loc.reminderEvery15min;
      case 30:
        return loc.reminderEvery30min;
      case 45:
        return loc.reminderEvery45min;
      case 60:
        return loc.reminderEveryHour;
      case 90:
        return loc.reminderEvery90min;
      default:
        return loc.reminderMinutes(minutes);
    }
  }
}

// ── About card ────────────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    // Spec (bundle4.jsx): surface bg, r-card-nested (16pt), divider@36% border,
    // 16pt padding, gap-14 row: 56×56 icon container + text column.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: nyan.surface,
        borderRadius: BorderRadius.circular(NyanRadius.cardNested),
        border: Border.all(
          color: nyan.divider.withValues(alpha: 0.36),
          width: 0.72,
        ),
        boxShadow: NyanShadows.settingsGrouped(nyan),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NyanSpacing.space16),
        child: Row(
          children: [
            // Spec: 56×56, r-card-nested bg, ph-book-open 26pt in primary.
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  nyan.primary.withValues(alpha: 0.12),
                  nyan.surfaceMuted,
                ),
                borderRadius: BorderRadius.circular(NyanRadius.cardNested),
              ),
              child: Icon(NyanIcons.book, size: 26, color: nyan.primary),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nyan Read',
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    // Spec: `font: "600 18px/1.2"` (bundle4.jsx About).
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
                    // Spec: `font: "400 13px/1.3"`.
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                    color: nyan.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
