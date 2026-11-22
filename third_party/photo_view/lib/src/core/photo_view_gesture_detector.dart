import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'photo_view_hit_corners.dart';

class PhotoViewGestureDetector extends StatelessWidget {
  const PhotoViewGestureDetector({
    Key? key,
    this.hitDetector,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.onDoubleTap,
    this.child,
    this.onTapUp,
    this.onTapDown,
    this.behavior,
  }) : super(key: key);

  final GestureDoubleTapCallback? onDoubleTap;
  final HitCornersDetector? hitDetector;

  final GestureScaleStartCallback? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleEndCallback? onScaleEnd;

  final GestureTapUpCallback? onTapUp;
  final GestureTapDownCallback? onTapDown;

  final Widget? child;

  final HitTestBehavior? behavior;

  @override
  Widget build(BuildContext context) {
    final scope = PhotoViewGestureDetectorScope.of(context);

    final Axis? axis = scope?.axis;

    final Map<Type, GestureRecognizerFactory> gestures =
        <Type, GestureRecognizerFactory>{};

    if (onTapDown != null || onTapUp != null) {
      gestures[TapGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
        () => TapGestureRecognizer(debugOwner: this),
        (TapGestureRecognizer instance) {
          instance
            ..onTapDown = onTapDown
            ..onTapUp = onTapUp;
        },
      );
    }

    final region =
        context.dependOnInheritedWidgetOfExactType<PhotoViewDoubleTapRegion>();
    if (region?.allows != null) {
      gestures[_RegionDoubleTapRecognizer] =
          GestureRecognizerFactoryWithHandlers<_RegionDoubleTapRecognizer>(
        () => _RegionDoubleTapRecognizer(debugOwner: this),
        (instance) => instance
          ..allows = region!.allows!
          ..onDoubleTap = onDoubleTap,
      );
    } else {
      gestures[DoubleTapGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
        () => DoubleTapGestureRecognizer(debugOwner: this),
        (DoubleTapGestureRecognizer instance) {
          instance.onDoubleTap = onDoubleTap;
        },
      );
    }

    gestures[PhotoViewGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<PhotoViewGestureRecognizer>(
      () => PhotoViewGestureRecognizer(
          hitDetector: hitDetector, debugOwner: this, validateAxis: axis),
      (PhotoViewGestureRecognizer instance) {
        instance
          ..dragStartBehavior = DragStartBehavior.start
          ..onStart = onScaleStart
          ..onUpdate = onScaleUpdate
          ..onEnd = onScaleEnd;
      },
    );

    return RawGestureDetector(
      behavior: behavior,
      child: child,
      gestures: gestures,
    );
  }
}

/// Limits which pointer downs may start or complete a double tap.
/// Scale and pan recognizers still receive the entire pointer sequence.
class PhotoViewDoubleTapRegion extends InheritedWidget {
  const PhotoViewDoubleTapRegion({
    Key? key,
    required this.allows,
    required Widget child,
  }) : super(key: key, child: child);

  final bool Function(PointerDownEvent)? allows;

  @override
  bool updateShouldNotify(PhotoViewDoubleTapRegion oldWidget) =>
      oldWidget.allows != allows;
}

class _RegionDoubleTapRecognizer extends GestureRecognizer {
  _RegionDoubleTapRecognizer({Object? debugOwner})
      : super(debugOwner: debugOwner);

  late bool Function(PointerDownEvent) allows;
  GestureDoubleTapCallback? onDoubleTap;
  DoubleTapGestureRecognizer? _delegate;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (!allows(event)) {
      // Releasing a held center tap before the parent receives this new
      // down can open controls over a valid edge turn. Let dispatch finish.
      final previous = _delegate;
      _delegate = null;
      if (previous != null) scheduleMicrotask(previous.dispose);
      return;
    }
    final recognizer =
        _delegate ??= DoubleTapGestureRecognizer(debugOwner: debugOwner);
    recognizer
      ..gestureSettings = gestureSettings
      ..onDoubleTap = onDoubleTap
      ..addPointer(event);
  }

  // Only the stock recognizer enters the arena.
  @override
  void acceptGesture(int pointer) {}
  @override
  void rejectGesture(int pointer) {}
  @override
  String get debugDescription => 'regional double tap';
  @override
  void dispose() {
    _delegate?.dispose();
    super.dispose();
  }
}

