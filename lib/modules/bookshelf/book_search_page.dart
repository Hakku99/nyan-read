import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/book.dart';
import '../../core/services/bookshelf_preferences_service.dart';
import '../../core/services/riverpod_providers.dart';
import '../../core/theme/nyan_radius.dart';
import '../../core/theme/nyan_shadows.dart';
import '../../core/theme/theme_presets.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/theme/nyan_typography.dart';
import 'widgets/animated_book_card.dart';
import '../../core/ui/components/nyan_book_grid_card.dart';
import '../../core/ui/nyan_icons.dart';
import '../../core/ui/nyan_theme_context.dart';
import '../../l10n/app_localizations.dart';
import 'bookshelf_view_model_provider.dart';

// ponytail: search is pure in-memory filter; no new DB query or provider.

// ── Shared shelf helpers (mirrored from home_screen private methods) ──────────

BoxDecoration _listGroupDecoration(NyanTheme nyan, bool isDark) => BoxDecoration(
      color: nyan.surface,
      borderRadius: BorderRadius.circular(NyanRadius.cardNested),
      border: Border.all(
        color: isDark ? nyan.divider : Colors.transparent,
        width: 1,
      ),
      boxShadow: NyanShadows.settingsGrouped(nyan),
    );

SliverGridDelegateWithFixedCrossAxisCount _bookshelfGridDelegate(
  BuildContext context,
) {
  const double crossAxisSpacing = 12;
  const double gridSideInset = NyanSpacing.space16;
  final double screenWidth = MediaQuery.sizeOf(context).width;
  final double cardWidth = (screenWidth - 2 * gridSideInset - 2 * crossAxisSpacing) / 3;
  // Cover ratio 120:156, text section 64pt — same constants as home_screen.
  const double coverAspect = 120.0 / 156.0;
  const double textSectionHeight = 64.0;
  final double coverHeight = cardWidth / coverAspect;
  final double cardHeight = coverHeight + textSectionHeight;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    childAspectRatio: cardWidth / cardHeight,
    crossAxisSpacing: crossAxisSpacing,
    mainAxisSpacing: 16,
  );
}

/// Height of the search-bar row (back button 40 + top 14 + bottom 12).
const double _kBarHeight = 66.0;

class BookSearchPage extends ConsumerStatefulWidget {
  const BookSearchPage({super.key, required this.isPrivate});

  /// Which shelf the user was on — searches that shelf's books.
  final bool isPrivate;

  @override
  ConsumerState<BookSearchPage> createState() => _BookSearchPageState();
}

