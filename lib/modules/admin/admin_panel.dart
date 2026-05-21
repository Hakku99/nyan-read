import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../core/services/feature_manager.dart';
import '../../core/services/riverpod_providers.dart';
import '../../core/theme/nyan_radius.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/theme/nyan_typography.dart';
import '../../core/theme/theme_presets.dart';

const double _kAdminHorizontalPadding = NyanSpacing.space16;
const double _kAdminSectionGap = NyanSpacing.space24;
const double _kAdminCardGap = NyanSpacing.space12;
const double _kAdminRowVerticalPadding = NyanSpacing.space12;

class AdminPanel extends ConsumerWidget {
  const AdminPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fm = ref.read(featureManagerRpProvider);

    return ListenableBuilder(
      listenable: fm,
      builder: (context, _) {
        final theme = Theme.of(context);
        final nyan = resolveNyanTheme(theme);
        final loc = AppLocalizations.of(context)!;

        return Scaffold(
          appBar: AppBar(
            leadingWidth: NyanSpacing.minTapTarget + NyanSpacing.space12,
            titleSpacing: NyanSpacing.space4,
            centerTitle: false,
            title: Text(
              loc.adminPanelTitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                _kAdminHorizontalPadding,
                _kAdminHorizontalPadding,
                _kAdminHorizontalPadding,
                _kAdminHorizontalPadding +
                    MediaQuery.of(context).padding.bottom,
              ),
              children: [
                _AdminSectionHeader(title: loc.adminPanelModeSection),
                _AdminSettingsCard(
                  children: [
                    _AdminSwitchRow(
                      title: loc.adminProModeEnabled,
                      subtitle: loc.adminProModeSubtitle,
                      value: fm.currentMode == AppMode.pro,
                      onChanged: (value) {
                        fm.toggleMode(value ? AppMode.pro : AppMode.free);
                      },
                    ),
                    if (fm.isPro) ...[
                      const _AdminDivider(),
                      _AdminSwitchRow(
                        title: loc.adminForceUnlockPrivacyShelf,
                        subtitle: loc.adminForceUnlockPrivacyShelfSubtitle,
                        value: fm.isPrivateShelfUnlocked,
                        onChanged: (value) {
                          if (value) {
                            fm.unlockPrivateShelf();
                          } else {
                            fm.lockPrivateShelf();
                          }
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: _kAdminSectionGap),
                _AdminSectionHeader(title: loc.adminFeatureFlagsSection),
                _AdminSettingsCard(
                  children: [
                    _AdminFlagRow(
                      title: loc.ads,
                      value: fm.adsEnabled,
                      nyan: nyan,
                      loc: loc,
                    ),
                    const _AdminDivider(),
                    _AdminFlagRow(
                      title: loc.privacy,
                      value: fm.privacyShelfEnabled,
                      nyan: nyan,
                      loc: loc,
                    ),
                    const _AdminDivider(),
                    _AdminFlagRow(
                      title: loc.tts,
                      value: fm.ttsEnabled,
                      nyan: nyan,
                      loc: loc,
                    ),
                  ],
                ),
                const SizedBox(height: _kAdminCardGap),
                _AdminSettingsCard(
                  backgroundColor: Color.alphaBlend(
                    nyan.primary.withValues(
                        alpha:
                            nyan.brightness == Brightness.dark ? 0.12 : 0.05),
                    nyan.surface,
                  ),
                  borderColor: nyan.primaryDeep.withValues(
                      alpha: nyan.brightness == Brightness.dark ? 0.42 : 0.2),
                  children: [
                    _AdminHintRow(
                      title: loc.adminPanelHintTitle,
                      subtitle: loc.adminPanelHintSubtitle,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminSectionHeader extends StatelessWidget {
  const _AdminSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyan = resolveNyanTheme(theme);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kAdminHorizontalPadding,
        0,
        _kAdminHorizontalPadding,
        _kAdminCardGap,
      ),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: NyanTypography.meta,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          color: nyan.primaryDeep.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _AdminSettingsCard extends StatelessWidget {
  const _AdminSettingsCard({
    required this.children,
    this.backgroundColor,
    this.borderColor,
  });

  final List<Widget> children;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final nyan = resolveNyanTheme(Theme.of(context));
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? nyan.surface,
        borderRadius: BorderRadius.circular(NyanRadius.input),
        border: Border.all(
          color: borderColor ??
              nyan.divider.withValues(
                  alpha: nyan.brightness == Brightness.dark ? 0.4 : 0.7),
          width: 0.72,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NyanRadius.input),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _AdminDivider extends StatelessWidget {
  const _AdminDivider();

  @override
  Widget build(BuildContext context) {
    final nyan = resolveNyanTheme(Theme.of(context));
    return Divider(
      height: 1,
      thickness: 0.6,
      color: nyan.divider
          .withValues(alpha: nyan.brightness == Brightness.dark ? 0.52 : 0.7),
    );
  }
}

class _AdminSwitchRow extends StatelessWidget {
  const _AdminSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyan = resolveNyanTheme(theme);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kAdminHorizontalPadding,
        _kAdminRowVerticalPadding,
        _kAdminHorizontalPadding,
        _kAdminRowVerticalPadding,
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
                    color: nyan.textPrimary,
                  ),
                ),
                const SizedBox(height: NyanSpacing.space4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.3,
                    color: nyan.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: NyanSpacing.space12),
          Theme(
            data: theme.copyWith(
              switchTheme: SwitchThemeData(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                    return theme.colorScheme.surface.withValues(alpha: 0);
                  }
                  return theme.dividerColor.withValues(
                    alpha: isDark ? 0.14 : 0.18,
                  );
                }),
                overlayColor: WidgetStateProperty.all(
                  theme.colorScheme.surface.withValues(alpha: 0),
                ),
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

class _AdminFlagRow extends StatelessWidget {
  const _AdminFlagRow({
    required this.title,
    required this.value,
    required this.nyan,
    required this.loc,
  });

  final String title;
  final bool value;
  final NyanTheme nyan;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = value ? nyan.primaryDeep : nyan.textSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kAdminHorizontalPadding,
        _kAdminRowVerticalPadding,
        _kAdminHorizontalPadding,
        _kAdminRowVerticalPadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: nyan.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: NyanSpacing.space12,
              vertical: NyanSpacing.space4,
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(
                  alpha: nyan.brightness == Brightness.dark ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(NyanRadius.small),
              border: Border.all(
                color: statusColor.withValues(
                    alpha: nyan.brightness == Brightness.dark ? 0.45 : 0.3),
              ),
            ),
            child: Text(
              value ? loc.adminStateOn : loc.adminStateOff,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminHintRow extends StatelessWidget {
  const _AdminHintRow({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyan = resolveNyanTheme(theme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kAdminHorizontalPadding,
        _kAdminRowVerticalPadding,
        _kAdminHorizontalPadding,
        _kAdminRowVerticalPadding,
      ),
      child: Row(
        children: [
          Icon(
            NyanIcons.info,
            size: 18,
            color: nyan.primaryDeep,
          ),
          const SizedBox(width: NyanSpacing.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: nyan.textPrimary.withValues(alpha: 0.96),
                  ),
                ),
                const SizedBox(height: NyanSpacing.space4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.3,
                    color: nyan.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
