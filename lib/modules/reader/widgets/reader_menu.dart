import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import '../reader_page.dart';
import 'chapter_list_widget.dart';
import '../../bookmark/bookmark_list_page.dart';
import '../../notes/notes_list_page.dart';
import '../../settings/settings_page.dart';
import '../reader_engine/txt/txt_position.dart';
import '../../../../core/models/highlight.dart';
import '../../../../core/theme/theme_presets.dart';
import '../../../../core/theme/theme_manager.dart';
import '../../../../core/services/reader_preferences_service.dart';

class ReaderMenu extends StatelessWidget {
  const ReaderMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReaderController>();
    final themeManager = context.watch<ThemeManager>();
    // Use the global app theme for the menu, decoupled from the reader's background color
    final activeTheme = themePresets[themeManager.currentPreset]!;

    return SafeArea(
      bottom: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: themeManager.currentPreset == ThemePreset.creamLight
              ? const Color(0xFFFAF9F6)
              : activeTheme.surface,
          borderRadius: BorderRadius.circular(24), // Soft corners
          boxShadow: [
            if (themeManager.currentPreset == ThemePreset.creamLight)
              BoxShadow(
                color: const Color(0x1A5D4037), // Diffused warm shadow
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
          ],
          border: themeManager.currentPreset == ThemePreset.creamLight
              ? Border.all(color: const Color(0xFFF0EFE9), width: 1.5)
              : Border.all(color: activeTheme.divider.withOpacity(0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Progress Slider
            _buildProgressSection(context, controller, activeTheme),

            const SizedBox(height: 28),

            // 2. Brightness Slider
            _buildBrightnessSection(context, controller, activeTheme),

            const SizedBox(height: 28),
            Divider(
                height: 1,
                color: themeManager.currentPreset == ThemePreset.creamLight
                    ? const Color(0xFFE6E2D8)
                    : activeTheme.divider.withOpacity(0.5)),
            const SizedBox(height: 28),

            // 3. Settings Row (Font, Line Height)
            _buildTypographySection(context, controller, activeTheme),

            const SizedBox(height: 28),
            Divider(
                height: 1,
                color: themeManager.currentPreset == ThemePreset.creamLight
                    ? const Color(0xFFE6E2D8)
                    : activeTheme.divider.withOpacity(0.5)),
            const SizedBox(height: 28),

            // 4. Themes (Background Colors)
            _buildThemeSection(context, controller, activeTheme),

            const SizedBox(height: 28),
            Divider(
                height: 1,
                color: themeManager.currentPreset == ThemePreset.creamLight
                    ? const Color(0xFFE6E2D8)
                    : activeTheme.divider.withOpacity(0.5)),
            const SizedBox(height: 20),

            // 5. Bottom Navigation Actions
            _buildBottomActions(context, controller, activeTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(
      BuildContext context, ReaderController controller, NyanTheme theme) {
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
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: controller.currentProgress,
              min: 0.0,
              max: 1.0,
              label: "${(controller.currentProgress * 100).toInt()}%",
              divisions: 1000,
              onChanged: (val) => controller.seekTo(val),
              activeColor: theme.primary,
              inactiveColor: theme.preset == ThemePreset.creamLight
                  ? const Color(0xFFE6E2D8)
                  : theme.divider.withOpacity(0.3),
            ),
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
    required NyanTheme theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.preset == ThemePreset.creamLight
              ? const Color(0xFFF0EFE9)
              : theme.surface.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 24,
          color: theme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildBrightnessSection(
      BuildContext context, ReaderController controller, NyanTheme theme) {
    final prefs = context.watch<ReaderPreferencesService>();

    return Column(
      children: [
        // 1. Brightness Slider
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.wb_sunny_outlined, // Outlined sun
                size: 22,
                color: theme.textSecondary.withOpacity(0.6)),
            const SizedBox(width: 16),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6.0,
                  trackShape: const RoundedRectSliderTrackShape(),
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                child: Slider(
                  value: controller.brightness,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => controller.setBrightness(val),
                  activeColor: theme.textSecondary
                      .withOpacity(0.8), // Darker grey for brightness
                  inactiveColor: theme.divider.withOpacity(0.5),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Tooltip(
              message: controller.followSystem
                  ? "Stop Following System"
                  : "Follow System Brightness",
              child: InkWell(
                onTap: () => controller.toggleFollowSystem(),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: controller.followSystem
                        ? theme.primary // Sage Green when active
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: controller.followSystem
                        ? null
                        : Border.all(
                            color: theme.textSecondary.withOpacity(0.4),
                            width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    controller.followSystem
                        ? Icons.brightness_auto // Filled when active
                        : Icons.brightness_auto_outlined,
                    size: 20,
                    color: controller.followSystem
                        ? Colors.white
                        : theme.textSecondary.withOpacity(0.8),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(
            height:
                24), // Extra spacing for the floating label above? No, below.

        // 2. Warmth Slider (New Design)
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none, // Allow drawing outside for floating label
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.thermostat_rounded,
                    size: 22, color: const Color(0xFFFFCCBC)), // Apricot icon
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0x222196F3), // Cool Blue (Transparent-ish)
                          Color(0xFFFFCCBC), // Soft Apricot
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6.0,
                        trackShape: const RoundedRectSliderTrackShape(),
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 8),
                        thumbColor: const Color(0xFFFFAB91), // Peach Thumb
                        activeTrackColor: Colors.transparent, // Uses Gradient
                        inactiveTrackColor: Colors.transparent, // Uses Gradient
                        overlayColor: const Color(0xFFFFAB91).withOpacity(0.12),
                      ),
                      child: Slider(
                        value: prefs.warmth,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) => prefs.setWarmth(val),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Placeholder to balance layout if needed, or keeping empty for now
                // The floating label takes the place of the side text.
                const SizedBox(width: 36),
              ],
            ),

            // Floating Label
            Positioned(
              bottom: -20.0, // Push into negative space
              left: 40 + 16, // Align with track start (Icon=24 + Gap=16) approx
              right: 16 + 36, // Align with track end (Gap=16 + Spacer=36)
              child: Center(
                child: Text(
                  "${(prefs.warmth * 100).toInt()}%",
                  style: TextStyle(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: const Color(0xFFFFAB91), // Peach Text
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypographySection(
      BuildContext context, ReaderController controller, NyanTheme theme) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: theme.preset == ThemePreset.creamLight
            ? const Color(0xFFF5F5F0) // Slightly darker cream for grouping
            : theme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          Container(
            width: 1,
            height: 32,
            color: theme.divider.withOpacity(0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: _buildStepper(
              context,
              label: loc.lineHeight,
              value: controller.lineHeight.toStringAsFixed(1),
              onRemove: () =>
                  controller.setLineHeight(controller.lineHeight - 0.1),
              onAdd: () =>
                  controller.setLineHeight(controller.lineHeight + 0.1),
              theme: theme,
            ),
          ),
        ],
      ),
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
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.textSecondary.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(Icons.remove_rounded,
                    size: 20, color: theme.textPrimary),
              ),
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 40),
              alignment: Alignment.center,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.textPrimary,
                  fontSize: 16,
                ),
              ),
            ),
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child:
                    Icon(Icons.add_rounded, size: 20, color: theme.textPrimary),
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
                        color: currentTheme.primary.withOpacity(0.25),
                        blurRadius: 10,
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
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => DraggableScrollableSheet(
                initialChildSize: 0.6,
                minChildSize: 0.3,
                maxChildSize: 0.9,
                builder: (context, scrollController) => ChapterListWidget(
                  chapters: controller.chapters,
                  currentChapterIndex: controller.currentChapterIndex,
                  currentProgress: controller.currentProgress,
                  scrollController: scrollController,
                  onChapterTap: (index, chapterData) {
                    Navigator.pop(context);
                    controller.jumpToChapter(index, chapterData);
                  },
                ),
              ),
            );
          }),
          buildActionBtn(Icons.bookmark_border_rounded, loc.addBookmark,
              () => controller.addBookmark(context)),
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
              controller.restorePosition(result);
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
                ),
              ),
            );

            await controller.loadHighlights();

            if (result != null && result is Highlight) {
              if (controller.book.format == 'txt') {
                final pos =
                    TxtReadingPosition(paragraphIndex: result.paragraphIndex);
                await controller.engine.goToPosition(pos);
              }
              if (context.mounted) {
                controller.showNoteDialog(context, result);
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
}
