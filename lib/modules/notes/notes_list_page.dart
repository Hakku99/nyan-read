import 'package:flutter/material.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../core/models/highlight.dart';
import '../../core/services/database_service.dart';
import '../../core/services/service_locator.dart';
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

  bool get _isZh =>
      Localizations.localeOf(context).languageCode.startsWith('zh');

  String _headerSubtitle() {
    if (_isZh) {
      return '\u300a${widget.bookTitle}\u300b';
    }
    return widget.bookTitle;
  }

  String _contextTitle() {
    if (_isZh) {
      return '\u7247\u6bb5\u4e0e\u6279\u6ce8';
    }
    return 'Reading notes';
  }

  String _contextDescription() {
    if (_isZh) {
      return '\u70b9\u5f00\u53ef\u56de\u5230\u539f\u6587\uff0c\u957f\u6309\u53ef\u7f16\u8f91\uff0c\u5de6\u6ed1\u53ef\u5220\u9664\u3002';
    }
    return 'Tap to return, long-press to edit, swipe left to delete.';
  }

  String _emptyStateTitle() {
    if (_isZh) {
      return '\u8fd8\u6ca1\u6709\u7559\u4e0b\u7247\u6bb5';
    }
    return 'No reading notes yet';
  }

  String _emptyStateDescription() {
    if (_isZh) {
      return '\u60f3\u56de\u770b\u7684\u53e5\u5b50\u4e0e\u6279\u6ce8\uff0c\u4f1a\u6536\u5728\u8fd9\u91cc\u3002';
    }
    return 'Lines worth returning to will gather here.';
  }

  String _emptyStateHint() {
    if (_isZh) {
      return '\u9605\u8bfb\u65f6\u957f\u6309\u6587\u5b57\u5373\u53ef\u521b\u5efa\u9ad8\u4eae';
    }
    return 'Long-press while reading to save a highlight or note.';
  }

  String _noteTagLabel() {
    if (_isZh) {
      return '\u6279\u6ce8';
    }
    return 'Note';
  }

  String _deleteActionLabel() {
    if (_isZh) {
      return '\u5220\u9664';
    }
    return 'Delete';
  }

  String _deleteFailedMessage(String error) {
    if (_isZh) {
      return '\u5220\u9664\u9ad8\u4eae\u5931\u8d25\uff1a$error';
    }
    return 'Failed to delete highlight: $error';
  }

  String _highlightLabel(int index) {
    if (_isZh) {
      return '\u9ad8\u4eae $index';
    }
    return 'Highlight $index';
  }

  String _paragraphLabel(int paragraphIndex) {
    if (_isZh) {
      return '\u6bb5\u843d ${paragraphIndex + 1}';
    }
    return 'Paragraph ${paragraphIndex + 1}';
  }

  String _formatDateLabel(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatSectionDate(String dateLabel) {
    if (dateLabel.isEmpty) {
      return _isZh ? '\u66f4\u65e9' : 'Earlier';
    }
    return dateLabel.replaceAll('-', '.');
  }

  Color _parseColor(String colorCode) {
    try {
      final hex = colorCode.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFFF2E58A);
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
        _deleteFailedMessage(e.toString()),
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
                subtitle: _headerSubtitle(),
                titleStyle: theme.textTheme.titleLarge?.copyWith(
                  fontSize: NyanTypography.section,
                  fontWeight: FontWeight.w600,
                ),
                subtitleStyle: theme.textTheme.bodySmall?.copyWith(
                  color: nyanTheme.textSecondary.withValues(alpha: 0.78),
                ),
                padding: const EdgeInsets.fromLTRB(
                  NyanSpacing.space16,
                  NyanSpacing.space12,
                  NyanSpacing.space16,
                  NyanSpacing.space8,
                ),
                leading: SizedBox(
                  width: NyanSpacing.minTapTarget,
                  height: NyanSpacing.minTapTarget,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
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
                alpha: isDark ? 0.09 : 0.05,
              ),
              nyanTheme.surface,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.dividerColor.withValues(
                alpha: isDark ? 0.1 : 0.09,
              ),
              width: 0.7,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.edit_note_rounded,
              size: NyanSpacing.space32 + NyanSpacing.space8,
              color: nyanTheme.primary.withValues(alpha: isDark ? 0.82 : 0.78),
            ),
          ),
        ),
        title: _emptyStateTitle(),
        titleStyle: theme.textTheme.titleMedium?.copyWith(
          fontSize: NyanTypography.section,
          fontWeight: FontWeight.w600,
          color: nyanTheme.textPrimary.withValues(alpha: isDark ? 0.88 : 0.84),
        ),
        description: _emptyStateDescription(),
        descriptionStyle: theme.textTheme.bodyMedium?.copyWith(
          height: 1.3,
          color: nyanTheme.textSecondary.withValues(
            alpha: isDark ? 0.84 : 0.74,
          ),
        ),
        iconSpacing: NyanSpacing.space16,
        descriptionSpacing: NyanSpacing.space12,
        actionSpacing: NyanSpacing.space12,
        action: Text(
          _emptyStateHint(),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: nyanTheme.textSecondary.withValues(
              alpha: isDark ? 0.74 : 0.62,
            ),
            height: 1.24,
          ),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        NyanSpacing.space16,
        0,
        NyanSpacing.space16,
        NyanSpacing.space24,
      ),
      children: [
        _buildContextPanel(),
        ..._buildGroupedHighlightItems(),
      ],
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
        borderRadius: BorderRadius.circular(NyanRadius.card),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: isDark ? 0.18 : 0.12),
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
                      nyanTheme.primary.withValues(alpha: 0.07),
                      nyanTheme.surfaceMuted,
                    ),
              borderRadius: BorderRadius.circular(NyanRadius.input),
            ),
            child: Icon(
              Icons.edit_note_rounded,
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
                  _contextTitle(),
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
                  _contextDescription(),
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
        width: 78,
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
                    _deleteActionLabel(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10.5,
                      color: nyanTheme.errorPrimaryTextColor.withValues(
                        alpha: isDark ? 0.8 : 0.58,
                      ),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.delete_outline_rounded,
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
    final meta = _paragraphLabel(highlight.paragraphIndex);

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
        label: _highlightLabel(index + 1),
        excerpt: excerpt,
        note: note,
        noteTagLabel: _noteTagLabel(),
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