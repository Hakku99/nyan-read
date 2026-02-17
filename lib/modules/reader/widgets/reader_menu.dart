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
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: themeManager.currentPreset == ThemePreset.creamLight
              ? const Color(0xFFFAF9F6)
              : activeTheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            if (themeManager.currentPreset == ThemePreset.creamLight)
              BoxShadow(
                color: const Color(0xFF4A453E).withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, -4),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
          ],
          border: themeManager.currentPreset == ThemePreset.creamLight
              ? Border.all(color: const Color(0xFFD8D4C8), width: 1.0)
              : Border.all(color: activeTheme.divider.withOpacity(0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Progress Slider
            _buildProgressSection(context, controller, activeTheme),

            const SizedBox(height: 24),

            // 2. Brightness Slider
            _buildBrightnessSection(context, controller, activeTheme),

            const SizedBox(height: 24),
            Divider(
                height: 1,
                color: themeManager.currentPreset == ThemePreset.creamLight
                    ? const Color(0xFFD8D4C8)
                    : activeTheme.divider.withOpacity(0.5)),
            const SizedBox(height: 24),

            // 3. Settings Row (Font, Line Height)
            _buildTypographySection(context, controller, activeTheme),

            const SizedBox(height: 24),
            Divider(
                height: 1,
                color: themeManager.currentPreset == ThemePreset.creamLight
                    ? const Color(0xFFD8D4C8)
                    : activeTheme.divider.withOpacity(0.5)),
            const SizedBox(height: 24),

            // 4. Themes (Background Colors)
            _buildThemeSection(context, controller, activeTheme),

            const SizedBox(height: 24),
            Divider(
                height: 1,
                color: themeManager.currentPreset == ThemePreset.creamLight
                    ? const Color(0xFFD8D4C8)
                    : activeTheme.divider.withOpacity(0.5)),
            const SizedBox(height: 16),

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
      crossAxisAlignment:
          CrossAxisAlignment.center, // Ensure vertical alignment
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded), // Softer chevron
          iconSize: 24, // Adjusted size for chevron
          visualDensity: VisualDensity.standard,
          onPressed: () => controller.jumpToPreviousChapter(),
          color: theme.primary,
          tooltip: "Previous Chapter",
        ),
        Expanded(
          child: Slider(
            value: controller.currentProgress,
            min: 0.0,
            max: 1.0,
            label: "${(controller.currentProgress * 100).toInt()}%",
            divisions: 1000,
            onChanged: (val) => controller.seekTo(val),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded), // Softer chevron
          iconSize: 24, // Adjusted size for chevron
          visualDensity: VisualDensity.standard,
          onPressed: () => controller.jumpToNextChapter(),
          color: theme.primary,
          tooltip: "Next Chapter",
        ),
      ],
    );
  }

  Widget _buildBrightnessSection(
      BuildContext context, ReaderController controller, NyanTheme theme) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center, // Ensure vertical alignment
      children: [
        // Balanced visual weight: Filled rounded icon
        Icon(Icons.wb_sunny_rounded,
            size: 22, color: theme.textSecondary.withOpacity(0.6)),
        const SizedBox(width: 16),
        Expanded(
          // Slider is always interactive now
          child: Slider(
            value: controller.brightness,
            min: 0.0,
            max: 1.0,
            onChanged: (val) => controller.setBrightness(val),
            // Ensure proper visual feedback when "following system" - maybe indicate somehow?
            // Actually, requirements say "Slider looks active (Matcha Green)" which is default active color.
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
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                // Active: Subtle colored background. Inactive: Transparent
                color: controller.followSystem
                    ? theme.primary.withOpacity(0.15)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.brightness_auto_rounded,
                size: 22,
                // Active: Primary Color. Inactive: Grey/Hint color
                color: controller.followSystem
                    ? theme.primary
                    : theme.textSecondary.withOpacity(0.6),
              ),
            ),
          ),
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
            ? const Color(0xFFF2F0EB)
            : theme.surface.withOpacity(0.5), // Subtle grouping for others
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Font Size Control
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

          const SizedBox(width: 16),

          // Line Height Control
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.textSecondary.withOpacity(0.8),
            ),
          ),
        ),
        Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.preset == ThemePreset.creamLight
                ? Colors.white
                : theme.textPrimary.withOpacity(0.08),
            border: theme.preset == ThemePreset.creamLight
                ? Border.all(color: const Color(0xFFD8D4C8))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onRemove,
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(11)),
                  child: Icon(Icons.remove, size: 18, color: theme.textPrimary),
                ),
              ),
              // Removed or made dividers very subtle if needed.
              // Here we can remove them for a cleaner look or use a very faint color.
              Container(
                width: 1,
                height: 20,
                color: theme.divider.withOpacity(0.2), // Much more subtle
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 40),
                alignment: Alignment.center,
                child: Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.textPrimary,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 20,
                color: theme.divider.withOpacity(0.2),
              ),
              Expanded(
                child: InkWell(
                  onTap: onAdd,
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(11)),
                  child: Icon(Icons.add, size: 18, color: theme.textPrimary),
                ),
              ),
            ],
          ),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? currentTheme.primary
                    : currentTheme.primary.withOpacity(0.3),
                width: isSelected ? 2 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: currentTheme.primary.withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(Icons.check,
                    color: isDark ? Colors.white : Colors.black87, size: 24)
                : null,
          ),
          if (label != null) ...[
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? currentTheme.primary
                    : currentTheme.textSecondary.withOpacity(0.8),
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
    Widget buildActionBtn(IconData icon, String tooltip, VoidCallback onTap) {
      return IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onTap,
        color: theme.textPrimary.withOpacity(0.8),
        iconSize: 26,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        buildActionBtn(Icons.list_alt_rounded, loc.tableOfContents, () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: DraggableScrollableSheet(
                initialChildSize: 0.6,
                minChildSize: 0.3,
                maxChildSize: 0.9,
                builder: (context, scrollController) => GestureDetector(
                  onTap: () {},
                  child: ChapterListWidget(
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
              ),
            ),
          );
        }),
        buildActionBtn(Icons.bookmark_add_outlined, loc.addBookmark,
            () => controller.addBookmark(context)),
        buildActionBtn(Icons.bookmarks_outlined, loc.bookmarks, () async {
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
        buildActionBtn(Icons.settings_outlined, loc.settingsTitle, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SettingsPage(),
            ),
          );
        }),
      ],
    );
  }
}