class _BookSearchPageState extends ConsumerState<BookSearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  // Local view toggle: default to the shelf's current viewMode.
  late ViewMode _resultView;
  // Live query driven by controller; no debounce (in-memory list).
  String _query = '';

  @override
  void initState() {
    super.initState();
    _resultView = ref.read(bookshelfPreferencesRpProvider).viewMode;
    _controller.addListener(() {
      final q = _controller.text;
      if (q != _query) setState(() => _query = q);
    });
    // Auto-focus so the keyboard appears immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<Book> _filteredBooks() {
    final vm = ref.read(bookshelfViewModelRpProvider);
    final books = widget.isPrivate ? vm.privateBooks : vm.publicBooks;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return books
        .where((b) =>
            b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q))
        .toList(growable: false);
  }

  Future<void> _submitSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    await ref.read(bookshelfPreferencesRpProvider).addRecentSearch(trimmed);
    setState(() {}); // Refresh recent list if user clears field after submit.
  }

  void _fillRecent(String term) {
    _controller.value = TextEditingValue(
      text: term,
      selection: TextSelection.collapsed(offset: term.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final loc = AppLocalizations.of(context)!;
    final isDark = nyan.brightness == Brightness.dark;
    final results = _filteredBooks();
    final hasQuery = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar row ──────────────────────────────────────────────
            SizedBox(
              height: _kBarHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                child: Row(
                  children: [
                    // Back arrow button — 40×40, r-control
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(NyanRadius.control),
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(NyanRadius.control),
                          onTap: () => Navigator.of(context).pop(),
                          child: Icon(
                            NyanIcons.arrowLeft,
                            size: 21,
                            color: nyan.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Search field — flex, 44h, r-control per spec SearchField
                    Expanded(child: _SearchField(
                      controller: _controller,
                      focusNode: _focusNode,
                      hint: loc.searchHint,
                      onSubmitted: _submitSearch,
                    )),
                  ],
                ),
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child: hasQuery && results.isEmpty
                  // No-match: vertically centered per spec (height:100%, justifyContent:center)
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: NyanSpacing.space16),
                      child: Center(child: _buildNoMatch(context, loc, nyan)),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                          NyanSpacing.space16, 4, NyanSpacing.space16, 28),
                      child: !hasQuery
                          ? _buildIdleState(context, loc, nyan, isDark)
                          : _buildResults(context, loc, nyan, isDark, results),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Idle state: recent searches ─────────────────────────────────────────────

  Widget _buildIdleState(
    BuildContext context,
    AppLocalizations loc,
    NyanTheme nyan,
    bool isDark,
  ) {
    final prefs = ref.read(bookshelfPreferencesRpProvider);
    final recents = prefs.recentSearches;
    if (recents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: "RECENT" eyebrow + "Clear" link
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.searchRecent.toUpperCase(),
                style: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  fontSize: NyanTypography.caption, // 11pt
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.22,
                  color: nyan.primaryDeep,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await ref
                      .read(bookshelfPreferencesRpProvider)
                      .clearRecentSearches();
                  setState(() {});
                },
                child: Text(
                  loc.searchClear,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: nyan.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Recent rows
        Column(
          mainAxisSize: MainAxisSize.min,
          children: recents
              .map((term) => _RecentRow(
                    term: term,
                    nyan: nyan,
                    onTap: () => _fillRecent(term),
                  ))
              .toList(growable: false),
        ),
      ],
    );
  }

  // ── Results ─────────────────────────────────────────────────────────────────

  Widget _buildResults(
    BuildContext context,
    AppLocalizations loc,
    NyanTheme nyan,
    bool isDark,
    List<Book> results,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Result count + view toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  loc.searchResultCount(results.length, _query.trim()),
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: nyan.textMuted,
                  ),
                ),
              ),
              _ViewToggle(
                isGrid: _resultView == ViewMode.grid,
                nyan: nyan,
                onToggle: (isGrid) =>
                    setState(() => _resultView = isGrid ? ViewMode.grid : ViewMode.list),
              ),
            ],
          ),
        ),

        // Book list or grid
        if (_resultView == ViewMode.list)
          _buildListResults(context, nyan, isDark, results)
        else
          _buildGridResults(context, results),
      ],
    );
  }

  Widget _buildListResults(
    BuildContext context,
    NyanTheme nyan,
    bool isDark,
    List<Book> results,
  ) {
    final decoration = _listGroupDecoration(nyan, isDark);
    final last = results.length - 1;
    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NyanRadius.cardNested),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(results.length, (i) {
            final book = results[i];
            return AnimatedBookCardList(
              book: book,
              bookData: book.toMap(),
              isSelected: false,
              isSelectionMode: false,
              showTopDivider: i > 0,
              isFirst: i == 0,
              isLast: i == last,
              onTap: () => context.push('/reader/${book.id}'),
              onLongPress: () {},
            );
          }),
        ),
      ),
    );
  }

  Widget _buildGridResults(BuildContext context, List<Book> results) {
    final delegate = _bookshelfGridDelegate(context);
    // GridView.count is fine here — result set is small and already filtered.
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: delegate,
      itemCount: results.length,
      itemBuilder: (context, i) {
        final book = results[i];
        return NyanBookGridCard(
          book: book,
          isSelected: false,
          isSelectionMode: false,
          onTap: () => context.push('/reader/${book.id}'),
          onLongPress: () {},
        );
      },
    );
  }

  // ── No-match ────────────────────────────────────────────────────────────────

  Widget _buildNoMatch(
      BuildContext context, AppLocalizations loc, NyanTheme nyan) {
    // 80×80 circle icon per spec
    final iconContainer = Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(nyan.surface, nyan.primary, 0.06),
        border: Border.all(
          color: nyan.divider.withValues(alpha: 0.18),
          width: 0.7,
        ),
      ),
      child: Icon(
        NyanIcons.search,
        size: 32,
        color: nyan.primary.withValues(alpha: 0.70),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 40), // optical centre shift per spec
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconContainer,
          const SizedBox(height: 14),
          Text(
            loc.searchNoMatchTitle(_query.trim()),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: NyanTypography.uiFontFamily,
              // Off-ladder 17pt: spec no-match title, §4.6.
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: nyan.textPrimary.withValues(alpha: 0.84),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            loc.searchNoMatchSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: NyanTypography.uiFontFamily,
              fontSize: NyanTypography.body, // 14pt
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: nyan.textSecondary.withValues(alpha: 0.74),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search field ──────────────────────────────────────────────────────────────

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onSubmitted;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final hasText = widget.controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: 44,
      decoration: BoxDecoration(
        color: nyan.surface,
        borderRadius: BorderRadius.circular(NyanRadius.control),
        border: Border.all(
          color: _focused
              ? nyan.primary
              : nyan.divider.withValues(alpha: 0.50),
          width: 1.5,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: nyan.primary.withValues(alpha: 0.12),
                  blurRadius: 0,
                  spreadRadius: 3,
                ),
              ]
            : const [],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            NyanIcons.search,
            size: 18,
            color: hasText ? nyan.primary : nyan.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              style: TextStyle(
                fontFamily: NyanTypography.uiFontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.0,
                color: nyan.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.0,
                  color: nyan.textMuted,
                ),
                // All border variants must be none — focusedBorder overrides border
                // when focused and defaults to the theme primary outline otherwise.
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: widget.onSubmitted,
            ),
          ),
          if (hasText) ...[
            GestureDetector(
              onTap: () => widget.controller.clear(),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: nyan.textPrimary.withValues(alpha: 0.12),
                ),
                child: Icon(
                  NyanIcons.close,
                  size: 12,
                  color: nyan.surface,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ] else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}

