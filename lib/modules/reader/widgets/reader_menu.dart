import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nyan_read/l10n/app_localizations.dart';

import '../../../core/theme/nyan_radius.dart';
import '../../../core/theme/nyan_spacing.dart';
import '../../../core/ui/components/nyan_confirm_dialog.dart';
import '../../../core/ui/components/nyan_overlay_style.dart';
import '../../bookshelf/widgets/segmented_tab_control.dart';
import '../controllers/brightness_controller.dart';
import '../reader_engine/reader_engine.dart';
import '../reader_page.dart';
import 'reader_settings/reader_settings_display_panel.dart';
import 'reader_settings/reader_settings_text_panel.dart';
import 'reader_settings/reader_settings_theme_panel.dart';

enum _ReaderMenuSection { display, text, theme }

class ReaderMenu extends StatefulWidget {
  const ReaderMenu({
    super.key,
    required this.controller,
    required this.scaffoldKey,
    required this.brightnessController,
    this.scrollController,
    this.onBackToQuickPanel,
    this.showSheetChrome = true,
    this.showHeader = true,
    this.bottomInsetOverride,
  });

  final ReaderController controller;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final BrightnessController brightnessController;
  final ScrollController? scrollController;

  /// When set (e.g. L2 opened on top of L1), shows a back control that pops
  /// this sheet and returns to the quick panel.
  final VoidCallback? onBackToQuickPanel;
  final bool showSheetChrome;
  final bool showHeader;
  final double? bottomInsetOverride;

  @override
  State<ReaderMenu> createState() => _ReaderMenuState();
}

class _ReaderMenuState extends State<ReaderMenu> {
  _ReaderMenuSection _selectedSection = _ReaderMenuSection.display;

  String _resetLabelForSection(
    BuildContext context,
    AppLocalizations loc,
    _ReaderMenuSection section,
  ) {
    final sectionLabel = switch (section) {
      _ReaderMenuSection.display => loc.readerMenuDisplay,
      _ReaderMenuSection.text => loc.readerMenuText,
      _ReaderMenuSection.theme => loc.readerMenuTheme,
    };
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    return isChinese ? '重置$sectionLabel' : 'Reset $sectionLabel';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final capabilities = controller.capabilities;
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sections = _buildSections(capabilities);
    if (!sections.contains(_selectedSection)) {
      _selectedSection = sections.first;
    }

    Widget body = LayoutBuilder(
      builder: (context, constraints) {
                final compactLayout = constraints.maxHeight < 620;
                final allowScrollFallback = constraints.maxHeight < 540 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.12;
                final sectionGap =
                    compactLayout ? NyanSpacing.space8 : NyanSpacing.space12;
                final headerBottomGap =
                    compactLayout ? NyanSpacing.space8 : NyanSpacing.space12;
                // Embedded: one small tail gap only (matches quick body + shell);
                // system inset is from the parent SafeArea, not double-stacked here.
                final contentPadding = EdgeInsets.fromLTRB(
                  NyanSpacing.space20,
                  widget.showHeader
                      ? (compactLayout
                          ? NyanSpacing.space12
                          : NyanSpacing.space16)
                      : 0,
                  NyanSpacing.space20,
                  !widget.showHeader
                      ? 0.0
                      : (NyanSpacing.space8 +
                          (widget.bottomInsetOverride ??
                              MediaQuery.of(context).padding.bottom)),
                );
                final resetSection = _ReaderSettingsResetSection(
                  label: _resetLabelForSection(
                    context,
                    loc,
                    _selectedSection,
                  ),
                  onResetCurrentTab: () async {
                    HapticFeedback.lightImpact();
                    switch (_selectedSection) {
                      case _ReaderMenuSection.display:
                        await controller.resetReaderDisplayDefaults();
                        break;
                      case _ReaderMenuSection.text:
                        controller.resetReaderTextDefaults();
                        break;
                      case _ReaderMenuSection.theme:
                        controller.resetReaderThemeDefaults();
                        break;
                    }
                  },
                );
                Future<void> resetAllAction() async {
                  HapticFeedback.lightImpact();
                  await controller.resetReaderAppearanceDefaults();
                }
                final actionsRow = _ReaderSettingsActionsRow(
                  resetCurrentTabLabel: _resetLabelForSection(
                    context,
                    loc,
                    _selectedSection,
                  ),
                  resetAllLabel: loc.readerResetAll,
                  onResetCurrentTab: resetSection.onResetCurrentTab,
                  onResetAll: resetAllAction,
                );

                Widget buildHeaderAndPanel() {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.showHeader) ...[
                        Center(
                          child: Container(
                            width: 40,
                            height: NyanSpacing.space4,
                            decoration: BoxDecoration(
                              color: theme.dividerColor.withValues(alpha: 0.44),
                              borderRadius:
                                  BorderRadius.circular(NyanRadius.small),
                            ),
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        _ReaderMenuHeader(
                          title: loc.readingSettings,
                          quickModeTooltip: loc.readerMenuBackToQuick,
                          fullModeTooltip: loc.readingSettings,
                          onOpenQuickMode: widget.onBackToQuickPanel,
                          onBackToQuickPanel: widget.onBackToQuickPanel,
                        ),
                        SizedBox(height: headerBottomGap),
                      ],
                      if (sections.length > 1) ...[
                        SegmentedTabControl(
                          tabs: [
                            for (final section in sections)
                              SegmentedTab(
                                label: _sectionLabel(loc, section),
                              ),
                          ],
                          selectedIndex: sections.indexOf(_selectedSection),
                          onTabChanged: (index) {
                            setState(() {
                              _selectedSection = sections[index];
                            });
                          },
                          backgroundColor:
                              NyanOverlayStyle.recessedSurface(context),
                          labelLineHeight: 1.15,
                        ),
                        SizedBox(height: sectionGap),
                      ],
                      ClipRect(
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeInOutCubic,
                          alignment: Alignment.topCenter,
                          child: ListenableBuilder(
                            listenable: controller,
                            builder: (context, _) => _buildSelectedPanel(
                              context,
                              controller,
                              capabilities,
                              loc,
                              denseLayout: compactLayout,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                if (allowScrollFallback) {
                  return SingleChildScrollView(
                    controller: widget.scrollController,
                    padding: contentPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        buildHeaderAndPanel(),
                        const SizedBox(height: NyanSpacing.space8),
                        actionsRow,
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: contentPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buildHeaderAndPanel(),
                      const SizedBox(height: NyanSpacing.space8),
                      actionsRow,
                    ],
                  ),
                );
      },
    );

    if (!widget.showSheetChrome) {
      return body;
    }

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Container(
            decoration: BoxDecoration(
              color: theme.bottomSheetTheme.backgroundColor ?? theme.cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(NyanRadius.sheet),
              ),
              boxShadow: NyanOverlayStyle.dialogShadow(context),
            ),
            child: body,
          ),
        ),
      ),
    );
  }

