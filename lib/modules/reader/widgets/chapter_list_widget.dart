import 'package:flutter/material.dart';

/// 章节列表组件
/// 显示书籍章节目录,支持当前章节高亮和已读章节弱化
class ChapterListWidget extends StatelessWidget {
  final List<dynamic> chapters;
  final int? currentChapterIndex;
  final double currentProgress;
  final ScrollController? scrollController;
  final Function(int index, dynamic chapterData) onChapterTap;

  const ChapterListWidget({
    Key? key,
    required this.chapters,
    this.currentChapterIndex,
    required this.currentProgress,
    this.scrollController,
    required this.onChapterTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (chapters.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No chapters detected',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
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
                  Text(
                    'Table of Contents',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${chapters.length} chapters',
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
              child: Scrollbar(
                thumbVisibility: true,
                controller: scrollController,
                child: ListView.builder(
                  controller: scrollController,
                  shrinkWrap: true,
                  itemCount: chapters.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    final chapterIndex = chapter['index'] ?? index;
                    final title = chapter['title'] ?? 'Chapter ${index + 1}';

                    // 判断是否为当前章节
                    final isCurrent = currentChapterIndex == chapterIndex;

                    // 判断是否已读 (简化版: 基于章节索引和总进度)
                    final isRead =
                        (chapterIndex / chapters.length) < currentProgress;

                    return _buildChapterItem(
                      context,
                      title: title,
                      index: index,
                      isCurrent: isCurrent,
                      isRead: isRead,
                      onTap: () => onChapterTap(index, chapter),
                    );
                  },
                ),
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

    return Material(
      color:
          isCurrent ? theme.primaryColor.withOpacity(0.1) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                  maxLines: 2,
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
