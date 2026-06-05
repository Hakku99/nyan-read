import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../theme/nyan_radius.dart';
import '../../theme/nyan_shelf_ui.dart';
import '../../theme/nyan_spacing.dart';
import '../../theme/nyan_typography.dart';
import '../nyan_icons.dart';
import '../nyan_theme_context.dart';
import '../../theme/theme_presets.dart';

/// Grid book card — cover-and-text layout per bundle3.jsx BookCard.
///
/// Structure (Column, gap 6):
///   Cover thumbnail (AspectRatio 120:156, NyanRadius.chip = 12pt)
///     └── Format badge overlay (top-right)
///   Progress bar (3px, always shown)
///   Title (12.5px / w600 / 2-line reserve)
///   Author (11px / w400)
class NyanBookGridCard extends StatelessWidget {
  final Book book;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const NyanBookGridCard({
    super.key,
    required this.book,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final progress = book.currentProgress.clamp(0.0, 1.0);
    final hasAuthor = book.author.trim().isNotEmpty &&
        book.author.trim().toLowerCase() != 'unknown';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Cover ────────────────────────────────────────────────────
              AspectRatio(
                aspectRatio: NyanShelfUi.gridCoverAspectRatio,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(NyanRadius.chip), // 12pt
                    color: Color.alphaBlend(
                      nyan.primary.withValues(alpha: 0.12),
                      nyan.surface,
                    ),
                    border: Border.all(
                      color: nyan.divider.withValues(alpha: 0.30),
                      width: 0.5,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          NyanIcons.book,
                          size: 26,
                          color: nyan.primary,
                        ),
                      ),
                      // Selection badge
                      if (isSelectionMode)
                        Positioned(
                          top: NyanSpacing.space8,
                          right: NyanSpacing.space8,
                          child: _SelectionBadge(
                            isSelected: isSelected,
                            nyan: nyan,
                          ),
                        ),
                      // Format badge
                      if (!isSelectionMode && book.format.isNotEmpty)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: _FormatBadge(
                            format: book.format,
                            nyan: nyan,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // ── Progress bar ─────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: NyanShelfUi.progressBarHeight, // 3pt
                  backgroundColor: Color.alphaBlend(
                    nyan.primary.withValues(alpha: 0.16),
                    nyan.surface,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(nyan.primary),
                ),
              ),
              const SizedBox(height: 6),

              // ── Title ────────────────────────────────────────────────────
              // Reserve 2-line height so all cards in a row share the same rhythm.
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: NyanShelfUi.gridCardTitleMinHeight, // 32pt
                ),
                child: Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: nyan.textPrimary,
                  ),
                ),
              ),

              // ── Author ───────────────────────────────────────────────────
              if (hasAuthor) ...[
                const SizedBox(height: 2),
                Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                    color: nyan.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FormatBadge extends StatelessWidget {
  const _FormatBadge({required this.format, required this.nyan});

  final String format;
  final NyanTheme nyan;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: nyan.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: nyan.divider.withValues(alpha: 0.44),
          width: 0.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        format.toUpperCase(),
        style: TextStyle(
          fontFamily: NyanTypography.uiFontFamily,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          height: 1,
          color: nyan.primaryDeep,
        ),
      ),
    );
  }
}

class _SelectionBadge extends StatelessWidget {
  const _SelectionBadge({required this.isSelected, required this.nyan});

  final bool isSelected;
  final NyanTheme nyan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? nyan.primary
            : nyan.textSecondary.withValues(alpha: 0.45),
        border: Border.all(color: nyan.surface, width: 2),
      ),
      child: isSelected
          ? Icon(NyanIcons.check, size: NyanSpacing.space16, color: nyan.surface)
          : null,
    );
  }
}
