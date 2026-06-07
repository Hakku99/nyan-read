import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/models/highlight.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import 'text_selection_menu.dart';

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

  /// Pool of live gesture recognizers keyed by highlight id.  Each recognizer
  /// outlives rebuilds; [_buildTextSpan] rebinds its `onTap` to the freshly
  /// resolved highlight object from [widget.highlights] so the
  /// recognizer never dangles on a stale closure.
  final Map<String, TapGestureRecognizer> _recognizerPool = {};

  Timer? _tapTimer;
  final GlobalKey _listenerKey = GlobalKey(debugLabel: 'highlightable_listener');

  // Memoised TextSpan.  Rebuilt only when one of the following changes:
  // paragraph index, the text itself, the text style object, or the
  // structural fingerprint of the highlights that apply to this paragraph.
  TextSpan? _cachedSpan;
  int? _cachedParagraphIndex;
  String? _cachedText;
  TextStyle? _cachedStyle;
  int? _cachedHighlightsFingerprint;

  // Swipe detection
  Offset? _pointerDownPosition;
  bool _isScrolling = false;
  static const double _scrollThreshold = 10.0; // Pixels to consider it a scroll

  @override
  void dispose() {
    _tapTimer?.cancel();
    for (final recognizer in _recognizerPool.values) {
      recognizer.dispose();
    }
    _recognizerPool.clear();
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

  /// Structural fingerprint of the highlights that will contribute spans for
  /// this paragraph.  Used for cache invalidation — paragraph-local, cheap
  /// to recompute (O(highlights)), independent of object identity.
  int _fingerprintHighlights(List<Highlight> highlights) {
    // Filter + sort deterministically so the fingerprint matches
    // [_buildTextSpan]'s traversal order.
    final relevant = highlights
        .where((h) => h.paragraphIndex == widget.paragraphIndex)
        .toList()
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    if (relevant.isEmpty) return 0;
    return Object.hashAll([
      for (final h in relevant)
        Object.hash(h.id, h.startOffset, h.endOffset, h.colorCode),
    ]);
  }

  TextSpan _buildTextSpan() {
    final fingerprint = _fingerprintHighlights(widget.highlights);
    final cached = _cachedSpan;
    if (cached != null &&
        _cachedParagraphIndex == widget.paragraphIndex &&
        _cachedText == widget.text &&
        identical(_cachedStyle, widget.style) &&
        _cachedHighlightsFingerprint == fingerprint) {
      // Rebind recognizer callbacks in case the parent passed a new
      // [onHighlightTap] closure.  Binding is O(spans) and does NOT
      // dispose or reallocate any recognizer.
      _rebindRecognizerCallbacks();
      return cached;
    }

    final paragraphHighlights = widget.highlights
        .where((h) => h.paragraphIndex == widget.paragraphIndex)
        .toList()
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    // Track which recognizers are still in use this build.  Anything left
    // behind will be disposed at the end — no recognizer leaks, no
    // per-build allocation for stable highlight sets.
    final survivingIds = <String>{};

    TextSpan result;
    if (paragraphHighlights.isEmpty) {
      result = TextSpan(text: widget.text, style: widget.style);
    } else {
      final spans = <InlineSpan>[];
      int currentIndex = 0;

      for (final highlight in paragraphHighlights) {
        if (highlight.startOffset > widget.text.length ||
            highlight.endOffset > widget.text.length ||
            highlight.startOffset < 0 ||
            highlight.endOffset <= highlight.startOffset) {
          continue;
        }

        if (highlight.startOffset < currentIndex) {
          continue;
        }

        if (currentIndex < highlight.startOffset) {
          spans.add(TextSpan(
            text: widget.text.substring(currentIndex, highlight.startOffset),
            style: widget.style,
          ));
        }

        final highlightColor = _parseColor(highlight.colorCode);
        final recognizer = _acquireRecognizer(highlight);
        survivingIds.add(highlight.id);

        spans.add(TextSpan(
          text: widget.text
              .substring(highlight.startOffset, highlight.endOffset),
          style: widget.style.copyWith(
            backgroundColor: highlightColor.withValues(alpha: 0.4),
          ),
          recognizer: recognizer,
        ));

        currentIndex = highlight.endOffset;
      }

      if (currentIndex < widget.text.length) {
        spans.add(TextSpan(
          text: widget.text.substring(currentIndex),
          style: widget.style,
        ));
      }

      result = TextSpan(children: spans);
    }

    // Reap any pool entries that no longer back a live span.
    final staleIds =
        _recognizerPool.keys.where((id) => !survivingIds.contains(id)).toList();
    for (final id in staleIds) {
      _recognizerPool.remove(id)?.dispose();
    }

    _cachedSpan = result;
    _cachedParagraphIndex = widget.paragraphIndex;
    _cachedText = widget.text;
    _cachedStyle = widget.style;
    _cachedHighlightsFingerprint = fingerprint;
    return result;
  }

  /// Fetch (or create) the recognizer for [highlight] and bind it to the
  /// current `onHighlightTap` closure.  The recognizer itself is pooled
  /// across rebuilds; only its callback rotates.
  TapGestureRecognizer _acquireRecognizer(Highlight highlight) {
    final existing = _recognizerPool[highlight.id];
    final recognizer = existing ?? TapGestureRecognizer();
    recognizer.onTap = () {
      _tapTimer?.cancel();
      widget.onHighlightTap?.call(highlight);
    };
    if (existing == null) {
      _recognizerPool[highlight.id] = recognizer;
    }
    return recognizer;
  }

  /// Cache-hit fast path: rebind live recognizers against the current
  /// highlight list so a stale closure never fires a tap.
  void _rebindRecognizerCallbacks() {
    if (_recognizerPool.isEmpty) return;
    for (final highlight in widget.highlights) {
      if (highlight.paragraphIndex != widget.paragraphIndex) continue;
      final recognizer = _recognizerPool[highlight.id];
      if (recognizer == null) continue;
      recognizer.onTap = () {
        _tapTimer?.cancel();
        widget.onHighlightTap?.call(highlight);
      };
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

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
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

    final anchors = editableTextState.contextMenuAnchors;
    // Place the menu above the selection (primaryAnchor) when space allows,
    // falling back to below (secondaryAnchor) at the top of the screen.
    return _PositionedSelectionMenu(
      anchors: anchors,
      child: TextSelectionMenu(
        selectedText: selectedText,
        position: anchors.primaryAnchor,
        onHighlight: (color) {
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
        onCopy: () {
          if (selectedText.isNotEmpty) {
            SnackBarUtils.show(context, 'Copied to clipboard');
          }
          editableTextState.hideToolbar();
        },
        onSearch: () {
          if (selectedText.isNotEmpty) {
            _searchInBrowser(selectedText);
          }
          editableTextState.hideToolbar();
        },
        onDismiss: editableTextState.hideToolbar,
      ),
    );
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

/// Positions [TextSelectionMenu] above or below the selection anchor,
/// keeping the menu within screen bounds.
class _PositionedSelectionMenu extends StatelessWidget {
  final TextSelectionToolbarAnchors anchors;
  final Widget child;

  const _PositionedSelectionMenu({
    required this.anchors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // menuHeight is an estimate; the real height is constrained by the child.
    const double menuHeight = 56;
    const double menuMargin = 8;

    final primary = anchors.primaryAnchor;
    final secondary = anchors.secondaryAnchor;

    final screenSize = MediaQuery.sizeOf(context);

    // Prefer above the selection; fall back to below when near top edge.
    final double top;
    if (primary.dy - menuHeight - menuMargin >= 0) {
      top = primary.dy - menuHeight - menuMargin;
    } else if (secondary != null) {
      top = secondary.dy + menuMargin;
    } else {
      top = primary.dy + menuMargin;
    }

    // Clamp horizontally so the menu doesn't bleed off screen edges.
    const double menuWidth = 300; // generous upper bound
    final double left = (primary.dx - menuWidth / 2)
        .clamp(menuMargin, screenSize.width - menuWidth - menuMargin);

    return Stack(
      children: [
        Positioned(
          top: top,
          left: left,
          child: child,
        ),
      ],
    );
  }
}
