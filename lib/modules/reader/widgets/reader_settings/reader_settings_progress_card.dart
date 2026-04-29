import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/nyan_radius.dart';
import '../../../../core/theme/nyan_spacing.dart';
import '../../../../core/ui/components/nyan_sheet_card.dart';
import '../reader_overlay_tool_button.dart';
import 'reader_settings_common.dart';

/// Chapter progress and seek bar (reading overlay or legacy sheet layout).
///
/// Progress is accepted as a `ValueListenable<double>` so the widget can
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
    this.forQuickSheet = false,
    this.overlayWidth,
  })  : assert(progress != null || progressListenable != null,
            'either progress or progressListenable must be provided'),
        assert(
          !(forQuickSheet && forOverlay),
          'forQuickSheet and forOverlay are mutually exclusive',
        );

  final String chapterLabel;
  final double? progress;
  final ValueListenable<double>? progressListenable;
  final bool showChapterNavigation;
  final ValueChanged<double> onSeek;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;

  /// When true, uses the same surface treatment as the reader overlay toolbar.
  final bool forOverlay;

  /// Embedded in the L1 quick sheet: no outer [NyanSheetCard]; [forOverlay] must
  /// be false. Uses overlay-style chapter nav affordances.
  final bool forQuickSheet;
  final double? overlayWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final progressSink =
        progressListenable ?? ValueNotifier<double>(progress ?? 0.0);

    final useOverlayStyleButtons = forOverlay;
    final isQuickSurface = forQuickSheet;
    final quickNavGap = isQuickSurface ? NyanSpacing.space4 : NyanSpacing.space12;
    final sheetPadding = forQuickSheet
        ? EdgeInsets.zero
        : forOverlay
            ? kReaderOverlayChromePadding
            : const EdgeInsets.fromLTRB(
                NyanSpacing.space16,
                NyanSpacing.space16,
                NyanSpacing.space16,
                NyanSpacing.space12,
              );

    final body = Padding(
      padding: sheetPadding,
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
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.2,
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
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.primary.withValues(alpha: 0.92),
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(
            height: isQuickSurface
                ? NyanSpacing.space12
                : (forOverlay ? NyanSpacing.space12 : NyanSpacing.space16),
          ),
          Row(
            children: [
              if (showChapterNavigation) ...[
                if (isQuickSurface)
                  _QuickArrowIconButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: onPreviousChapter,
                    tooltip: 'Previous chapter',
                  )
                else if (useOverlayStyleButtons)
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
                SizedBox(width: quickNavGap),
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
                SizedBox(width: quickNavGap),
                if (isQuickSurface)
                  _QuickArrowIconButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: onNextChapter,
                    tooltip: 'Next chapter',
                  )
                else if (useOverlayStyleButtons)
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

    if (forQuickSheet) {
      return SizedBox(
        width: overlayWidth,
        child: body,
      );
    }

    if (forOverlay) {
      return Align(
        alignment: Alignment.center,
        child: SizedBox(
          key: const Key('reader-overlay-progress-card-surface'),
          width: overlayWidth,
          child: NyanSheetCard(
            radius: NyanRadius.card,
            children: [body],
          ),
        ),
      );
    }

    return NyanSheetCard(
      radius: NyanRadius.card,
      children: [body],
    );
  }
}

class _QuickArrowIconButton extends StatelessWidget {
  const _QuickArrowIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NyanRadius.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NyanSpacing.space4,
          vertical: 10,
        ),
        child: Icon(
          icon,
          size: 20,
          color: theme.colorScheme.primary.withValues(alpha: 0.76),
        ),
      ),
    );
    if (tooltip == null || tooltip!.isEmpty) {
      return button;
    }
    return Tooltip(message: tooltip!, child: button);
  }
}
