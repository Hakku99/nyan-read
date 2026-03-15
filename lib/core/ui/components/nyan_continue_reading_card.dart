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

  const NyanContinueReadingCard({
    super.key,
    required this.book,
    this.onContinue,
    this.progressLabel,
    this.buttonLabel = 'Continue Reading',
    this.compact = false,
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
    final cardPadding = compact ? NyanSpacing.space8 : NyanSpacing.space12;
    final titleSpacing = compact ? NyanSpacing.space8 : NyanSpacing.space12;

    return NyanInfoCard(
      padding: EdgeInsets.all(cardPadding),
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
      ),
    );
  }
}
