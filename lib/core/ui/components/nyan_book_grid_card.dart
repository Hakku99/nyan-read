import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../theme/nyan_radius.dart';
import '../../theme/nyan_shadows.dart';
import '../../theme/nyan_shelf_ui.dart';
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

  /// Tapped when the ↗ affordance button is pressed in selection mode.
  /// Opens book details without affecting the selection state.
  final VoidCallback? onOpenDetails;

  const NyanBookGridCard({
    super.key,
    required this.book,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    this.onOpenDetails,
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
                    // Selected: 2px primary border + 3px spread glow.
                    // Unselected: 0.5px hairline.
                    border: isSelected
                        ? Border.all(color: nyan.primary, width: 2.0)
                        : Border.all(
                            color: nyan.divider.withValues(alpha: 0.30),
                            width: 0.5,
                          ),
                    boxShadow: isSelected
                        ? NyanShadows.cardSelectionGlow(nyan)
                        : null,
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
                      // Primary@12% tint overlay when selected.
                      if (isSelected)
                        Positioned.fill(
                          child: ColoredBox(
                            color: nyan.primary.withValues(alpha: 0.12),
                          ),
                        ),
                      // Format badge — visible in both normal and selection mode.
                      if (book.format.isNotEmpty)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: _FormatBadge(
                            format: book.format,
                            nyan: nyan,
                          ),
                        ),
                      // Selection badge — top-left per spec.
                      if (isSelectionMode)
                        Positioned(
                          top: 7,
                          left: 7,
                          child: NyanSelectionBadge(
                            isSelected: isSelected,
                            nyan: nyan,
                          ),
                        ),
                      // ↗ open-detail affordance — bottom-right per spec
                      // SelectBookCard. Navigates to book details independently
                      // of selection toggle. Only shown in selection mode.
                      if (isSelectionMode)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onOpenDetails,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: nyan.surface.withValues(alpha: 0.90),
                                border: Border.all(
                                  color: nyan.divider.withValues(alpha: 0.50),
                                  width: 0.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Icon(
                                NyanIcons.arrowUpRight,
                                size: 13,
                                color: nyan.primaryDeep,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // ── Progress bar — only when reading has started (spec: pct > 0)
              if (progress > 0) ...[
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
              ],

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

class NyanSelectionBadge extends StatelessWidget {
  const NyanSelectionBadge({
    super.key,
    required this.isSelected,
    required this.nyan,
    this.size = 24,
  });

  final bool isSelected;
  final NyanTheme nyan;

  /// Badge diameter — 24pt for grid, 20pt for list rows.
  final double size;

  @override
  Widget build(BuildContext context) {
    // Spec: `SelectCheck` — circle with backdrop blur (approximated via
    // frosted background), 1.5px border.
    // Selected: primary fill, primary border, primary@40% glow.
    // Unselected: surface@76% fill, textPrimary@30% border, small black shadow.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected
            ? nyan.primary
            : nyan.surface.withValues(alpha: 0.76),
        border: Border.all(
          color: isSelected
              ? nyan.primary
              : nyan.textPrimary.withValues(alpha: 0.30),
          width: 1.5,
        ),
        boxShadow: isSelected
            ? NyanShadows.selectionBadgeGlow(nyan)
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: isSelected
          ? Icon(
              NyanIcons.check,
              size: size * 0.54,
              color: Colors.white,
            )
          : null,
    );
  }
}
