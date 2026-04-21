import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/nyan_radius.dart';
import '../../../../core/theme/nyan_spacing.dart';
import '../../../../core/ui/components/nyan_overlay_style.dart';
import '../../../../core/ui/components/nyan_sheet_card.dart';
import '../reader_overlay_tool_button.dart';
import 'reader_settings_common.dart';

/// Chapter progress and seek bar (reading overlay or legacy sheet layout).
///
/// Progress is accepted as a [ValueListenable]<double> so the widget can
/// repaint only the thumb and the "42%" label when the 1s reading
/// heartbeat advances the value, rather than rebuilding the whole card.
/// A one-shot [progress] is still accepted for callers that never animate.
class ReaderSettingsProgressCard extends StatelessWidget {
  const ReaderSettingsProgressCard({
    super.key,
    required this.chapterLabel,
    required this.showChapterNavigation,
    required this.onSeek,
    required this.onPreviousChapter,
    required this.onNextChapter,
    this.progress,
    this.progressListenable,
    this.forOverlay = false,
    this.overlayWidth,
  }) : assert(progress != null || progressListenable != null,
            'either progress or progressListenable must be provided');

  final String chapterLabel;
  final double? progress;
  final ValueListenable<double>? progressListenable;
  final bool showChapterNavigation;
  final ValueChanged<double> onSeek;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;

  /// When true, uses the same surface treatment as the reader overlay toolbar.
  final bool forOverlay;
  final double? overlayWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final progressSink = progressListenable ??
        ValueNotifier<double>(progress ?? 0.0);

    final body = Padding(
      padding: forOverlay
          ? kReaderOverlayChromePadding
          : const EdgeInsets.fromLTRB(
              NyanSpacing.space16,
              NyanSpacing.space16,
              NyanSpacing.space16,
              NyanSpacing.space12,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  chapterLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: NyanSpacing.space8),
              ValueListenableBuilder<double>(
                valueListenable: progressSink,
                builder: (context, value, _) {
                  final c = value.clamp(0.0, 1.0);
                  return Text(
                    '${(c * 100).round()}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary.withValues(alpha: 0.92),
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: forOverlay ? NyanSpacing.space12 : NyanSpacing.space16),
          Row(
            children: [
              if (showChapterNavigation) ...[
                if (forOverlay)
                  ReaderOverlayToolButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: onPreviousChapter,
                    tooltip: 'Previous chapter',
                  )
                else
                  ReaderSettingsIconButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: onPreviousChapter,
                    tooltip: 'Previous chapter',
                  ),
                const SizedBox(width: NyanSpacing.space12),
              ],
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: progressSink,
                  builder: (context, value, _) => ReaderSettingsSlider(
                    value: value.clamp(0.0, 1.0),
                    min: 0,
                    max: 1,
                    divisions: 1000,
                    onChanged: onSeek,
                    activeColor: theme.colorScheme.primary,
                    inactiveColor: theme.dividerColor.withValues(alpha: 0.24),
                  ),
                ),
              ),
              if (showChapterNavigation) ...[
                const SizedBox(width: NyanSpacing.space12),
                if (forOverlay)
                  ReaderOverlayToolButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: onNextChapter,
                    tooltip: 'Next chapter',
                  )
                else
                  ReaderSettingsIconButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: onNextChapter,
                    tooltip: 'Next chapter',
                  ),
              ],
            ],
          ),
        ],
      ),
    );

    if (forOverlay) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          key: const Key('reader-overlay-progress-card-surface'),
          width: overlayWidth,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              theme.colorScheme.surface.withValues(alpha: 0.92),
              theme.scaffoldBackgroundColor,
            ),
            borderRadius: BorderRadius.circular(NyanRadius.panel),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.18),
              width: 0.72,
            ),
            boxShadow: NyanOverlayStyle.noticeShadow(context),
          ),
          child: body,
        ),
      );
    }

    return NyanSheetCard(
      radius: NyanRadius.card,
      children: [body],
    );
  }
}
