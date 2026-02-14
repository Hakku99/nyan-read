void _showSortMenu(BuildContext context) {
  final loc = AppLocalizations.of(context)!;

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Text(
                    loc.sortBy,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ...() {
                  // Define the 6 combined sort options
                  final sortOptions = [
                    (SortBy.recency, false, loc.lastReadDesc),
                    (SortBy.recency, true, loc.lastReadAsc),
                    (SortBy.importDate, false, loc.addedDesc),
                    (SortBy.importDate, true, loc.addedAsc),
                    (SortBy.title, true, loc.titleAsc),
                    (SortBy.title, false, loc.titleDesc),
                  ];

                  return sortOptions.map((option) {
                    final sortBy = option.$1;
                    final isAscending = option.$2;
                    final label = option.$3;
                    final isSelected = _prefs.sortBy == sortBy &&
                        _prefs.isAscending == isAscending;

                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 24),
                      title: Text(
                        label,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            )
                          : null,
                      onTap: () async {
                        await _prefs.setSort(sortBy, isAscending);
                        _refreshShelf();
                        setModalState(() {});
                        Navigator.pop(context);
                      },
                    );
                  }).toList();
                }(),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    },
  );
}
