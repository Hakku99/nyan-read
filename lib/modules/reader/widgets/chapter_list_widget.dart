import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../reader_engine/reader_engine.dart';

/// 章节列表组件
/// 显示书籍章节目录,支持当前章节高亮和已读章节弱化
class ChapterListWidget extends StatefulWidget {
  final List<dynamic> chapters;
  final int? currentChapterIndex;
  final double currentProgress;
  final ScrollController? scrollController;
  final void Function(int index, ChapterLocator locator) onChapterTap;

  const ChapterListWidget({
    Key? key,
    required this.chapters,
    this.currentChapterIndex,
    required this.currentProgress,
    this.scrollController,
    required this.onChapterTap,
  }) : super(key: key);

  @override
  State<ChapterListWidget> createState() => _ChapterListWidgetState();
}

class _ChapterListWidgetState extends State<ChapterListWidget> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();

    // Schedule scroll to current chapter
    if (widget.currentChapterIndex != null && widget.currentChapterIndex! > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_itemScrollController.isAttached) {
          _itemScrollController.jumpTo(
            index: widget.currentChapterIndex!,
            alignment:
                0.1, // Show a bit of previous context if possible, or just near top
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
      ),
      child: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.list, color: theme.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      loc.tableOfContents,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    loc.chapterCount(widget.chapters.length),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // 章节列表
            Flexible(
              child: widget.chapters.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(48),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.menu_book_outlined,
                                size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              loc.noChaptersDetected,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ScrollablePositionedList.builder(
                      itemCount: widget.chapters.length,
                      itemScrollController: _itemScrollController,
                      itemPositionsListener: _itemPositionsListener,
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, index) {
                        final chapter = widget.chapters[index];
                        final chapterIndex = chapter['index'] ?? index;
                        final title =
                            chapter['title'] ?? loc.chapterName(index + 1);

                        // 判断是否为当前章节
                        final isCurrent =
                            widget.currentChapterIndex == chapterIndex;

                        // 判断是否已读 (简化版: 基于章节索引和总进度)
                        final isRead = (chapterIndex / widget.chapters.length) <
                            widget.currentProgress;

                        return _buildChapterItem(
                          context,
                          title: title,
                          index: index,
                          isCurrent: isCurrent,
                          isRead: isRead,
                          onTap: () => widget.onChapterTap(
                            index,
                            ChapterLocator.fromChapterData(
                              chapter as Map<String, dynamic>,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterItem(
    BuildContext context, {
    required String title,
    required int index,
    required bool isCurrent,
    required bool isRead,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    // Ensure item height is consistent for scrolling estimation
    return Material(
      color:
          isCurrent ? theme.primaryColor.withOpacity(0.1) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56.0, // Fixed height for consistent scrolling
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              // 章节序号
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? theme.primaryColor
                      : isRead
                          ? Colors.grey.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isCurrent
                        ? Colors.white
                        : isRead
                            ? Colors.grey[600]
                            : Colors.grey[700],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 章节标题
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    color: isCurrent
                        ? theme.primaryColor
                        : isRead
                            ? Colors.grey[600]
                            : theme.textTheme.bodyLarge?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 当前章节指示器
              if (isCurrent)
                Icon(
                  Icons.play_arrow,
                  color: theme.primaryColor,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
