import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../theme/nyan_shelf_ui.dart';
import '../../theme/nyan_spacing.dart';
import 'nyan_info_card.dart';
import 'nyan_primary_button.dart';
import '../nyan_icons.dart';
import '../nyan_theme_context.dart';

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
    final EdgeInsetsGeometry cardPadding;
    if (collapsed) {
      cardPadding = EdgeInsets.symmetric(
        horizontal: compact ? NyanSpacing.space8 : NyanSpacing.space12,
        vertical: NyanSpacing.space8,
      );
    } else if (compact) {
      cardPadding = const EdgeInsets.all(NyanSpacing.space8);
    } else {
      cardPadding = const EdgeInsets.symmetric(
        horizontal: NyanSpacing.space16,
        vertical: NyanSpacing.space12,
      );
    }

    /// Between title block and progress / CTA row.
    final titleSpacing = compact
        ? NyanSpacing.space4
        : (hasAuthor ? NyanSpacing.space8 : NyanSpacing.space4);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: NyanInfoCard(
        padding: cardPadding,
        child: collapsed
            ? _buildCollapsedLayout(
                context,
                theme,
                resolvedProgressLabel,
              )
            : _buildExpandedLayout(
                context,
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
    BuildContext context,
    ThemeData theme,
    bool hasAuthor,
    String resolvedProgressLabel,
    double progress,
    double titleSpacing,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.only(
                right: onToggleCollapse != null ? 36 : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: compact ? 15 : 16,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (hasAuthor) ...[
                    const SizedBox(height: NyanSpacing.space4),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.2,
                        color: context.nyanTheme.textPrimary.withValues(
                          alpha: 0.62,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onToggleCollapse != null)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildCollapseButton(
                    context,
                    expanded: true,
                    compact: true,
                    dense: true,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: titleSpacing),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resolvedProgressLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.1,
                          color: context.nyanTheme.textPrimary.withValues(
                            alpha: 0.62,
                          ),
                        ),
                      ),
                      const SizedBox(height: NyanSpacing.space8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          NyanShelfUi.progressBarHeight / 2,
                        ),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: NyanShelfUi.progressBarHeight,
                          backgroundColor: context.nyanTheme.primary
                              .withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.nyanTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: NyanSpacing.space12),
              NyanPrimaryButton(
                label: buttonLabel,
                onPressed: onContinue,
                size: NyanPrimaryButtonSize.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedLayout(
    BuildContext context,
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
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  height: 1.2,
                  color: context.nyanTheme.textPrimary.withValues(
                    alpha: 0.62,
                  ),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: NyanSpacing.space8),
        NyanPrimaryButton(
          label: buttonLabel,
          onPressed: onContinue,
          size: NyanPrimaryButtonSize.compact,
        ),
        if (onToggleCollapse != null) ...[
          const SizedBox(width: NyanSpacing.space4),
          _buildCollapseButton(
            context,
            expanded: false,
            compact: true,
          ),
        ],
      ],
    );
  }

  Widget _buildCollapseButton(
    BuildContext context, {
    required bool expanded,
    bool compact = false,
    bool dense = false,
  }) {
    final m = MaterialLocalizations.of(context);
    return IconButton(
      onPressed: onToggleCollapse,
      tooltip: expanded ? m.expandedIconTapHint : m.collapsedIconTapHint,
      icon: Icon(
        expanded ? NyanIcons.chevronUp : NyanIcons.chevronDown,
        size: NyanSpacing.space20,
      ),
      constraints: BoxConstraints(
        minWidth: dense ? 36 : NyanSpacing.minTapTarget,
        minHeight: dense ? 36 : NyanSpacing.minTapTarget,
      ),
      padding: EdgeInsets.all(
        dense
            ? NyanSpacing.space4
            : (compact ? NyanSpacing.space4 : NyanSpacing.space8),
      ),
      style: IconButton.styleFrom(
        foregroundColor: context.nyanTheme.textPrimary.withValues(alpha: 0.55),
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      ),
    );
  }
}
