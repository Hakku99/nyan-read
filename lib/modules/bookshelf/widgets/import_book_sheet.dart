import 'package:flutter/material.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../../core/theme/nyan_radius.dart';
import '../../../core/theme/nyan_spacing.dart';
import '../../../core/theme/nyan_typography.dart';
import '../../../core/ui/components/components.dart';
import '../../../core/ui/nyan_theme_context.dart';

class ImportBookSheet extends StatelessWidget {
  final bool isEmptyShelf;
  final String shelfLabel;
  final VoidCallback onImportFiles;

  const ImportBookSheet({
    super.key,
    required this.isEmptyShelf,
    required this.shelfLabel,
    required this.onImportFiles,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final nyan = context.nyanTheme;

    return NyanOnePaperSheet(
      child: Padding(
        // spec: padding "12px 20px 24px" inside the floating shell
        padding: const EdgeInsets.fromLTRB(
          NyanSpacing.space20,
          NyanSpacing.space12,
          NyanSpacing.space20,
          NyanSpacing.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title — spec: "600 18px/1.2", letterSpacing -0.1px.
            // 18pt is a spec-mandated exception to the 6-step font scale
            // (§4.6 handoff package priority; see AGENTS.md §4.2.5 exception).
            Text(
              loc.importBooksTitle,
              style: TextStyle(
                fontFamily: NyanTypography.uiFontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.2,
                letterSpacing: -0.1,
                color: nyan.textPrimary,
              ),
            ),
            // Description — spec: marginBottom 4 inside the title block → space4.
            const SizedBox(height: NyanSpacing.space4),
            Text(
              isEmptyShelf
                  ? loc.importBooksEmptySubtitle
                  : loc.importBooksSubtitle,
              style: TextStyle(
                fontFamily: NyanTypography.uiFontFamily,
                fontSize: NyanTypography.meta,
                fontWeight: FontWeight.w400,
                height: 1.38,
                color: nyan.textSecondary,
              ),
            ),
            // spec: gap 14pt between the title block, badge, and card.
            const SizedBox(height: 14),
            _ShelfBadge(label: shelfLabel),
            const SizedBox(height: 14),
            // Card — grouped variant: 16pt radius, settingsGrouped shadow,
            // 0.72px border @ 16% (matches RowGroup in _chrome.jsx).
            NyanInfoCard(
              variant: NyanInfoCardVariant.grouped,
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NyanListRow(
                    leadingIcon: NyanIcons.file,
                    title: loc.importFiles,
                    subtitle: loc.importFilesSubtitle,
                    showChevron: true,
                    onTap: onImportFiles,
                  ),
                  // spec: height 0.5px, divider @ 34%, margin 0 16px.
                  Container(
                    height: 0.5,
                    margin: const EdgeInsets.symmetric(
                      horizontal: NyanSpacing.space16,
                    ),
                    color: nyan.divider.withValues(alpha: 0.34),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      NyanSpacing.space16,
                      NyanSpacing.space12,
                      NyanSpacing.space16,
                      NyanSpacing.space16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // spec (bundle3.jsx line 289): ph-book — plain closed book.
                        const _SheetLeadingIcon(icon: NyanIcons.bookClosed),
                        const SizedBox(width: NyanSpacing.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // spec: "500 15px/1.2" — exception between meta(13)
                              // and body(16); §4.6 handoff package takes priority.
                              Text(
                                loc.supportedFormats,
                                style: TextStyle(
                                  fontFamily: NyanTypography.uiFontFamily,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                  color: nyan.textPrimary,
                                ),
                              ),
                              const SizedBox(height: NyanSpacing.space4),
                              Text(
                                loc.supportedFormatsSubtitle,
                                style: TextStyle(
                                  fontFamily: NyanTypography.uiFontFamily,
                                  fontSize: NyanTypography.meta,
                                  fontWeight: FontWeight.w400,
                                  height: 1.3,
                                  color: nyan.textSecondary,
                                ),
                              ),
                              const SizedBox(height: NyanSpacing.space12),
                              const Wrap(
                                spacing: NyanSpacing.space8,
                                runSpacing: NyanSpacing.space8,
                                children: [
                                  _FormatChip(label: 'TXT'),
                                  _FormatChip(label: 'EPUB'),
                                  _FormatChip(label: 'PDF'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shelf badge ──────────────────────────────────────────────────────────────

class _ShelfBadge extends StatelessWidget {
  final String label;

  const _ShelfBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    // spec: height 34, padding "0 12px", borderRadius 12 (r-chip), primary 8%.
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: NyanSpacing.space12),
      decoration: BoxDecoration(
        color: nyan.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(NyanRadius.chip),
        border: Border.all(
          color: nyan.divider.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // spec (bundle3.jsx line 280): ph-books — stacked-books shelf icon.
          Icon(NyanIcons.books, size: 15, color: nyan.primary),
          const SizedBox(width: NyanSpacing.space8),
          Text(
            label,
            style: TextStyle(
              fontFamily: NyanTypography.uiFontFamily,
              fontSize: NyanTypography.meta,
              fontWeight: FontWeight.w600,
              height: 1.0,
              color: nyan.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Leading icon container (Supported Formats section) ───────────────────────

class _SheetLeadingIcon extends StatelessWidget {
  final IconData icon;

  const _SheetLeadingIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    // spec: width/height 44, borderRadius 12 (r-chip — not cardNested 16),
    // background: color-mix(primary 10%, surfaceMuted) — primary tints the
    // recessed surface rather than floating on a transparent base.
    final bg = Color.alphaBlend(
      nyan.primary.withValues(alpha: 0.10),
      nyan.surfaceMuted,
    );

    return Container(
      width: NyanSpacing.minTapTarget,
      height: NyanSpacing.minTapTarget,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(NyanRadius.chip),
      ),
      child: Icon(icon, size: NyanSpacing.space20, color: nyan.primary),
    );
  }
}

// ── Format chip (TXT / EPUB / PDF) ───────────────────────────────────────────

class _FormatChip extends StatelessWidget {
  final String label;

  const _FormatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    // spec: height 30, padding "0 12px", borderRadius 12, same surfaceMuted
    // blend as the leading icon.
    final bg = Color.alphaBlend(
      nyan.primary.withValues(alpha: 0.10),
      nyan.surfaceMuted,
    );

    // Container must NOT use alignment — it would expand to fill Wrap's
    // max-width constraint, making each chip full-width. Row with
    // mainAxisSize.min keeps the container intrinsically sized to content.
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: NyanSpacing.space12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(NyanRadius.chip),
        border: Border.all(
          color: nyan.divider.withValues(alpha: 0.50),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: NyanTypography.uiFontFamily,
              fontSize: NyanTypography.meta,
              fontWeight: FontWeight.w600,
              height: 1.0,
              color: nyan.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Import progress dialog ────────────────────────────────────────────────────

class ImportProgressDialog extends StatelessWidget {
  const ImportProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return NyanProgressDialog(
      title: loc.importingBooksTitle,
      description: loc.importingBooksSubtitle,
    );
  }
}
