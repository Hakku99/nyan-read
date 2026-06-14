import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../theme/nyan_radius.dart';
import '../../theme/nyan_shadows.dart';
import '../../theme/nyan_spacing.dart';
import '../../theme/nyan_typography.dart';
import 'nyan_primary_button.dart';
import '../nyan_icons.dart';
import '../nyan_theme_context.dart';
import '../../theme/theme_presets.dart';

/// Collapsible "Continue Reading" hero card — bundle3.jsx ContinueCard spec.
///
/// Always-visible header: book icon + "Continue Reading" eyebrow + rotating caret.
/// Collapsed header also shows book title + progress %.
/// Expanded body: 56×72 cover thumbnail, title/author, inline progress bar + %, full-width CTA.
class NyanContinueReadingCard extends StatelessWidget {
  final Book book;
  final VoidCallback? onContinue;
  final String buttonLabel;
  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  // Legacy params — kept for call-site compat, not used in the layout.
  final String? progressLabel;
  final bool compact;

  const NyanContinueReadingCard({
    super.key,
    required this.book,
    this.onContinue,
    this.buttonLabel = 'Continue Reading',
    this.collapsed = false,
    this.onToggleCollapse,
    this.progressLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final progress = book.currentProgress.clamp(0.0, 1.0);
    final pct = (progress * 100).round();
    final hasAuthor = book.author.trim().isNotEmpty &&
        book.author.trim().toLowerCase() != 'unknown';

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: const Cubic(0.33, 0.9, 0.36, 1), // ease-paper
      alignment: Alignment.topCenter,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: nyan.surface,
          borderRadius: BorderRadius.circular(NyanRadius.cardNested), // 16pt
          border: Border.all(
            color: nyan.divider.withValues(alpha: 0.36),
            width: 0.72,
          ),
          boxShadow: NyanShadows.subtle(nyan),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context, nyan, pct),
            if (!collapsed) _buildBody(context, nyan, progress, pct, hasAuthor),
          ],
        ),
      ),
    );
  }

  /// Always-visible header row — tapping collapses/expands the body.
  Widget _buildHeader(BuildContext context, NyanTheme nyan, int pct) {
    return GestureDetector(
      onTap: onToggleCollapse,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          NyanSpacing.space12,
          collapsed ? 11 : NyanSpacing.space12,
          NyanSpacing.space12,
          collapsed ? 11 : NyanSpacing.space8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(NyanIcons.book, size: 15, color: nyan.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Continue Reading',
                    style: TextStyle(
                      fontFamily: NyanTypography.uiFontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                      letterSpacing: 0.2,
                      color: nyan.textMuted,
                    ),
                  ),
                  if (collapsed) ...[
                    const SizedBox(height: 2),
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: NyanTypography.uiFontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: nyan.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (collapsed) ...[
              const SizedBox(width: NyanSpacing.space8),
              Text(
                '$pct%',
                style: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  color: nyan.primaryDeep,
                ),
              ),
            ],
            const SizedBox(width: NyanSpacing.space8),
            // Caret rotates 180° when expanded
            AnimatedRotation(
              turns: collapsed ? 0 : 0.5,
              duration: const Duration(milliseconds: 200),
              curve: const Cubic(0.33, 0.9, 0.36, 1),
              child: Icon(NyanIcons.chevronDown, size: 15, color: nyan.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  /// Expanded body: cover + title/author/progress row + full-width CTA.
  Widget _buildBody(
    BuildContext context,
    NyanTheme nyan,
    double progress,
    int pct,
    bool hasAuthor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NyanSpacing.space12,
        0,
        NyanSpacing.space12,
        NyanSpacing.space12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cover thumbnail: 56 × 72, 14pt radius
              Container(
                width: 56,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Color.alphaBlend(
                    nyan.primary.withValues(alpha: 0.12),
                    nyan.surfaceMuted,
                  ),
                  border: Border.all(
                    color: nyan.divider.withValues(alpha: 0.30),
                    width: 0.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(NyanIcons.book, size: 22, color: nyan.primary),
              ),
              const SizedBox(width: NyanSpacing.space12),
              // Title / author / progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: NyanTypography.uiFontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        letterSpacing: -0.1,
                        color: nyan.textPrimary,
                      ),
                    ),
                    if (hasAuthor) ...[
                      const SizedBox(height: 2),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: NyanTypography.uiFontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                          color: nyan.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: NyanSpacing.space8),
                    // Inline progress bar + percentage
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 3,
                              backgroundColor: Color.alphaBlend(
                                nyan.primary.withValues(alpha: 0.16),
                                nyan.surfaceMuted,
                              ),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(nyan.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: NyanSpacing.space8),
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontFamily: NyanTypography.uiFontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1,
                            color: nyan.primaryDeep,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: NyanSpacing.space12),
          // Full-width CTA
          NyanPrimaryButton(
            label: buttonLabel,
            onPressed: onContinue,
            icon: const Icon(NyanIcons.book, size: 17),
            expanded: true,
          ),
        ],
      ),
    );
  }
}
