import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'reader_engine.dart';

/// Mounted text geometry only. The engine remains the owner of reading position.
/// Uses the actual SelectableText layout, including fallback fonts and scaling.
class TextLayoutAnchors {
  final _mounted = <int, ({BuildContext context, String text})>{};

  void attach(int index, BuildContext context, String text) {
    _mounted[index] = (context: context, text: text);
  }

  void detach(int index, BuildContext context) {
    if (identical(_mounted[index]?.context, context)) _mounted.remove(index);
  }

  RenderEditable? _editable(int index) {
    final entry = _mounted[index];
    if (entry == null || !entry.context.mounted) return null;
    final root = entry.context.findRenderObject();
    RenderEditable? result;
    void visit(RenderObject node) {
      if (node is RenderEditable && node.attached && node.hasSize) {
        result ??= node;
      } else if (result == null) {
        node.visitChildren(visit);
      }
    }

    if (root != null) visit(root);
    return result;
  }

  double? _rowTop(int index) {
    final root = _mounted[index]?.context.findRenderObject();
    return root is RenderBox && root.attached && root.hasSize
        ? root.localToGlobal(Offset.zero).dy
        : null;
  }

  ReadingPosition capture(ReadingPosition position, double height,
      {int? preferredOffset, String? layoutIdentity}) {
    // Footer builds may ask for progress while a captured page is reparenting.
    // Only committed-frame callbacks and commands may read text geometry.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      return position;
    }
    final index = position.paragraphIndex;
    if (index == null || height <= 0) return position;
    final render = _editable(index);
    final rowTop = _rowTop(index);
    if (render == null || rowTop == null) return position;
    final viewportTop = rowTop - (position.paragraphLeadingEdge ?? 0) * height;
    final textTop = render.localToGlobal(Offset.zero);
    final text = _mounted[index]!.text;
    var offset = preferredOffset;
    final paragraphStartsInView = (position.paragraphLeadingEdge ?? -1) >= 0;
    if (offset == null || offset < 0 || offset >= text.length) {
      var point = render.getPositionForPoint(Offset(
          textTop.dx, viewportTop > textTop.dy ? viewportTop : textTop.dy));
      var line = render.getLineAtOffset(point);
      final rect =
          render.getLocalRectForCaret(TextPosition(offset: line.start));
      // Prefer the first fully visible line when the preceding one is clipped.
      if (textTop.dy + rect.top < viewportTop - .5 && line.end < text.length) {
        point = TextPosition(offset: line.end + 1);
        line = render.getLineAtOffset(point);
      }
      // Caret rectangles can extend above their glyphs on device fonts. A
      // wholly visible paragraph must never skip its first line for that.
      offset = paragraphStartsInView ? 0 : line.start;
    }
    final caret = render.getLocalRectForCaret(TextPosition(offset: offset));
    final lineY = textTop.dy + caret.top - viewportTop;
    if ((lineY + caret.height <= 0 &&
            !(paragraphStartsInView && offset == 0)) ||
        lineY >= height) {
      return position;
    }
    return ReadingPosition(
      paragraphIndex: index,
      paragraphLeadingEdge: position.paragraphLeadingEdge,
      paragraphTrailingEdge: position.paragraphTrailingEdge,
      chapterIndex: position.chapterIndex,
      enumVersion: position.enumVersion,
      textOffset: offset,
      textViewportOffset: (lineY / height).clamp(0, .999999),
      layoutIdentity: layoutIdentity,
      anchorVersion: 1,
    );
  }

  /// Called after the target paragraph has laid out at its leading edge.
  /// Returns the pixel offset from that edge needed in the new viewport.
  double? restoreOffset(ReadingPosition position, double height) {
    final index = position.paragraphIndex;
    if (index == null) return null;
    final render = _editable(index);
    final rowTop = _rowTop(index);
    if (render == null || rowTop == null) return null;
    final offset = position.textOffset;
    final text = _mounted[index]!.text;
    if (position.anchorVersion != 1 ||
        offset == null ||
        offset < 0 ||
        offset >= text.length) {
      return null;
    }
    // Snap malformed offsets to a grapheme boundary without splitting emoji.
    var boundary = 0;
    for (final cluster in text.characters) {
      if (boundary + cluster.length > offset) break;
      boundary += cluster.length;
    }
    final caret = render.getLocalRectForCaret(TextPosition(offset: boundary));
    final y = render.localToGlobal(Offset(0, caret.top)).dy - rowTop;
    final fraction = position.textViewportOffset;
    final desired = fraction != null && fraction.isFinite
        ? (fraction * height).clamp(0, caret.height)
        : 0.0;
    return y - desired;
  }
}

/// Keep intermediate reflow layouts measurable but out of paint.
/// A render listener can be changed during layout without rebuilding ancestors.
class RestoreVisibility extends SingleChildRenderObjectWidget {
  const RestoreVisibility(
      {super.key, required this.covered, required super.child});
  final ValueListenable<bool> covered;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RestoreVisibility(covered);

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderObject renderObject) {
    (renderObject as _RestoreVisibility).covered = covered;
  }
}

class _RestoreVisibility extends RenderProxyBox {
  _RestoreVisibility(this._covered);
  ValueListenable<bool> _covered;
  set covered(ValueListenable<bool> value) {
    if (identical(value, _covered)) return;
    if (attached) _covered.removeListener(_changed);
    _covered = value;
    if (attached) _covered.addListener(_changed);
    _changed();
  }

  void _changed() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _covered.addListener(_changed);
  }

  @override
  void detach() {
    _covered.removeListener(_changed);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_covered.value) super.paint(context, offset);
  }

  // Keep hit testing active: a new user drag supersedes a pending restore.
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (!_covered.value) super.visitChildrenForSemantics(visitor);
  }
}
