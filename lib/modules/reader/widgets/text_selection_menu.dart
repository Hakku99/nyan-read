import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/highlight.dart';

/// Popup menu for text selection actions
class TextSelectionMenu extends StatelessWidget {
  final String selectedText;
  final Offset position;
  final Function(String colorCode) onHighlight;
  final VoidCallback onCopy;
  final VoidCallback onSearch;
  final VoidCallback onDismiss;

  const TextSelectionMenu({
    Key? key,
    required this.selectedText,
    required this.position,
    required this.onHighlight,
    required this.onCopy,
    required this.onSearch,
    required this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Copy button
            _ActionButton(
              icon: Icons.copy,
              label: 'Copy',
              onTap: () {
                Clipboard.setData(ClipboardData(text: selectedText));
                onCopy();
              },
            ),
            const SizedBox(width: 8),

            // Search button
            _ActionButton(
              icon: Icons.search,
              label: 'Search',
              onTap: onSearch,
            ),
            const SizedBox(width: 8),

            // Divider
            Container(
              width: 1,
              height: 32,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 8),

            // Highlight colors
            ...HighlightColors.all.map((color) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _ColorButton(
                    colorCode: color,
                    onTap: () => onHighlight(color),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).primaryColor),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final String colorCode;
  final VoidCallback onTap;

  const _ColorButton({
    required this.colorCode,
    required this.onTap,
  });

  Color _parseColor() {
    try {
      final hex = colorCode.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.yellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _parseColor(),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}
