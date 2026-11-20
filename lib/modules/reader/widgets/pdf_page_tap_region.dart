import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:pdfx/pdfx.dart' show PhotoViewDoubleTapRegion;

import 'reader_tap_zone.dart';

/// Keeps taps in viewport coordinates even when the PDF image is transformed.
class PdfPageTapRegion extends StatefulWidget {
  const PdfPageTapRegion({
    super.key,
    required this.enabled,
    required this.onTapUp,
    required this.child,
  });

  final bool enabled;
  final GestureTapUpCallback onTapUp;
  final Widget child;

  @override
  State<PdfPageTapRegion> createState() => _PdfPageTapRegionState();
}

class _PdfPageTapRegionState extends State<PdfPageTapRegion> {
  final _touches = <int>{};
  PointerDownEvent? _candidate;
  PointerUpEvent? _released;
  PointerUpEvent? _lastEdgeTap;

  ReaderTapZone _zone(Offset position) {
    final box = context.findRenderObject()! as RenderBox;
    return ReaderTapZone.at(box.globalToLocal(position).dx, box.size.width);
  }

  bool _allowsDoubleTap(PointerDownEvent event) =>
      event.kind != PointerDeviceKind.touch ||
      (_touches.isEmpty && _zone(event.position) == ReaderTapZone.center);

  void _down(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _touches.add(event.pointer);
    _released = null;
    _candidate = _touches.length == 1 ? event : null;
    final last = _lastEdgeTap;
    _lastEdgeTap = null;
    // A close second tap just across the boundary must not open controls
    // after its first tap has already turned the page.
    if (last != null &&
        event.timeStamp - last.timeStamp <= kDoubleTapTimeout &&
        (event.position - last.position).distance <= kDoubleTapSlop &&
        _zone(event.position) == ReaderTapZone.center) {
      _candidate = null;
    }
  }

  void _up(PointerUpEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _touches.remove(event.pointer);
    if (_candidate?.pointer == event.pointer) _released = event;
  }

  void _cancel(PointerCancelEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _touches.remove(event.pointer);
    _candidate = null;
    _released = null;
  }

  void _accepted(TapUpDetails details) {
    if (details.kind == PointerDeviceKind.touch) {
      final down = _candidate;
      final up = _released;
      if (down == null || up == null) return;
      _candidate = null;
      _released = null;
      final zone = _zone(up.position);
      if (_zone(down.position) != zone ||
          (zone != ReaderTapZone.center &&
              up.timeStamp - down.timeStamp >= kLongPressTimeout)) {
        return;
      }
      if (zone != ReaderTapZone.center) _lastEdgeTap = up;
    }
    widget.onTapUp(details);
  }

  @override
  void didUpdateWidget(PdfPageTapRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _touches.clear();
      _candidate = null;
      _released = null;
      _lastEdgeTap = null;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: widget.enabled ? _down : null,
        onPointerUp: widget.enabled ? _up : null,
        onPointerCancel: widget.enabled ? _cancel : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: widget.enabled ? _accepted : null,
          child: PhotoViewDoubleTapRegion(
            allows: widget.enabled ? _allowsDoubleTap : null,
            child: widget.child,
          ),
        ),
      );
}
