import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import 'nyan_info_card.dart';
import 'nyan_primary_button.dart';

class NyanContinueReadingCard extends StatelessWidget {
  final Book book;
  final VoidCallback? onContinue;
  final String? progressLabel;
  final String buttonLabel;
  final bool compact;
  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  const NyanContinueReadingCard({
    super.key,
    required this.book,
    this.onContinue,
    this.progressLabel,
    this.buttonLabel = 'Continue Reading',
    this.compact = false,
    this.collapsed = false,
    this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = book.currentProgress.clamp(0.0, 1.0);
    final resolvedProgressLabel =
        progressLabel ?? '${(progress * 100).toStringAsFixed(0)}%';
    final hasAuthor =
        book.author.trim().isNotEmpty &&
        book.author.trim().toLowerCase() != 'unknown';
    final horizontalPadding = compact
        ? NyanSpacing.space8
        : NyanSpacing.space12;
    final verticalPadding = collapsed
        ? NyanSpacing.space8
        : (compact ? NyanSpacing.space8 : NyanSpacing.space12);
    final titleSpacing = compact ? NyanSpacing.space8 : NyanSpacing.space12;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: NyanInfoCard(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: collapsed
            ? _buildCollapsedLayout(
                theme,
                resolvedProgressLabel,
              )
            : _buildExpandedLayout(
                theme,
                hasAuthor,
                resolvedProgressLabel,
                progress,
                titleSpacing,
              ),
      ),
    );
  }

  Widget _buildExpandedLayout(
    ThemeData theme,
    bool hasAuthor,
    String resolvedProgressLabel,
    double progress,
    double titleSpacing,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hasAuthor) ...[
                    const SizedBox(height: NyanSpacing.space4),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (onToggleCollapse != null) ...[
              const SizedBox(width: NyanSpacing.space8),
              _buildCollapseButton(expanded: true),
            ],
          ],
        ),
        SizedBox(height: titleSpacing),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resolvedProgressLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: NyanSpacing.space8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(NyanRadius.small),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: NyanSpacing.space4,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: NyanSpacing.space12),
            NyanPrimaryButton(
              label: buttonLabel,
              onPressed: onContinue,
              padding: EdgeInsets.symmetric(
                horizontal: compact
                    ? NyanSpacing.space12
                    : NyanSpacing.space16,
                vertical: NyanSpacing.space8,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCollapsedLayout(
    ThemeData theme,
    String resolvedProgressLabel,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: NyanSpacing.space4),
              Text(
                resolvedProgressLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.78,
                  ),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: NyanSpacing.space8),
        NyanPrimaryButton(
          label: buttonLabel,
          onPressed: onContinue,
          padding: const EdgeInsets.symmetric(
            horizontal: NyanSpacing.space12,
            vertical: NyanSpacing.space4,
          ),
        ),
        if (onToggleCollapse != null) ...[
          const SizedBox(width: NyanSpacing.space4),
          _buildCollapseButton(
            expanded: false,
            compact: true,
          ),
        ],
      ],
    );
  }

  Widget _buildCollapseButton({
    required bool expanded,
    bool compact = false,
  }) {
    return IconButton(
      onPressed: onToggleCollapse,
      icon: Icon(
        expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
        size: NyanSpacing.space20,
      ),
      constraints: const BoxConstraints(
        minWidth: NyanSpacing.minTapTarget,
        minHeight: NyanSpacing.minTapTarget,
      ),
      padding: EdgeInsets.all(
        compact ? NyanSpacing.space4 : NyanSpacing.space8,
      ),
      visualDensity: VisualDensity.compact,
      splashRadius: compact ? NyanSpacing.space16 : NyanSpacing.space20,
    );
  }
}