class PhotoViewGestureRecognizer extends ScaleGestureRecognizer {
  PhotoViewGestureRecognizer({
    this.hitDetector,
    Object? debugOwner,
    this.validateAxis,
    PointerDeviceKind? kind,
  }) : super(debugOwner: debugOwner);
  final HitCornersDetector? hitDetector;
  final Axis? validateAxis;

  Map<int, Offset> _pointerLocations = <int, Offset>{};

  Offset? _initialFocalPoint;
  Offset? _currentFocalPoint;
  Offset? _pendingSingleTouchOrigin;

  bool ready = true;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _pendingSingleTouchOrigin = ready &&
            validateAxis == Axis.vertical &&
            event.kind == PointerDeviceKind.touch
        ? event.position
        : null;
    if (ready) {
      ready = false;
      _pointerLocations = <int, Offset>{};
    }
    super.addAllowedPointer(event);
  }

  @override
  void acceptGesture(int pointer) {
    _pendingSingleTouchOrigin = null;
    super.acceptGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pendingSingleTouchOrigin = null;
    ready = true;
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (validateAxis != null) {
      _computeEvent(event);
      _updateDistances();
      if (event is PointerMoveEvent && !_shouldTrackMove(event)) return;
    }
    super.handleEvent(event);
  }

  void _computeEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      if (!event.synthesized) {
        _pointerLocations[event.pointer] = event.position;
      }
    } else if (event is PointerDownEvent) {
      _pointerLocations[event.pointer] = event.position;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointerLocations.remove(event.pointer);
    }

    _initialFocalPoint = _currentFocalPoint;
  }

  void _updateDistances() {
    final int count = _pointerLocations.keys.length;
    Offset focalPoint = Offset.zero;
    for (int pointer in _pointerLocations.keys)
      focalPoint += _pointerLocations[pointer]!;
    _currentFocalPoint =
        count > 0 ? focalPoint / count.toDouble() : Offset.zero;
  }

  bool _shouldTrackMove(PointerMoveEvent event) {
    final origin = _pendingSingleTouchOrigin;
    if (origin != null && !event.synthesized) {
      final travel = event.position - origin;
      final distanceY = travel.dy.abs();
      if (distanceY > travel.dx.abs() && hitDetector!.canYieldAtContainedScale) {
        // Keep small moves pending for a possible pinch. For a drag, yield
        // before the base scale recognizer can claim the same move as a pan.
        if (distanceY <= computeHitSlop(event.kind, gestureSettings)) {
          return true;
        }
        resolve(GestureDisposition.rejected);
        return false;
      }
    }
    final move = _initialFocalPoint! - _currentFocalPoint!;
    final bool shouldMove = hitDetector!.shouldMove(move, validateAxis!);
    if (shouldMove || _pointerLocations.keys.length > 1) {
      acceptGesture(event.pointer);
    }
    return true;
  }
}

/// An [InheritedWidget] responsible to give a axis aware scope to [PhotoViewGestureRecognizer].
///
/// When using this, PhotoView will test if the content zoomed has hit edge every time user pinches,
/// if so, it will let parent gesture detectors win the gesture arena
///
/// Useful when placing PhotoView inside a gesture sensitive context,
/// such as [PageView], [Dismissible], [BottomSheet].
///
/// Usage example:
/// ```
/// PhotoViewGestureDetectorScope(
///   axis: Axis.vertical,
///   child: PhotoView(
///     imageProvider: AssetImage("assets/pudim.jpg"),
///   ),
/// );
/// ```
class PhotoViewGestureDetectorScope extends InheritedWidget {
  PhotoViewGestureDetectorScope({
    this.axis,
    required Widget child,
  }) : super(child: child);

  static PhotoViewGestureDetectorScope? of(BuildContext context) {
    final PhotoViewGestureDetectorScope? scope = context
        .dependOnInheritedWidgetOfExactType<PhotoViewGestureDetectorScope>();
    return scope;
  }

  final Axis? axis;

  @override
  bool updateShouldNotify(PhotoViewGestureDetectorScope oldWidget) {
    return axis != oldWidget.axis;
  }
}
