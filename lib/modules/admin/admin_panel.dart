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
import '../../core/ui/components/nyan_switch.dart';

// Vertical padding inside each row — matches spec `padding: "12px 16px"`.
const double _kAdminHorizontalPadding = NyanSpacing.space16;
const double _kAdminRowVerticalPadding = NyanSpacing.space12;
// Hint card uses 14pt vertical — spec `padding: "14px 16px"`.
const double _kAdminHintVerticalPadding = 14.0;
// Gap between icon and text in hint card — spec `gap: 10`.
const double _kAdminHintIconGap = 10.0;

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
              // Top padding is 0 — section headers carry their own 16pt top gap.
              padding: EdgeInsets.fromLTRB(
                _kAdminHorizontalPadding,
                0,
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
                    const _AdminDivider(),
                    _AdminSwitchRow(
                      title: loc.adminForceProNudge,
                      subtitle: loc.adminForceProNudgeSubtitle,
                      value: fm.forceProNudge,
                      onChanged: fm.setForceProNudge,
                    ),
                  ],
                ),
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
                const SizedBox(height: NyanSpacing.space12),
                _AdminSettingsCard(
                  backgroundColor: Color.alphaBlend(
                    nyan.primary.withValues(alpha: 0.05),
                    nyan.surface,
                  ),
                  borderColor: nyan.primaryDeep.withValues(alpha: 0.22),
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
    final nyan = resolveNyanTheme(Theme.of(context));
    return Padding(
      // 16pt top provides the between-section gap; 8pt bottom before the card.
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: nyan.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: NyanTypography.eyebrowStyle(nyan.primaryDeep),
          ),
        ],
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
        borderRadius: BorderRadius.circular(NyanRadius.cardNested),
        border: Border.all(
          color: borderColor ??
              nyan.divider.withValues(
                  alpha: nyan.brightness == Brightness.dark ? 0.4 : 0.7),
          width: 0.72,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NyanRadius.cardNested),
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
      thickness: 0.5,
      indent: _kAdminHorizontalPadding,
      endIndent: _kAdminHorizontalPadding,
      color: nyan.divider.withValues(alpha: 0.34),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kAdminHorizontalPadding,
        _kAdminRowVerticalPadding,
        _kAdminHorizontalPadding,
        _kAdminRowVerticalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: NyanTypography.adminRowLabel,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
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
          NyanSwitch(value: value, onChanged: onChanged),
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
    final accent = value ? nyan.primaryDeep : nyan.textSecondary;

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
              style: TextStyle(
                fontFamily: NyanTypography.uiFontFamily,
                fontSize: NyanTypography.adminRowLabel,
                fontWeight: FontWeight.w500,
                height: 1.2,
                color: nyan.textPrimary,
              ),
            ),
          ),
          // Badge: fixed 28pt height, r-chip (12pt), surfaceMuted base.
          // On: accent 10% + border 30%. Off: accent 8% + border 22%.
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(
              horizontal: NyanSpacing.space12,
            ),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                accent.withValues(alpha: value ? 0.10 : 0.08),
                nyan.surfaceMuted,
              ),
              borderRadius: BorderRadius.circular(NyanRadius.chip),
              border: Border.all(
                color: accent.withValues(alpha: value ? 0.30 : 0.22),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              value ? loc.adminStateOn : loc.adminStateOff,
              style: TextStyle(
                fontFamily: NyanTypography.uiFontFamily,
                fontSize: NyanTypography.adminBadgeLabel,
                fontWeight: FontWeight.w500,
                height: 1.0,
                color: accent,
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
    final nyan = resolveNyanTheme(Theme.of(context));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kAdminHorizontalPadding,
        _kAdminHintVerticalPadding,
        _kAdminHorizontalPadding,
        _kAdminHintVerticalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            NyanIcons.info,
            size: 18,
            color: nyan.primaryDeep,
          ),
          const SizedBox(width: _kAdminHintIconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: NyanTypography.adminHintTitle,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: nyan.textPrimary.withValues(alpha: 0.96),
                  ),
                ),
                const SizedBox(height: NyanSpacing.space4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: NyanTypography.meta,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
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
