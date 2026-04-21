import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/models/highlight.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';

/// Text widget that renders highlights and supports selection
class HighlightableText extends StatefulWidget {
  final String text;
  final int paragraphIndex;
  final List<Highlight> highlights;
  final TextStyle style;
  final Color backgroundColor;
  final EdgeInsets padding;

  /// Callback when text is selected and a highlight color is chosen
  /// Parameters: paragraphIndex, start, end, text, colorCode
  final Function(int paragraphIndex, int start, int end, String text,
      String colorCode)? onTextSelected;
  final Function(Highlight highlight)? onHighlightTap;
  final Function(Offset position)? onTap;

  const HighlightableText({
    super.key,
    required this.text,
    required this.paragraphIndex,
    required this.highlights,
    required this.style,
    required this.backgroundColor,
    this.padding = EdgeInsets.zero,
    this.onTextSelected,
    this.onHighlightTap,
    this.onTap,
  });

  @override
  State<HighlightableText> createState() => _HighlightableTextState();
}

class _HighlightableTextState extends State<HighlightableText> {
  TextSelection? _currentSelection;
  final List<TapGestureRecognizer> _recognizers = [];
  Timer? _tapTimer;
  final GlobalKey _listenerKey = GlobalKey(debugLabel: 'highlightable_listener');

  // Swipe detection
  Offset? _pointerDownPosition;
  bool _isScrolling = false;
  static const double _scrollThreshold = 10.0; // Pixels to consider it a scroll

