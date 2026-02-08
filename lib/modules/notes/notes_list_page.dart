import 'package:flutter/material.dart';
import '../../core/models/highlight.dart';
import '../../core/services/database_service.dart';
import '../reader/widgets/highlight_note_dialog.dart';

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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notes & Highlights'),
            Text(
              widget.bookTitle,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          if (_highlights.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_highlights.length}',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _highlights.isEmpty
              ? _buildEmptyState()
              : _buildHighlightsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.highlight_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No highlights yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Long-press on text to create highlights',
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
        return _buildHighlightCard(highlight);
      },
    );
  }

  Widget _buildHighlightCard(Highlight highlight) {
    final theme = Theme.of(context);
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
                // Color indicator and text
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      child: Text(
                        highlight.selectedText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          backgroundColor: color.withOpacity(0.2),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                      'Paragraph ${highlight.paragraphIndex + 1}',
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