// ── Recent row ────────────────────────────────────────────────────────────────

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.term,
    required this.nyan,
    required this.onTap,
  });

  final String term;
  final NyanTheme nyan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        // Spec: minHeight 44pt, padding 11px vertical
        height: 44,
        child: Row(
          children: [
            const SizedBox(width: 6),
            Icon(NyanIcons.clockCounterClockwise, size: 18, color: nyan.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                term,
                style: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                  color: nyan.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(NyanIcons.arrowUpLeft, size: 16, color: nyan.textMuted),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

// ── View toggle (list / grid) ─────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.isGrid,
    required this.nyan,
    required this.onToggle,
  });

  final bool isGrid;
  final NyanTheme nyan;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: nyan.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            icon: NyanIcons.viewRows,
            selected: !isGrid,
            nyan: nyan,
            onTap: () => onToggle(false),
          ),
          _ToggleButton(
            icon: NyanIcons.viewGrid,
            selected: isGrid,
            nyan: nyan,
            onTap: () => onToggle(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    required this.selected,
    required this.nyan,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final NyanTheme nyan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: const Cubic(0.33, 0.9, 0.36, 1), // ease-paper per spec
        width: 30,
        height: 26,
        decoration: BoxDecoration(
          color: selected ? nyan.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected ? NyanShadows.subtle(nyan) : const [],
        ),
        child: Icon(
          icon,
          size: 15,
          color: selected ? nyan.primaryDeep : nyan.textMuted,
        ),
      ),
    );
  }
}
