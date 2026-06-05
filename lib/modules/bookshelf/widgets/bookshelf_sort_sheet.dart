import 'package:flutter/material.dart';

import 'package:nyan_read/l10n/app_localizations.dart';

import '../../../core/services/bookshelf_preferences_service.dart';
import '../../../core/theme/nyan_spacing.dart';
import '../../../core/ui/components/nyan_bottom_sheet.dart';
import '../../../core/ui/components/nyan_pill_button.dart';
import '../../../core/ui/components/nyan_sheet_appearance.dart';
import 'segmented_tab_control.dart';

/// Bookshelf sort sheet — two independent axes per `BookshelfScreen.jsx`:
/// a row of key chips (Last Read / Added / Title) and an Ascending/Descending
/// [SegmentedTabControl]. Changes apply **live** through [onChanged] while the
/// sheet stays open (the user dismisses it), matching the design's `setT`
/// behaviour rather than the old pop-on-select rows.
Future<void> showBookshelfSortSheet({
  required BuildContext context,
  required SortBy currentSortBy,
  required bool currentAscending,
  required void Function(SortBy sortBy, bool isAscending) onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
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

  // Key chips read left→right in the same order as the design.
  static const _keys = [SortBy.recency, SortBy.importDate, SortBy.title];

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
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    final keyLabels = <SortBy, String>{
      SortBy.recency: loc.lastRead,
      SortBy.importDate: loc.added,
      SortBy.title: loc.title,
    };

    return NyanBottomSheet(
      title: loc.sortBy,
      titleStyle: NyanSheetAppearance.compactTitleStyle(theme),
      handleColor: NyanSheetAppearance.compactHandleColor(theme),
      contentPadding: EdgeInsets.only(
        left: NyanSheetAppearance.compactHorizontalPadding,
        right: NyanSheetAppearance.compactHorizontalPadding,
        top: NyanSpacing.space12,
        bottom: NyanSpacing.space8 + MediaQuery.of(context).padding.bottom,
      ),
      titleTopSpacing: NyanSpacing.space8,
      titleChildSpacing: NyanSpacing.space20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < _keys.length; i++) ...[
                if (i > 0) const SizedBox(width: NyanSpacing.space8),
                Expanded(
                  child: NyanPillButton(
                    label: keyLabels[_keys[i]]!,
                    selected: _sortBy == _keys[i],
                    onPressed: () => _setSortBy(_keys[i]),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: NyanSpacing.space12),
          SegmentedTabControl(
            style: SegmentedTabStyle.subtle,
            selectedIndex: _isAscending ? 0 : 1,
            onTabChanged: (i) => _setAscending(i == 0),
            tabs: [
              SegmentedTab(label: loc.sortOrderAsc),
              SegmentedTab(label: loc.sortOrderDesc),
            ],
          ),
        ],
      ),
    );
  }
}
