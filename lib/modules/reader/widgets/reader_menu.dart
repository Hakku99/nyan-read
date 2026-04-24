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
  });

  final ReaderController controller;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final BrightnessController brightnessController;
  final ScrollController? scrollController;

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactLayout = constraints.maxHeight < 620;
                final allowScrollFallback =
                    constraints.maxHeight < 540 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.12;
                final sectionGap =
                    compactLayout ? NyanSpacing.space8 : NyanSpacing.space12;
                final contentPadding = EdgeInsets.fromLTRB(
                  NyanSpacing.space20,
                  compactLayout ? NyanSpacing.space12 : NyanSpacing.space16,
                  NyanSpacing.space20,
                  NyanSpacing.space8 + MediaQuery.of(context).padding.bottom,
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

                Widget buildHeaderAndPanel() {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                        resetAllLabel: loc.readerResetAll,
                        onResetAll: () async {
                          HapticFeedback.lightImpact();
                          await controller.resetReaderAppearanceDefaults();
                        },
                      ),
                      if (sections.length > 1) ...[
                        SizedBox(height: sectionGap),
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
                      ],
                      SizedBox(height: sectionGap),
                      _buildSelectedPanel(
                        context,
                        controller,
                        capabilities,
                        loc,
                        denseLayout: compactLayout,
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
                        resetSection,
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
                      resetSection,
                    ],
                  ),
                );
              },
            ),
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

  Widget _buildSelectedPanel(
    BuildContext context,
    ReaderController controller,
    ReaderCapabilities capabilities,
    AppLocalizations loc,
    {required bool denseLayout}
  ) {
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
    required this.resetAllLabel,
    required this.onResetAll,
  });

  final String title;
  final String resetAllLabel;
  final Future<void> Function() onResetAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 16,
      letterSpacing: -0.08,
      height: 1.2,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.92),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
        ),
        const SizedBox(width: NyanSpacing.space8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _confirmResetAllFromHeader(
              context,
              AppLocalizations.of(context)!,
              onResetAll,
            ),
            icon: Icon(
              Icons.restart_alt_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            label: Text(
              resetAllLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: NyanSpacing.space8,
                vertical: NyanSpacing.space4,
              ),
              minimumSize: const Size(0, NyanSpacing.minTapTarget),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
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
                  size: 20,
                  color: theme.colorScheme.primary.withValues(alpha: 0.88),
                ),
                const SizedBox(width: NyanSpacing.space8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: textMaxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ],
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