  List<_ReaderMenuSection> _buildSections(ReaderCapabilities capabilities) {
    final sections = <_ReaderMenuSection>[_ReaderMenuSection.display];
    if (capabilities.supportsTypography) {
      sections.add(_ReaderMenuSection.text);
    }
    if (capabilities.supportsTheme) {
      sections.add(_ReaderMenuSection.theme);
    }
    return sections;
  }

  String _sectionLabel(AppLocalizations loc, _ReaderMenuSection section) {
    return switch (section) {
      _ReaderMenuSection.display => loc.readerMenuDisplay,
      _ReaderMenuSection.text => loc.readerMenuText,
      _ReaderMenuSection.theme => loc.readerMenuTheme,
    };
  }

  Widget _buildSelectedPanel(BuildContext context, ReaderController controller,
      ReaderCapabilities capabilities, AppLocalizations loc,
      {required bool denseLayout}) {
    switch (_selectedSection) {
      case _ReaderMenuSection.display:
        return ReaderSettingsDisplayPanel(
          brightnessController: widget.brightnessController,
          loc: loc,
          onWarmthChanged: controller.setWarmth,
          denseLayout: denseLayout,
        );
      case _ReaderMenuSection.text:
        return ReaderSettingsTextPanel(
          fontSize: controller.fontSize,
          lineHeight: controller.lineHeight,
          textColor: controller.textColor,
          backgroundColor: controller.backgroundColor,
          onSetFontSize: controller.setFontSize,
          onSetLineHeight: controller.setLineHeight,
          loc: loc,
          denseLayout: denseLayout,
        );
      case _ReaderMenuSection.theme:
        return ReaderSettingsThemePanel(
          currentBackground: controller.backgroundColor,
          onSelectBackground: controller.setBackground,
          loc: loc,
        );
    }
  }
}

Future<void> _confirmResetAllFromHeader(
  BuildContext context,
  AppLocalizations loc,
  Future<void> Function() onResetAll,
) async {
  final confirmed = await showNyanConfirmDialog(
    context,
    title: loc.readerResetAllConfirmTitle,
    description: loc.readerResetAllConfirmMessage,
    confirmLabel: loc.readerResetAllConfirmAction,
    cancelLabel: loc.cancel,
    tone: NyanConfirmTone.warning,
    icon: Icons.restart_alt_rounded,
  );
  if (confirmed == true && context.mounted) {
    await onResetAll();
  }
}

