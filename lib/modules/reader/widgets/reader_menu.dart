import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import '../reader_page.dart';
import 'chapter_list_widget.dart';
import '../../bookmark/bookmark_list_page.dart';
import '../../notes/notes_list_page.dart';
import '../reader_engine/txt/txt_position.dart';
import '../../../../core/models/highlight.dart';

class ReaderMenu extends StatelessWidget {
  const ReaderMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReaderController>();
    final theme = Theme.of(context);

    return SafeArea(
      bottom: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Progress Slider
            _buildProgressSection(context, controller, theme),

            const SizedBox(height: 24),

            // 2. Brightness Slider
            _buildBrightnessSection(context, controller, theme),

            const SizedBox(height: 24),
            Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
            const SizedBox(height: 24),

            // 3. Settings Row (Font, Line Height)
            _buildTypographySection(context, controller, theme),

            const SizedBox(height: 24),
            Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
            const SizedBox(height: 24),

            // 4. Themes (Background Colors)
            _buildThemeSection(context, controller, theme),

            const SizedBox(height: 24),
            Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),
            const SizedBox(height: 16),

            // 5. Bottom Navigation Actions
            _buildBottomActions(context, controller, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(
      BuildContext context, ReaderController controller, ThemeData theme) {
    return Row(
      children: [
        Text(
          "${(controller.currentProgress * 100).toInt()}%",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.primary.withOpacity(0.2),
              thumbColor: theme.colorScheme.primary,
              overlayColor: theme.colorScheme.primary.withOpacity(0.1),
            ),
            child: Slider(
              value: controller.currentProgress,
              min: 0.0,
              max: 1.0,
              onChanged: (val) => controller.seekTo(val),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrightnessSection(
      BuildContext context, ReaderController controller, ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.wb_sunny_outlined,
            size: 20, color: theme.colorScheme.onSurface.withOpacity(0.6)),
        const SizedBox(width: 16),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              activeTrackColor: theme.colorScheme.secondary,
              inactiveTrackColor: theme.colorScheme.secondary.withOpacity(0.2),
              thumbColor: theme.colorScheme.secondary,
            ),
            child: Slider(
              value: controller.brightness,
              min:
                  0.0, // Allow fuller range if supported, though system might clamp
              max: 1.0,
              onChanged: (val) => controller.setBrightness(val),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Icon(Icons.wb_sunny,
            size: 20, color: theme.colorScheme.onSurface.withOpacity(0.6)),
      ],
    );
  }

  Widget _buildTypographySection(
      BuildContext context, ReaderController controller, ThemeData theme) {
    final loc = AppLocalizations.of(context)!;
    return Row(
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
    required ThemeData theme,
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
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        Container(
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surface,
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onRemove,
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(11)),
                  child: Icon(Icons.remove,
                      size: 18, color: theme.colorScheme.onSurface),
                ),
              ),
              Container(
                width: 1,
                height: 20,
                color: theme.dividerColor.withOpacity(0.5),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 40),
                alignment: Alignment.center,
                child: Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 20,
                color: theme.dividerColor.withOpacity(0.5),
              ),
              Expanded(
                child: InkWell(
                  onTap: onAdd,
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(11)),
                  child: Icon(Icons.add,
                      size: 18, color: theme.colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSection(
      BuildContext context, ReaderController controller, ThemeData theme) {
    final loc = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildColorBtn(context, controller, const Color(0xFFFDFCF8),
              label: loc.themeCream),
          const SizedBox(width: 16),
          _buildColorBtn(context, controller, const Color(0xFFF5F5DC),
              label: loc.themeSepia),
          const SizedBox(width: 16),
          _buildColorBtn(context, controller, const Color(0xFF262422),
              isDark: true, label: loc.themeSumi),
          const SizedBox(width: 16),
          _buildColorBtn(context, controller, const Color(0xFF1C1B1A),
              isDark: true, label: loc.themeCharcoal),
        ],
      ),
    );
  }

  Widget _buildColorBtn(BuildContext context, ReaderController c, Color color,
      {bool isDark = false, String? label}) {
    final isSelected = c.backgroundColor.value == color.value;
    final theme = Theme.of(context);

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
                    ? theme.colorScheme.primary
                    : theme.dividerColor.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.2),
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
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActions(
      BuildContext context, ReaderController controller, ThemeData theme) {
    final loc = AppLocalizations.of(context)!;
    Widget buildActionBtn(IconData icon, String tooltip, VoidCallback onTap) {
      return IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onTap,
        color: theme.colorScheme.onSurface.withOpacity(0.8),
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
      ],
    );
  }
}
