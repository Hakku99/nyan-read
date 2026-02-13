import 'package:flutter/material.dart';
import '../../core/models/highlight.dart';
import '../../core/services/database_service.dart';
import '../reader/widgets/highlight_note_dialog.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

/// Page to view all highlights and notes for a book
class NotesListPage extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final Function(int paragraphIndex)? onJumpToHighlight;

  const NotesListPage({
    Key? key,
    required this.bookId,
    required this.bookTitle,
    this.onJumpToHighlight,
  }) : super(key: key);

  @override
  State<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends State<NotesListPage> {
  List<Highlight> _highlights = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHighlights();
  }

  Future<void> _loadHighlights() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseService().getHighlights(widget.bookId);
      setState(() {
        _highlights = data.map((m) => Highlight.fromMap(m)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Color _parseColor(String colorCode) {
    try {
      final hex = colorCode.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.yellow;
    }
  }

  Future<void> _deleteHighlight(Highlight highlight) async {
    await DatabaseService().deleteHighlight(highlight.id);
    _loadHighlights();
  }

  Future<void> _editNote(Highlight highlight) async {
    await showHighlightNoteDialog(
      context,
      highlight: highlight,
      onSave: (note, colorCode) async {
        await DatabaseService()
            .updateHighlight(highlight.id, note: note, colorCode: colorCode);
        _loadHighlights();
      },
      onDelete: () => _deleteHighlight(highlight),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.notesAndHighlightsTitle(_highlights.length)),
            Text(
              widget.bookTitle,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        // Removed actions as count is now in title
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _highlights.isEmpty
                ? _buildEmptyState()
                : _buildHighlightsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.highlight_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            loc.noHighlightsYet,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            loc.longPressToCreateHighlight,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightsList() {
    // Group by color
    final groupedByColor = <String, List<Highlight>>{};
    for (final highlight in _highlights) {
      groupedByColor.putIfAbsent(highlight.colorCode, () => []);
      groupedByColor[highlight.colorCode]!.add(highlight);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _highlights.length,
      itemBuilder: (context, index) {
        final highlight = _highlights[index];
        return _buildHighlightCard(highlight, index);
      },
    );
  }

  Widget _buildHighlightCard(Highlight highlight, int index) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final color = _parseColor(highlight.colorCode);

    return Dismissible(
      key: Key(highlight.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteHighlight(highlight),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: InkWell(
          onTap: () {
            if (widget.onJumpToHighlight != null) {
              Navigator.pop(context, highlight);
            }
          },
          onLongPress: () => _editNote(highlight),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Index and Delete Button
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.highlightName(index + 1),
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            highlight.selectedText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              backgroundColor: Colors.transparent,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: Colors.grey[500],
                      onPressed: () => _deleteHighlight(highlight),
                    ),
                  ],
                ),

                // Note if present
                if (highlight.note != null && highlight.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            highlight.note!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Metadata
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      loc.paragraphIndex(highlight.paragraphIndex + 1),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    Text(
                      _formatDate(highlight.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