class _ReaderMenuHeader extends StatelessWidget {
  const _ReaderMenuHeader({
    required this.title,
    required this.quickModeTooltip,
    required this.fullModeTooltip,
    required this.onOpenQuickMode,
    this.onBackToQuickPanel,
  });

  final String title;
  final String quickModeTooltip;
  final String fullModeTooltip;
  final VoidCallback? onOpenQuickMode;
  final VoidCallback? onBackToQuickPanel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 16,
      letterSpacing: -0.08,
      height: 1.2,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.92),
    );

    return SizedBox(
      height: NyanSpacing.minTapTarget,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: NyanSpacing.space4 / 2),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
            ),
          ),
          const SizedBox(width: NyanSpacing.space8),
          Container(
            decoration: BoxDecoration(
              color: NyanOverlayStyle.recessedSurface(context, strength: 0.02),
              borderRadius: BorderRadius.circular(NyanRadius.input),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.16),
                width: 0.8,
              ),
            ),
            child: ReaderLayerModeToggle(
              quickSelected: onBackToQuickPanel == null,
              quickTooltip: quickModeTooltip,
              fullTooltip: fullModeTooltip,
              onTapQuick: onOpenQuickMode == null
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onOpenQuickMode!();
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class ReaderLayerModeToggle extends StatelessWidget {
  const ReaderLayerModeToggle({
    super.key,
    required this.quickSelected,
    required this.quickTooltip,
    required this.fullTooltip,
    this.onTapQuick,
    this.onTapFull,
  });

  final bool quickSelected;
  final String? quickTooltip;
  final String? fullTooltip;
  final VoidCallback? onTapQuick;
  final VoidCallback? onTapFull;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ReaderLayerModeToggleCell(
          icon: Icons.dashboard_customize_rounded,
          selected: quickSelected,
          tooltip: quickTooltip,
          onTap: onTapQuick,
        ),
        ReaderLayerModeToggleCell(
          icon: Icons.tune_rounded,
          selected: !quickSelected,
          tooltip: fullTooltip,
          onTap: onTapFull,
        ),
      ],
    );
  }
}

class ReaderLayerModeToggleCell extends StatelessWidget {
  const ReaderLayerModeToggleCell({
    super.key,
    required this.icon,
    required this.selected,
    required this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final bool selected;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NyanRadius.input),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: NyanSpacing.minTapTarget,
        height: NyanSpacing.minTapTarget,
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(NyanRadius.input),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected
              ? theme.colorScheme.primary
              : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
        ),
      ),
    );
    if (tooltip == null || tooltip!.isEmpty) {
      return button;
    }
    return Tooltip(message: tooltip!, child: button);
  }
}

class _ReaderSettingsResetSection extends StatelessWidget {
  const _ReaderSettingsResetSection({
    required this.label,
    required this.onResetCurrentTab,
  });

  final String label;
  final Future<void> Function() onResetCurrentTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = TextButton.styleFrom(
      foregroundColor: theme.colorScheme.primary,
      padding: const EdgeInsets.symmetric(
        horizontal: NyanSpacing.space8,
        vertical: NyanSpacing.space8,
      ),
      minimumSize: const Size(0, NyanSpacing.minTapTarget),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textMaxWidth = (constraints.maxWidth - 56).clamp(0.0, 520.0);
        return Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: () async => onResetCurrentTab(),
            style: baseStyle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: theme.colorScheme.primary.withValues(alpha: 0.88),
                ),
                const SizedBox(width: NyanSpacing.space8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: textMaxWidth),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReaderSettingsActionsRow extends StatelessWidget {
  const _ReaderSettingsActionsRow({
    required this.resetCurrentTabLabel,
    required this.resetAllLabel,
    required this.onResetCurrentTab,
    required this.onResetAll,
  });

  final String resetCurrentTabLabel;
  final String resetAllLabel;
  final Future<void> Function() onResetCurrentTab;
  final Future<void> Function() onResetAll;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: _ReaderSettingsResetSection(
            label: resetCurrentTabLabel,
            onResetCurrentTab: onResetCurrentTab,
          ),
        ),
        const SizedBox(width: NyanSpacing.space4),
        Flexible(
          child: Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () async => _confirmResetAllFromHeader(
                context,
                loc,
                onResetAll,
              ),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: NyanSpacing.space8,
                  vertical: NyanSpacing.space8,
                ),
                minimumSize: const Size(0, NyanSpacing.minTapTarget),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restart_alt_rounded,
                    size: 18,
                    color: theme.colorScheme.primary.withValues(alpha: 0.88),
                  ),
                  const SizedBox(width: NyanSpacing.space8),
                  Flexible(
                    child: Text(
                      resetAllLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
