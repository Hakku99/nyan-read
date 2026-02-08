import 'package:flutter/material.dart';
import '../../../core/models/highlight.dart';

/// Dialog for adding or editing a note on a highlight
class HighlightNoteDialog extends StatefulWidget {
  final Highlight? highlight;
  final String? initialNote;
  final Function(String? note, String? colorCode) onSave;
  final VoidCallback? onDelete;

  const HighlightNoteDialog({
    Key? key,
    this.highlight,
    this.initialNote,
    required this.onSave,
    this.onDelete,
  }) : super(key: key);

  @override
  State<HighlightNoteDialog> createState() => _HighlightNoteDialogState();
}

class _HighlightNoteDialogState extends State<HighlightNoteDialog> {
  late TextEditingController _controller;
  String? _selectedColorCode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialNote ?? widget.highlight?.note ?? '',
    );
    _selectedColorCode = widget.highlight?.colorCode ?? HighlightColors.yellow;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _parseColor(String? colorCode) {
    if (colorCode == null) return Colors.yellow;
    try {
      final hex = colorCode.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.yellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightColor = _parseColor(_selectedColorCode);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: highlightColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.highlight != null ? 'Edit Note' : 'Add Note',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Color Selection
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: HighlightColors.all.map((color) {
                  final isSelected = color == _selectedColorCode;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColorCode = color;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _parseColor(color),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: theme.primaryColor,
                                width: 3,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Highlighted text preview
            if (widget.highlight != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: highlightColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.highlight!.selectedText,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Note input
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Add your note here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: theme.cardColor,
              ),
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.onDelete != null)
                  TextButton.icon(
                    onPressed: () {
                      widget.onDelete!();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                  )
                else
                  const SizedBox(),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        final note = _controller.text.trim();
                        widget.onSave(
                            note.isEmpty ? null : note, _selectedColorCode);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a dialog to add/edit a note
Future<void> showHighlightNoteDialog(
  BuildContext context, {
  Highlight? highlight,
  String? initialNote,
  required Function(String? note, String? colorCode) onSave,
  VoidCallback? onDelete,
}) async {
  await showDialog(
    context: context,
    builder: (context) => HighlightNoteDialog(
      highlight: highlight,
      initialNote: initialNote,
      onSave: onSave,
      onDelete: onDelete,
    ),
  );
}
