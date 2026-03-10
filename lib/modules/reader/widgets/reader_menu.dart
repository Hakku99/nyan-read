import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import '../reader_page.dart';
import '../../bookmark/bookmark_list_page.dart';
import '../../notes/notes_list_page.dart';
import '../../settings/settings_page.dart';
import '../widgets/highlight_note_dialog.dart';
import '../../../../core/models/highlight.dart';
import '../../../../core/theme/theme_presets.dart';
import '../../../../core/theme/theme_manager.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../controllers/brightness_controller.dart';

class ReaderMenu extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  /// Inject the BrightnessController directly so the brightness slider
  /// follows the shared reader brightness state in real time.
  final BrightnessController brightnessController;

  const ReaderMenu({
    Key? key,
    required this.scaffoldKey,
    required this.brightnessController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReaderController>();
    final themeManager = context.watch<ThemeManager>();
    // Use the global app theme for the menu, decoupled from the reader's background color
    final activeTheme = Theme.of(context);
    final nyanTheme = themePresets[themeManager.currentPreset]!;

    return SafeArea(
      bottom: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Container(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 24.0,
            bottom: 24.0 + MediaQuery.of(context).padding.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Progress Slider
                _buildProgressSection(context, controller, activeTheme),

                const SizedBox(height: 24),

                // 2. Brightness Slider
                _buildBrightnessSection(context, nyanTheme),

                const SizedBox(height: 24),
                Divider(
                    height: 1,
                    color: activeTheme.dividerColor.withOpacity(0.5)),
                const SizedBox(height: 24),

                // 3. Settings Row (Font, Line Height)
                _buildTypographySection(context, controller, nyanTheme),

                const SizedBox(height: 24),
                Divider(
                    height: 1,
                    color: activeTheme.dividerColor.withOpacity(0.5)),
                const SizedBox(height: 24),

                // 4. Themes (Background Colors)
                _buildThemeSection(context, controller, nyanTheme),

                const SizedBox(height: 24),
                Divider(
                    height: 1,
                    color: activeTheme.dividerColor.withOpacity(0.5)),
                const SizedBox(height: 20),

                // 5. Bottom Navigation Actions
                _buildBottomActions(context, controller, nyanTheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(
      BuildContext context, ReaderController controller, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildNavButton(
          icon: Icons.chevron_left_rounded,
          onTap: () => controller.jumpToPreviousChapter(),
          theme: theme,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SliderWithFloatingLabel(
            value: controller.currentProgress,
            min: 0.0,
            max: 1.0,
            divisions: 1000,
            onChanged: (val) => controller.seekTo(val),
            activeColor: theme.colorScheme.primary,
            inactiveColor: theme.dividerColor.withOpacity(0.3),
          ),
        ),
        const SizedBox(width: 12),
        _buildNavButton(
          icon: Icons.chevron_right_rounded,
          onTap: () => controller.jumpToNextChapter(),
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 24,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildBrightnessSection(
      BuildContext context, NyanTheme theme) {
    return Column(
      children: [
        // 1. Brightness Slider
        // Listen to BrightnessController.uiBrightnessValue directly so the
        // slider always reflects the live reader brightness state.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.preset == ThemePreset.creamLight
                    ? NyanTheme.creamRecess
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.wb_sunny_rounded,
                  size: 22, color: theme.textSecondary.withOpacity(0.6)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<double>(
                valueListenable: brightnessController.uiBrightnessValue,
                builder: (context, brightnessVal, _) {
                  return SliderWithFloatingLabel(
                    value: brightnessVal.clamp(0.0, 1.0),
                    min: 0.0,
                    max: 1.0,
                    onChanged: (val) => brightnessController.setFromSlider(val),
                    onChangeEnd: (val) {
                      brightnessController.commitFromSlider(val);
                    },
                    activeColor: theme.textSecondary.withOpacity(0.8),
                    inactiveColor: theme.divider.withOpacity(0.5),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            ListenableBuilder(
              listenable: brightnessController,
              builder: (context, _) {
                return Tooltip(
                  message: brightnessController.followSystem
                      ? "Stop Following System"
                      : "Follow System Brightness",
                  child: InkWell(
                    onTap: () => brightnessController.toggleFollowSystem(),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        brightnessController.followSystem
                            ? Icons.brightness_auto
                            : Icons.brightness_auto_outlined,
                        size: 24,
                        color: brightnessController.followSystem
                            ? theme.primary
                            : Colors.grey.withOpacity(0.5),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 24),

        // 2. Warmth Slider
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.preset == ThemePreset.creamLight
                    ? NyanTheme.creamRecess
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.thermostat_rounded,
                  size: 22, color: const Color(0xFFFFCCBC)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<double>(
                valueListenable: brightnessController.warmthListenable,
                builder: (context, warmth, _) {
                  return SliderWithFloatingLabel(
                    value: warmth,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (val) => brightnessController.setWarmth(val),
                    activeColor: const Color(0xFFFFCCBC),
                    thumbColor: const Color(0xFFFFAB91),
                    inactiveColor: const Color(0xFFFFE0B2).withOpacity(0.3),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            const SizedBox(width: 36),
          ],
        ),
      ],
    );
  }

  Widget _buildTypographySection(
      BuildContext context, ReaderController controller, NyanTheme theme) {
    final loc = AppLocalizations.of(context)!;
    // Flat layout, no wrapping Container, same visual layer as sliders above.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _buildStepper(
            context,
            label: loc.fontSize,
            value: controller.fontSize.toStringAsFixed(0),
            onRemove: () => controller.setFontSize(controller.fontSize - 1),
            onAdd: () => controller.setFontSize(controller.fontSize + 1),
            theme: theme,
          ),
        ),
        // Subtle vertical separator
        Container(
          width: 1,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: theme.divider.withOpacity(0.1),
        ),
        Expanded(
          child: _buildStepper(
            context,
            label: loc.lineHeight,
            value: controller.lineHeight.toStringAsFixed(1),
            onRemove: () =>
                controller.setLineHeight(controller.lineHeight - 0.1),
            onAdd: () => controller.setLineHeight(controller.lineHeight + 0.1),
            theme: theme,
          ),
        ),
      ],
    );
  }

  Widget _buildStepper(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback onRemove,
    required VoidCallback onAdd,
    required NyanTheme theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.textSecondary.withOpacity(0.5),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                child:
                    Icon(Icons.remove_rounded, size: 22, color: theme.primary),
              ),
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 36),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimary,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                child: Icon(Icons.add_rounded, size: 22, color: theme.primary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThemeSection(
      BuildContext context, ReaderController controller, NyanTheme theme) {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildColorBtn(context, controller, const Color(0xFFF7F5EF), theme,
              label: loc.themeCream),
          const SizedBox(width: 16),
          _buildColorBtn(context, controller, const Color(0xFFEDE3C7), theme,
              label: loc.themeSepia),
          const SizedBox(width: 16),
          _buildColorBtn(context, controller, const Color(0xFF262422), theme,
              isDark: true, label: loc.themeSumi),
          const SizedBox(width: 16),
          _buildColorBtn(context, controller, const Color(0xFF141312), theme,
              isDark: true, label: loc.themeCharcoal),
        ],
      ),
    );
  }

  Widget _buildColorBtn(BuildContext context, ReaderController c, Color color,
      NyanTheme currentTheme,
      {bool isDark = false, String? label}) {
    final isSelected = c.backgroundColor.value == color.value;

    return GestureDetector(
      onTap: () => c.setBackground(color),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48, // Slightly larger touch target
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? currentTheme.primary
                    : const Color(0xFFE6E2D8), // Subtle border for unselected
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF8DA399).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(Icons.check_rounded,
                    color: isDark ? Colors.white : currentTheme.primary,
                    size: 26)
                : null,
          ),
          if (label != null) ...[
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? currentTheme.primary
                    : currentTheme.textSecondary.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActions(
      BuildContext context, ReaderController controller, NyanTheme theme) {
    final loc = AppLocalizations.of(context)!;
    // Helper for consistency
    Widget buildActionBtn(IconData icon, String tooltip, VoidCallback onTap,
        {bool isActive = false}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 26,
                color: isActive
                    ? theme.primary // Sage Green if active
                    : theme.textSecondary.withOpacity(0.8),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Better spacing
        children: [
          buildActionBtn(Icons.toc_rounded, loc.tableOfContents, () {
            // Close the current settings bottom sheet
            Navigator.of(context).pop();

            // Delay slightly to let the bottom sheet animation start before opening drawer
            Future.delayed(const Duration(milliseconds: 50), () {
              scaffoldKey.currentState?.openDrawer();
            });
          }),
          buildActionBtn(Icons.bookmark_border_rounded, loc.addBookmark,
              () async {
            final added = await controller.addBookmark();
            if (!added) return;

            final feedbackContext = scaffoldKey.currentContext;
            if (context.mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              final targetContext = feedbackContext ?? scaffoldKey.currentContext;
              if (targetContext == null || !targetContext.mounted) return;
              SnackBarUtils.show(targetContext, 'Bookmark Added!');
            });
          }),
          buildActionBtn(Icons.bookmarks_rounded, loc.bookmarks, () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookmarkListPage(
                  bookId: controller.book.id,
                  bookTitle: controller.book.title,
                ),
              ),
            );
            if (result != null && result is Map<String, dynamic>) {
              await controller.handleBookmarkSelection(result);
            }
          }),
          buildActionBtn(Icons.edit_note_rounded, loc.highlightsAndNotes,
              () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotesListPage(
                  bookId: controller.book.id,
                  bookTitle: controller.book.title,
                  onJumpToHighlight: (_) {},
                ),
              ),
            );

            await controller.loadHighlights();

            if (result != null && result is Highlight) {
              final selectedHighlight =
                  await controller.handleHighlightSelection(result);
              if (context.mounted && selectedHighlight != null) {
                _showHighlightNoteDialog(
                  context,
                  controller,
                  selectedHighlight,
                );
              }
            }
          }),
          buildActionBtn(Icons.settings_suggest_rounded, loc.settingsTitle, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsPage(),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showHighlightNoteDialog(
    BuildContext context,
    ReaderController controller,
    Highlight highlight,
  ) {
    showHighlightNoteDialog(
      context,
      highlight: highlight,
      onSave: (note, colorCode) => controller.updateHighlight(
        highlight.id,
        note: note,
        colorCode: colorCode,
      ),
      onDelete: () => controller.deleteHighlight(highlight.id),
    );
  }
}

class SliderWithFloatingLabel extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;

  const SliderWithFloatingLabel({
    Key? key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
  }) : super(key: key);

  @override
  State<SliderWithFloatingLabel> createState() =>
      _SliderWithFloatingLabelState();
}

class _SliderWithFloatingLabelState extends State<SliderWithFloatingLabel> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
            trackShape: const RoundedRectSliderTrackShape(),
            thumbColor: widget.thumbColor,
            overlayColor: widget.thumbColor?.withOpacity(0.12),
            activeTrackColor: widget.activeColor,
            inactiveTrackColor: widget.inactiveColor,
          ),
          child: Slider(
            value: widget.value,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            onChanged: widget.onChanged,
            onChangeStart: (_) => setState(() => _isDragging = true),
            onChangeEnd: (val) {
              setState(() => _isDragging = false);
              HapticFeedback.selectionClick(); // ADDED HAPTIC FEEDBACK
              if (widget.onChangeEnd != null) widget.onChangeEnd!(val);
            },
            activeColor: widget.activeColor,
            inactiveColor: widget.inactiveColor,
          ),
        ),
        Positioned(
          bottom: -20,
          child: AnimatedOpacity(
            opacity: _isDragging ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              "${(widget.value * 100).toInt()}%",
              style: TextStyle(
                fontSize: 10,
                color: (widget.activeColor ?? Theme.of(context).primaryColor)
                    .withOpacity(0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