  @override
  void dispose() {
    _tapTimer?.cancel();
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      padding: widget.padding,
      child: Listener(
        key: _listenerKey,
        onPointerDown: (event) {
          _pointerDownPosition = event.position;
          _isScrolling = false;
        },
        onPointerMove: (event) {
          // Detect if user is scrolling based on movement distance
          if (_pointerDownPosition != null) {
            final distance = (event.position - _pointerDownPosition!).distance;
            if (distance > _scrollThreshold) {
              _isScrolling = true;
            }
          }
        },
        onPointerUp: (event) {
          // Only trigger tap if not scrolling and no text selected
          if (_isScrolling) {
            _isScrolling = false;
            _pointerDownPosition = null;
            return;
          }

          // If text is selected (or being selected), ignore the tap for page turning logic
          if (_currentSelection != null && !_currentSelection!.isCollapsed) {
            _pointerDownPosition = null;
            return;
          }

          // Short delay so [TapGestureRecognizer] on highlights can run first and
          // cancel this timer; global offset matches outer tap zone math.
          _tapTimer?.cancel();
          final listenerBox =
              _listenerKey.currentContext?.findRenderObject() as RenderBox?;
          final global = listenerBox != null
              ? listenerBox.localToGlobal(event.localPosition)
              : event.localPosition;
          _tapTimer = Timer(const Duration(milliseconds: 50), () {
            widget.onTap?.call(global);
          });

          _pointerDownPosition = null;
        },
        onPointerCancel: (event) {
          _isScrolling = false;
          _pointerDownPosition = null;
        },
        child: SelectableText.rich(
          _buildTextSpan(),
          style: widget.style,
          onSelectionChanged: (selection, cause) {
            _currentSelection = selection;
          },
          contextMenuBuilder: (context, editableTextState) {
            return _buildContextMenu(context, editableTextState);
          },
        ),
      ),
    );
  }

  TextSpan _buildTextSpan() {
    // Dispose old recognizers
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    if (widget.highlights.isEmpty) {
      return TextSpan(text: widget.text, style: widget.style);
    }

    // Filter highlights for this paragraph
    final paragraphHighlights = widget.highlights
        .where((h) => h.paragraphIndex == widget.paragraphIndex)
        .toList();

    if (paragraphHighlights.isEmpty) {
      return TextSpan(text: widget.text, style: widget.style);
    }

    // Sort by start offset
    paragraphHighlights.sort((a, b) => a.startOffset.compareTo(b.startOffset));

    final spans = <InlineSpan>[];
    int currentIndex = 0;

    for (final highlight in paragraphHighlights) {
      // Validate offsets
      if (highlight.startOffset > widget.text.length ||
          highlight.endOffset > widget.text.length ||
          highlight.startOffset < 0 ||
          highlight.endOffset <= highlight.startOffset) {
        continue;
      }

      // Skip if this highlight overlaps with previous one
      if (highlight.startOffset < currentIndex) {
        continue;
      }

      // Add text before highlight
      if (currentIndex < highlight.startOffset) {
        spans.add(TextSpan(
          text: widget.text.substring(currentIndex, highlight.startOffset),
          style: widget.style,
        ));
      }

      // Add highlighted text
      final highlightColor = _parseColor(highlight.colorCode);

      // Create recognizer for this highlight
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          _tapTimer?.cancel();
          widget.onHighlightTap?.call(highlight);
        };
      _recognizers.add(recognizer);

      spans.add(TextSpan(
        text: widget.text.substring(highlight.startOffset, highlight.endOffset),
        style: widget.style.copyWith(
          backgroundColor: highlightColor.withValues(alpha: 0.4),
        ),
        recognizer: recognizer,
      ));

      currentIndex = highlight.endOffset;
    }

    // Add remaining text
    if (currentIndex < widget.text.length) {
      spans.add(TextSpan(
        text: widget.text.substring(currentIndex),
        style: widget.style,
      ));
    }

    return TextSpan(children: spans);
  }

  Color _parseColor(String colorCode) {
    try {
      final hex = colorCode.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.yellow;
    }
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    // Get current selection from the editable text state
    final selection = editableTextState.textEditingValue.selection;
    final fullText = widget.text;

    String selectedText = '';
    int selectionStart = 0;
    int selectionEnd = 0;

    if (selection.isValid && !selection.isCollapsed) {
      selectionStart = selection.start.clamp(0, fullText.length);
      selectionEnd = selection.end.clamp(0, fullText.length);
      if (selectionEnd > selectionStart) {
        selectedText = fullText.substring(selectionStart, selectionEnd);
      }
    }

    final buttonItems = <ContextMenuButtonItem>[
      ContextMenuButtonItem(
        label: 'Copy',
        onPressed: () {
          if (selectedText.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: selectedText));
            SnackBarUtils.show(context, 'Copied to clipboard');
          }
          editableTextState.hideToolbar();
        },
      ),
      ContextMenuButtonItem(
        label: 'Search',
        onPressed: () {
          if (selectedText.isNotEmpty) {
            _searchInBrowser(selectedText);
          }
          editableTextState.hideToolbar();
        },
      ),
    ];

    for (final color in HighlightColors.all) {
      buttonItems.add(ContextMenuButtonItem(
        label: '${_getColorEmoji(color)} ${HighlightColors.getName(color)}',
        onPressed: () {
          if (selectedText.isNotEmpty) {
            widget.onTextSelected?.call(
              widget.paragraphIndex,
              selectionStart,
              selectionEnd,
              selectedText,
              color,
            );
          }
          editableTextState.hideToolbar();
        },
      ));
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  String _getColorEmoji(String colorCode) {
    switch (colorCode) {
      case HighlightColors.yellow:
        return '🟡';
      case HighlightColors.green:
        return '🟢';
      case HighlightColors.blue:
        return '🔵';
      case HighlightColors.pink:
        return '🔴';
      case HighlightColors.orange:
        return '🟠';
      default:
        return '⚪';
    }
  }

  Future<void> _searchInBrowser(String query) async {
    final url = Uri.parse(
        'https://www.google.com/search?q=${Uri.encodeComponent(query)}');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      // Fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: url.toString()));
      if (mounted) {
        SnackBarUtils.show(
            context, 'Could not open browser. Search link copied.');
      }
    }
  }
}
