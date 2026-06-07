import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../../core/theme/nyan_radius.dart';
import '../../../core/theme/nyan_spacing.dart';
import '../../../core/theme/nyan_typography.dart';
import '../../../core/theme/theme_presets.dart';
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
    this.showSheetChrome = true,
    this.showHeader = true,
    this.bottomInsetOverride,
  });

  final ReaderController controller;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final BrightnessController brightnessController;
  final ScrollController? scrollController;
  final bool showSheetChrome;
  final bool showHeader;
  final double? bottomInsetOverride;

  @override
  State<ReaderMenu> createState() => _ReaderMenuState();
}

class _ReaderMenuState extends State<ReaderMenu> {
  _ReaderMenuSection _selectedSection = _ReaderMenuSection.display;

  String _resetLabelForSection(
    AppLocalizations loc,
    _ReaderMenuSection section,
  ) {
    final sectionLabel = switch (section) {
      _ReaderMenuSection.display => loc.readerMenuDisplay,
      _ReaderMenuSection.text => loc.readerMenuText,
      _ReaderMenuSection.theme => loc.readerMenuTheme,
    };
    // Uses the l10n template so both EN ("Reset Display") and ZH ("重置显示")
    // are produced from the ARB without locale sniffing in widget code.
    return loc.readerResetSection(sectionLabel);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final capabilities = controller.capabilities;
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final nyan = resolveNyanTheme(theme);
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
                const headerBottomGap = NyanSpacing.space12;
                // Embedded: one small tail gap only (matches quick body + shell);
                // system inset is from the parent SafeArea, not double-stacked here.
                // When embedded in OnePaperDock (showSheetChrome=false) the dock
                // already provides 14pt horizontal padding — add none here to
                // avoid double-padding (F1 width fix, §4.6 delivery-package spec).
                final hPad = widget.showSheetChrome ? NyanSpacing.space20 : 0.0;
                final contentPadding = EdgeInsets.fromLTRB(
                  hPad,
                  widget.showHeader
                      ? (compactLayout
                          ? NyanSpacing.space12
                          : NyanSpacing.space16)
                      : 0,
                  hPad,
                  !widget.showHeader
                      ? 0.0
                      : (NyanSpacing.space8 +
                          (widget.bottomInsetOverride ??
                              MediaQuery.of(context).padding.bottom)),
                );
                final resetSection = _ReaderSettingsResetSection(
                  label: _resetLabelForSection(
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
                      if (widget.showHeader) ...[
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              // Spec --grabber: primary @ 36% light / 50% dark.
                              color: nyan.primary.withValues(
                                alpha: nyan.brightness == Brightness.dark
                                    ? 0.5
                                    : 0.36,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        _ReaderMenuHeader(
                          title: loc.readingSettings,
                          progressListenable:
                              controller.progressListenable,
                        ),
                        SizedBox(height: headerBottomGap),
                      ],
                      if (sections.length > 1) ...[
                        // Spec ReaderSettingsBody: style="subtle" (matcha-tint
                        // indicator chip, primaryDeep selected label).
                        SegmentedTabControl(
                          style: SegmentedTabStyle.subtle,
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
          pageTurnMode:
              controller.settingsManager.preferences.pageTurnMode,
          onSetPageTurnMode: controller.setPageTurnMode,
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
          useSerif:
              controller.settingsManager.preferences.useSerif,
          onSetUseSerif: controller.setUseSerif,
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

/// Sheet header per Claude Design spec (`ReaderSettingsSheet.jsx`): title on
/// the left, "Reading progress {N}%" meta on the right. The old Quick / Full
/// layer toggle was removed in P4 once the bottom-overlay layer system went
/// away — there is no longer a parallel "quick" panel to bounce back to.
class _ReaderMenuHeader extends StatelessWidget {
  const _ReaderMenuHeader({
    required this.title,
    required this.progressListenable,
  });

  final String title;
  final ValueListenable<double> progressListenable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyan = resolveNyanTheme(theme);
    final loc = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: NyanSpacing.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: NyanTypography.uiFontFamily,
                // Spec: 600 / 20px / -0.2 letter-spacing (OnePaperDock title).
                fontSize: NyanTypography.section,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                height: 1.2,
                color: nyan.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: NyanSpacing.space8),
          ValueListenableBuilder<double>(
            valueListenable: progressListenable,
            builder: (context, progress, _) {
              final pct = (progress.clamp(0.0, 1.0) * 100).round();
              return Text(
                loc.readerSettingsProgressHint(pct),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  fontSize: NyanTypography.meta,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                  color: nyan.textSecondary,
                ),
              );
            },
          ),
        ],
      ),
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
                  NyanIcons.refresh,
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

