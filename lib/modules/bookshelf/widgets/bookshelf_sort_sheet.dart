import 'package:flutter/material.dart';

import 'package:nyan_read/l10n/app_localizations.dart';

import '../../../core/services/bookshelf_preferences_service.dart';
import '../../../core/theme/nyan_radius.dart';
import '../../../core/theme/nyan_spacing.dart';
import '../../../core/theme/nyan_typography.dart';
import '../../../core/ui/components/nyan_one_paper_sheet.dart';
import '../../../core/ui/nyan_icons.dart';
import '../../../core/ui/nyan_sheet.dart';
import '../../../core/ui/nyan_theme_context.dart';
import '../../../core/ui/components/segmented_tab_control.dart';

/// Bookshelf sort sheet — direction tab above field rows per `bundle3.jsx`
/// `ShelfSortSheet`. Changes apply live via [onChanged] while the sheet stays
/// open.
Future<void> showBookshelfSortSheet({
  required BuildContext context,
  required SortBy currentSortBy,
  required bool currentAscending,
  required void Function(SortBy sortBy, bool isAscending) onChanged,
}) {
  return showNyanSheet(
    context: context,
    builder: (_) => _BookshelfSortSheet(
      initialSortBy: currentSortBy,
      initialAscending: currentAscending,
      onChanged: onChanged,
    ),
  );
}

class _BookshelfSortSheet extends StatefulWidget {
  const _BookshelfSortSheet({
    required this.initialSortBy,
    required this.initialAscending,
    required this.onChanged,
  });

  final SortBy initialSortBy;
  final bool initialAscending;
  final void Function(SortBy sortBy, bool isAscending) onChanged;

  @override
  State<_BookshelfSortSheet> createState() => _BookshelfSortSheetState();
}

class _BookshelfSortSheetState extends State<_BookshelfSortSheet> {
  late SortBy _sortBy = widget.initialSortBy;
  late bool _isAscending = widget.initialAscending;

  // Spec field order: Last read, Title, Added (bundle3.jsx SHELF_SORT_FIELDS).
  static const _fields = [SortBy.recency, SortBy.title, SortBy.importDate];

  void _setSortBy(SortBy key) {
    if (key == _sortBy) return;
    setState(() => _sortBy = key);
    widget.onChanged(_sortBy, _isAscending);
  }

  void _setAscending(bool ascending) {
    if (ascending == _isAscending) return;
    setState(() => _isAscending = ascending);
    widget.onChanged(_sortBy, _isAscending);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return NyanOnePaperSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title — spec: padding "12px 20px 4px", font "600 18px/1.2 -0.1px".
          // 18pt is the NyanOnePaperSheet title exception (AGENTS.md §4.2.5).
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NyanSpacing.space20,
              NyanSpacing.space12,
              NyanSpacing.space20,
              NyanSpacing.space4,
            ),
            child: _SheetTitle(label: loc.sortShelfBy),
          ),
          // Direction tab — spec: padding "8px 20px 6px".
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NyanSpacing.space20,
              NyanSpacing.space8,
              NyanSpacing.space20,
              NyanSpacing.space4 + 2, // 6pt
            ),
            child: SegmentedTabControl(
              style: SegmentedTabStyle.subtle,
              selectedIndex: _isAscending ? 0 : 1,
              onTabChanged: (i) => _setAscending(i == 0),
              tabs: [
                SegmentedTab(label: loc.sortOrderAsc),
                SegmentedTab(label: loc.sortOrderDesc),
              ],
            ),
          ),
          // Field rows — spec: padding "4px 12px 16px".
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NyanSpacing.space12,
              NyanSpacing.space4,
              NyanSpacing.space12,
              NyanSpacing.space16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _fields
                  .map(
                    (field) => _SortFieldRow(
                      field: field,
                      isSelected: _sortBy == field,
                      isAscending: _isAscending,
                      onTap: () => _setSortBy(field),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    return Text(
      label,
      style: TextStyle(
        fontFamily: NyanTypography.uiFontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.1,
        color: nyan.textPrimary,
      ),
    );
  }
}

/// Single sort-field row with label, sub-label, direction arrow, and radio.
///
/// Spec: `bundle3.jsx` `ShelfSortSheet` field button —
///   selected bg `primary 8%`, radius `r-card-nested` (16pt),
///   padding 12, minHeight 56, gap 12.
class _SortFieldRow extends StatelessWidget {
  const _SortFieldRow({
    required this.field,
    required this.isSelected,
    required this.isAscending,
    required this.onTap,
  });

  final SortBy field;
  final bool isSelected;
  final bool isAscending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final loc = AppLocalizations.of(context)!;

    final label = _label(field, loc);
    final subLabel = _subLabel(field, isAscending, loc);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: NyanSpacing.minTapTarget + 12),
        padding: const EdgeInsets.all(NyanSpacing.space12),
        decoration: BoxDecoration(
          color: isSelected
              ? nyan.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(NyanRadius.cardNested),
        ),
        child: Row(
          children: [
            // Label + sub-label column.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: NyanTypography.uiFontFamily,
                      fontSize: NyanTypography.shelfSortFieldLabel,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      height: 1.2,
                      color: isSelected
                          ? nyan.primaryDeep
                          : nyan.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: TextStyle(
                      fontFamily: NyanTypography.uiFontFamily,
                      fontSize: NyanTypography.shelfSortFieldSub,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                      color: nyan.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: NyanSpacing.space12),
            // Direction arrow — only on selected row; flipped for descending.
            if (isSelected) ...[
              Transform.scale(
                scaleY: isAscending ? 1.0 : -1.0,
                child: Icon(
                  NyanIcons.sortDirectionIndicator,
                  size: 15,
                  color: nyan.primary,
                ),
              ),
              const SizedBox(width: NyanSpacing.space12),
            ],
            // Radio circle — 22×22, 2px border.
            _RadioCircle(isSelected: isSelected),
          ],
        ),
      ),
    );
  }
}

/// 22×22 radio circle — filled when selected.
///
/// Spec: `border: "2px solid ${isSel ? primary : divider@80%}"`;
///       inner 11×11 filled circle when selected.
class _RadioCircle extends StatelessWidget {
  const _RadioCircle({required this.isSelected});

  final bool isSelected;

  static const double _outerSize = 22;
  static const double _innerSize = 11;
  static const double _borderWidth = 2;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final borderColor = isSelected
        ? nyan.primary
        : nyan.divider.withValues(alpha: 0.80);

    return SizedBox(
      width: _outerSize,
      height: _outerSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: _borderWidth),
        ),
        child: isSelected
            ? Center(
                child: SizedBox(
                  width: _innerSize,
                  height: _innerSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: nyan.primary,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

// ── Label helpers ────────────────────────────────────────────────────────────

String _label(SortBy field, AppLocalizations loc) => switch (field) {
      SortBy.recency => loc.lastRead,
      SortBy.title => loc.title,
      SortBy.importDate => loc.added,
    };

String _subLabel(SortBy field, bool ascending, AppLocalizations loc) =>
    switch (field) {
      SortBy.recency =>
        ascending ? loc.sortLastReadAscSub : loc.sortLastReadDescSub,
      SortBy.title =>
        ascending ? loc.sortTitleAscSub : loc.sortTitleDescSub,
      SortBy.importDate =>
        ascending ? loc.sortAddedAscSub : loc.sortAddedDescSub,
    };
