import 'package:flutter/material.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../core/models/highlight.dart';
import '../../core/services/database_service.dart';
import '../../core/services/service_locator.dart';
import '../../core/theme/nyan_colors.dart';
import '../../core/theme/nyan_radius.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/theme/nyan_typography.dart';
import '../../core/ui/components/components.dart';
import '../../core/ui/nyan_theme_context.dart';
import '../../core/utils/snackbar_utils.dart';
import '../reader/widgets/highlight_note_dialog.dart';

/// Page to view all highlights and notes for a book
class NotesListPage extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final Function(int paragraphIndex)? onJumpToHighlight;

  const NotesListPage({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.onJumpToHighlight,
  });

  @override
  State<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends State<NotesListPage> {
  List<Highlight> _highlights = [];
  bool _isLoading = true;

  AppLocalizations get _loc => AppLocalizations.of(context)!;

  String _formatDateLabel(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatSectionDate(String dateLabel) {
    if (dateLabel.isEmpty) return _loc.timeEarlier;
    return dateLabel.replaceAll('-', '.');
  }

  Color _parseColor(String colorCode) {
    try {
      final hex = colorCode.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return NyanColors.highlightYellow;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadHighlights();
  }

  Future<void> _loadHighlights() async {
    setState(() => _isLoading = true);
    try {
      final data = await getIt<DatabaseService>().getHighlights(widget.bookId);
      if (!mounted) {
        return;
      }

      final highlights = data
          .map((m) => Highlight.fromMap(m))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _highlights = highlights;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteHighlight(Highlight highlight) async {
    final index = _highlights.indexWhere((item) => item.id == highlight.id);
    if (index == -1) {
      return;
    }

    final removedItem = _highlights[index];
    setState(() {
      _highlights.removeAt(index);
    });

    try {
      await getIt<DatabaseService>().deleteHighlight(highlight.id);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _highlights.insert(index, removedItem);
      });
      SnackBarUtils.show(
        context,
        _loc.failedToDeleteHighlight(e.toString()),
        tone: NyanSnackTone.error,
      );
    }
  }

  Future<void> _editNote(Highlight highlight) async {
    await showHighlightNoteDialog(
      context,
      highlight: highlight,
      onSave: (note, colorCode) async {
        await getIt<DatabaseService>()
            .updateHighlight(highlight.id, note: note, colorCode: colorCode);
        _loadHighlights();
      },
      onDelete: () => _deleteHighlight(highlight),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                nyanTheme.primary.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.08 : 0.05,
                ),
                nyanTheme.background,
              ),
              nyanTheme.background,
              nyanTheme.background,
            ],
            stops: const [0, 0.24, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              NyanPageHeader(
                title: loc.notesAndHighlightsTitle(_highlights.length),
                subtitle: _loc.notesBookSubtitle(widget.bookTitle),
                titleStyle: theme.textTheme.titleLarge?.copyWith(
                  fontSize: NyanTypography.section,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.15,
                ),
                subtitleStyle: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  height: 1.35,
                  color: nyanTheme.textMuted,
                ),
                padding: const EdgeInsets.fromLTRB(
                  NyanSpacing.space12,
                  NyanSpacing.space16,
                  NyanSpacing.space12,
                  NyanSpacing.space12,
                ),
                leading: SizedBox(
                  width: NyanSpacing.minTapTarget,
                  height: NyanSpacing.minTapTarget,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(NyanIcons.back),
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: nyanTheme.primary),
      );
    }

    if (_highlights.isEmpty) {
      final isDark = theme.brightness == Brightness.dark;
      final heroSize = NyanSpacing.space32 * 2 + NyanSpacing.space20;

      return NyanEmptyState(
        alignment: const Alignment(0, -0.24),
        padding: const EdgeInsets.fromLTRB(
          NyanSpacing.space24,
          NyanSpacing.space16,
          NyanSpacing.space24,
          NyanSpacing.space24,
        ),
        contentMaxWidth: NyanSpacing.space32 * 8,
        icon: Container(
          width: heroSize,
          height: heroSize,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              nyanTheme.primary.withValues(
                alpha: isDark ? 0.09 : 0.06,
              ),
              nyanTheme.surface,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: nyanTheme.divider.withValues(alpha: 0.18),
              width: 0.7,
            ),
          ),
          child: Center(
            child: Icon(
              NyanIcons.highlighterCircle,
              size: 36,
              color: nyanTheme.primary.withValues(alpha: 0.78),
            ),
          ),
        ),
        title: _loc.notesEmptyTitle,
        // Empty-state title uses 18pt — exception per design spec
        // (bundle3.jsx NotesList empty state: "600 18px/1.25").
        // Same exception pattern as Reader Error View and Sheet title.
        titleStyle: theme.textTheme.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.25,
          color: nyanTheme.textPrimary.withValues(alpha: isDark ? 0.88 : 0.84),
        ),
        description: _loc.notesEmptyDescription,
        descriptionStyle: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.4,
          color: nyanTheme.textSecondary.withValues(alpha: isDark ? 0.84 : 0.74),
        ),
        iconSpacing: 14,
        descriptionSpacing: NyanSpacing.space12 - 2, // ~10pt gap to hint
        actionSpacing: NyanSpacing.space12,
        action: Text(
          _loc.notesEmptyHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 13,
            color: nyanTheme.textSecondary.withValues(
              alpha: isDark ? 0.74 : 0.62,
            ),
            height: 1.38,
          ),
        ),
      );
    }

    // §3.4: list surfaces stay lazy — items are cheap widget descriptors,
    // but layout/paint of offscreen rows is what builder skips.
    final items = <Widget>[
      _buildContextPanel(),
      ..._buildGroupedHighlightItems(),
    ];
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        NyanSpacing.space16,
        0,
        NyanSpacing.space16,
        NyanSpacing.space24,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  List<Widget> _buildGroupedHighlightItems() {
    final items = <Widget>[];
    String? previousDate;

    for (int index = 0; index < _highlights.length; index++) {
      final highlight = _highlights[index];
      final dateLabel = _formatDateLabel(highlight.createdAt);
      if (dateLabel != previousDate) {
        if (items.isNotEmpty) {
          items.add(const SizedBox(height: NyanSpacing.space12));
        }
        items.add(_buildDateHeader(_formatSectionDate(dateLabel)));
        items.add(const SizedBox(height: NyanSpacing.space4));
        previousDate = dateLabel;
      }

      items.add(_buildHighlightCard(highlight, index));
      items.add(const SizedBox(height: NyanSpacing.space8));
    }

    if (items.isNotEmpty) {
      items.removeLast();
    }

    return items;
  }

  Widget _buildContextPanel() {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final isDark = theme.brightness == Brightness.dark;

    final panelSurface = isDark
        ? Color.alphaBlend(
            nyanTheme.surface.withValues(alpha: 0.78),
            nyanTheme.background,
          )
        : Color.alphaBlend(
            nyanTheme.primary.withValues(alpha: 0.035),
            nyanTheme.surface,
          );

    return Container(
      margin: const EdgeInsets.only(bottom: NyanSpacing.space8),
      padding: const EdgeInsets.symmetric(
        horizontal: NyanSpacing.space12,
        vertical: NyanSpacing.space12,
      ),
      decoration: BoxDecoration(
        color: panelSurface,
        borderRadius: BorderRadius.circular(NyanRadius.cardNested),
        border: Border.all(
          color: nyanTheme.divider.withValues(alpha: isDark ? 0.18 : 0.16),
          width: 0.6,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark
                  ? Color.alphaBlend(
                      nyanTheme.primary.withValues(alpha: 0.1),
                      nyanTheme.surfaceMuted.withValues(alpha: 0.9),
                    )
                  : Color.alphaBlend(
                      nyanTheme.primary.withValues(alpha: 0.08),
                      nyanTheme.surfaceMuted,
                    ),
              borderRadius: BorderRadius.circular(NyanRadius.chip),
            ),
            child: Icon(
              NyanIcons.editNote,
              size: 15,
              color: nyanTheme.primary.withValues(alpha: isDark ? 0.88 : 0.84),
            ),
          ),
          const SizedBox(width: NyanSpacing.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _loc.notesContextTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    height: 1.08,
                    color: nyanTheme.textPrimary.withValues(
                      alpha: isDark ? 0.92 : 0.82,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _loc.notesContextDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12.5,
                    color: nyanTheme.textSecondary.withValues(
                      alpha: isDark ? 0.8 : 0.68,
                    ),
                    height: 1.24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String label) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NyanSpacing.space4),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontSize: 10.5,
          letterSpacing: 0.9,
          color: nyanTheme.textSecondary.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.72 : 0.56,
          ),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDeleteRevealBackground() {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final isDark = theme.brightness == Brightness.dark;
    final railBase = isDark
        ? Color.alphaBlend(
            nyanTheme.surface.withValues(alpha: 0.76),
            nyanTheme.background,
          )
        : Color.alphaBlend(
            nyanTheme.errorBackgroundColor.withValues(alpha: 0.46),
            nyanTheme.surface,
          );
    final railTint = isDark
        ? Color.alphaBlend(
            nyanTheme.errorAccentColor.withValues(alpha: 0.045),
            railBase,
          )
        : Color.alphaBlend(
            nyanTheme.errorAccentColor.withValues(alpha: 0.06),
            nyanTheme.background,
          );
    final railBorder = nyanTheme.errorAccentColor.withValues(
      alpha: isDark ? 0.2 : 0.1,
    );

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 104,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NyanRadius.card),
            border: Border.all(color: railBorder, width: 0.5),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                railTint.withValues(alpha: 0.08),
                railTint.withValues(alpha: 0.16),
                railBase,
              ],
              stops: const [0.0, 0.62, 1.0],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _loc.delete,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 12,
                      color: nyanTheme.errorPrimaryTextColor.withValues(
                        alpha: isDark ? 0.8 : 0.62,
                      ),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    NyanIcons.delete,
                    size: 20,
                    color: nyanTheme.errorPrimaryTextColor.withValues(
                      alpha: isDark ? 0.92 : 0.72,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightCard(Highlight highlight, int index) {
    final note = highlight.note?.trim();
    final excerpt = highlight.selectedText.trim();
    final meta = _loc.paragraphIndex(highlight.paragraphIndex + 1);

    return Dismissible(
      key: Key(highlight.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.34,
      },
      movementDuration: const Duration(milliseconds: 220),
      resizeDuration: const Duration(milliseconds: 180),
      background: _buildDeleteRevealBackground(),
      secondaryBackground: _buildDeleteRevealBackground(),
      onDismissed: (_) => _deleteHighlight(highlight),
      child: NyanHighlightCard(
        label: _loc.highlightName(index + 1),
        excerpt: excerpt,
        note: note,
        noteTagLabel: _loc.noteTagLabel,
        meta: meta,
        highlightColor: _parseColor(highlight.colorCode),
        onTap: widget.onJumpToHighlight == null
            ? null
            : () => Navigator.pop(context, highlight),
        onLongPress: () => _editNote(highlight),
      ),
    );
  }
}