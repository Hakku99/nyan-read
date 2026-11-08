import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../reader_engine/page_turn_request.dart';

class SmoothPageReader extends StatefulWidget {
  const SmoothPageReader({
    super.key,
    required this.child,
    required this.onPreviousTap,
    required this.onNextTap,
    required this.onCenterTap,
    this.enabled = true,
    this.layoutIdentity,
    this.captureTimeout = const Duration(milliseconds: 350),
    this.prepareTimeout = const Duration(milliseconds: 1500),
    this.captureFrame,
    this.onTurnMeasured,
    this.snapshotIncoming = true,
    this.duration = const Duration(milliseconds: 360),
    this.curve = Curves.easeInOutCubic,
  });

  final bool enabled;
  final Object? layoutIdentity;
  final Duration captureTimeout;
  final Duration prepareTimeout;
  @visibleForTesting
  final Future<ui.Image?> Function()? captureFrame;
  final ValueChanged<Map<String, num>>? onTurnMeasured;

  /// Text pages benefit from rasterizing once; PDF pages already use an image.
  final bool snapshotIncoming;
  final Widget child;
  final VoidCallback onPreviousTap;
  final VoidCallback onNextTap;
  final VoidCallback onCenterTap;
  final Duration duration;
  final Curve curve;

  @override
  State<SmoothPageReader> createState() => SmoothPageReaderState();
}

class SmoothPageReaderState extends State<SmoothPageReader>
    with SingleTickerProviderStateMixin {
  // Bound the additional RGBA image to 16 MiB; large displays keep live paint.
  static const _maxIncomingSnapshotPixels = 4 * 1024 * 1024;
  final GlobalKey _captureKey = GlobalKey();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  PageTurnRequest? _activeRequest;
  Object? _environment;
  bool _capturePending = false;
  bool _preparing = false;
  bool _forward = true;
  ui.Image? _outgoingImage;
  ui.Image? _incomingImage;
  bool _isAnimating = false;

  bool get isAnimating => _isAnimating;

  @override
  void didUpdateWidget(covariant SmoothPageReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.layoutIdentity != widget.layoutIdentity) {
      _activeRequest?.cancel();
      _controller.stop(canceled: true);
    }
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final environment = (
      MediaQuery.sizeOf(context),
      MediaQuery.devicePixelRatioOf(context),
      MediaQuery.textScalerOf(context),
      Directionality.of(context),
      Theme.of(context)
    );
    if (_environment != null && _environment != environment) {
      _activeRequest?.cancel();
      _controller.stop(canceled: true);
    }
    _environment = environment;
  }

  @override
  void dispose() {
    _activeRequest?.cancel();
    _controller.dispose();
    _outgoingImage?.dispose();
    _outgoingImage = null;
    _incomingImage?.dispose();
    _incomingImage = null;
    super.dispose();
  }

  void handleExternalTap(Offset globalPosition) {
    _handleTap(TapUpDetails(
      globalPosition: globalPosition,
      kind: PointerDeviceKind.touch,
    ));
  }

  void _handleTap(TapUpDetails details) {
    if (!widget.enabled) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final localX = box.globalToLocal(details.globalPosition).dx;
    final ratio = localX / box.size.width;
    if (ratio < 0.20) {
      widget.onPreviousTap();
    } else if (ratio > 0.80) {
      widget.onNextTap();
    } else {
      widget.onCenterTap();
    }
  }

  /// Set [readyIncludesPaint] only when [waitForReady] awaits target paint.
  Future<void> playTurn({
    required bool forward,
    required Future<void> Function() dispatchTurn,
    Future<bool> Function()? waitForReady,
    bool readyIncludesPaint = false,
    bool Function()? didMove,
    PageTurnRequest? request,
  }) async {
    if (!mounted || _isAnimating || !widget.enabled) return;
    final turn = request ?? PageTurnRequest();
    turn.checkActive();
    _activeRequest = turn;
    _isAnimating = true;
    _forward = forward;
    final total = Stopwatch()..start();
    final phase = Stopwatch()..start();
    final metrics = <String, num>{};
    try {
      _outgoingImage = await _captureFor(turn);
      metrics['captureMs'] = phase.elapsedMicroseconds / 1000;
      metrics['snapshotPixels'] =
          (_outgoingImage?.width ?? 0) * (_outgoingImage?.height ?? 0);
      turn.checkActive();
      // Paint the old page above the live reader before navigation changes it.
      _preparing = true;
      setState(() {});
      if (_outgoingImage != null) {
        await turn.wait(SchedulerBinding.instance.endOfFrame);
      }
      turn.checkActive();
      phase.reset();
      await turn
          .wait(Future<void>.sync(dispatchTurn).timeout(widget.prepareTimeout));
      metrics['navigationMs'] = phase.elapsedMicroseconds / 1000;
      turn.checkActive();
      if (_outgoingImage == null || didMove?.call() == false) return;
      phase.reset();
      bool ready;
      try {
        ready = await turn.wait((waitForReady?.call() ??
                SchedulerBinding.instance.endOfFrame.then((_) => true))
            .timeout(widget.prepareTimeout));
      } on TimeoutException {
        // Reveal the reader's normal loading state; do not animate a stale page.
        return;
      }
      metrics['readyMs'] = phase.elapsedMicroseconds / 1000;
      turn.checkActive();
      if (!ready) return;
      // A visual update queued after readiness must still reach the snapshot.
      final scheduler = SchedulerBinding.instance;
      if (!readyIncludesPaint ||
          waitForReady == null ||
          scheduler.hasScheduledFrame) {
        await turn.wait(scheduler.endOfFrame);
      }
      turn.checkActive();
      if (widget.snapshotIncoming &&
          metrics['snapshotPixels']! <= _maxIncomingSnapshotPixels) {
        phase.reset();
        // Capture the selected painted frame without scheduling another one.
        _incomingImage = await _captureFor(turn, frameReady: true);
        metrics['incomingCaptureMs'] = phase.elapsedMicroseconds / 1000;
        metrics['snapshotPixels'] = metrics['snapshotPixels']! +
            (_incomingImage?.width ?? 0) * (_incomingImage?.height ?? 0);
        turn.checkActive();
      }
      _controller.value = 0;
      setState(() => _preparing = false);
      phase.reset();
      await turn.wait(_controller.forward(from: 0).orCancel);
      metrics['animationMs'] = phase.elapsedMicroseconds / 1000;
    } on PageTurnCancelled {
      // An accepted navigation remains owned by the engine after cancellation.
    } on TickerCanceled {
      // Disposal and a new layout cancel presentation, never navigation twice.
    } finally {
      turn.cancel();
      if (mounted) _controller.stop(canceled: true);
      _isAnimating = false;
      _preparing = false;
      _activeRequest = null;
      _outgoingImage?.dispose();
      _outgoingImage = null;
      _incomingImage?.dispose();
      _incomingImage = null;
      metrics['totalMs'] = total.elapsedMicroseconds / 1000;
      widget.onTurnMeasured?.call(Map.unmodifiable(metrics));
      if (mounted) setState(() {});
    }
  }

  Future<ui.Image?> _captureFor(PageTurnRequest request,
      {bool frameReady = false}) async {
    // A timed-out GPU readback cannot be cancelled. Never start a second one
    // until it returns, and dispose its late image rather than retaining it.
    if (_capturePending) return null;
    _capturePending = true;
    var accepted = true;
    final capture = Future<ui.Image?>.sync(widget.captureFrame ??
            () => _captureCurrentFrame(frameReady: frameReady))
        .then((image) {
      if (!accepted || !request.isActive || !mounted) {
        image?.dispose();
        return null;
      }
      return image;
    }).whenComplete(() => _capturePending = false);
    try {
      return await request.wait(capture.timeout(widget.captureTimeout));
    } on TimeoutException {
      return null;
    } on PageTurnCancelled {
      rethrow;
    } catch (error) {
      // A direct turn is the visible fallback for an unavailable snapshot.
      debugPrint('Page snapshot unavailable (${error.runtimeType}).');
      return null;
    } finally {
      accepted = false;
    }
  }

  Future<ui.Image?> _captureCurrentFrame({bool frameReady = false}) async {
    try {
      // Wait for paint in all build modes. debugNeedsPaint is assert-only and
      // throws in profile/release; a zero-delay timer does not await paint.
      if (!frameReady) await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return null;
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null ||
          !boundary.attached ||
          !boundary.hasSize ||
          boundary.size.isEmpty) {
        return null;
      }
      return await boundary.toImage(
          pixelRatio: MediaQuery.devicePixelRatioOf(context));
    } catch (error) {
      // The visible fallback is an immediate page turn, preserving the input
      // even when an optional snapshot cannot be created.
      debugPrint(
          'Page snapshot unavailable (${error.runtimeType}); turning directly.');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        if (notification.dragDetails != null) _activeRequest?.cancel();
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: widget.enabled ? _handleTap : null,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = widget.curve.transform(_controller.value);
              final active = _outgoingImage != null && widget.enabled;
              final showIncoming =
                  active && !_preparing && _incomingImage != null;

              final width = MediaQuery.sizeOf(context).width;
              final outgoingX = _forward ? -t * width : t * width;
              final incomingX = _forward ? (1 - t) * width : -(1 - t) * width;

              return ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The live reader stays at one keyed location through capture,
                    // animation, cancellation and mode changes.
                    Transform.translate(
                      key: const ValueKey('live-reader'),
                      offset: Offset(active && !_preparing ? incomingX : 0, 0),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _LivePageVisibility(
                            hidden: showIncoming,
                            child: child ?? const SizedBox.shrink(),
                          ),
                          if (showIncoming)
                            RawImage(
                                image: _incomingImage,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.low),
                        ],
                      ),
                    ),
                    if (active)
                      Transform.translate(
                        offset: Offset(_preparing ? 0 : outgoingX, 0),
                        child: RawImage(
                          image: _outgoingImage,
                          fit: BoxFit.cover,
                          // The snapshot retains device resolution. Bilinear
                          // sampling only interpolates fractional translation;
                          // expensive rescaling filters add no detail here.
                          filterQuality: FilterQuality.low,
                        ),
                      ),
                  ],
                ),
              );
            },
            // Moving the live page must not repaint its text on every animation
            // tick. Navigation can repaint this boundary independently.
            child: RepaintBoundary(key: _captureKey, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Keep the live page mounted without an opacity layer at handoff.
class _LivePageVisibility extends SingleChildRenderObjectWidget {
  const _LivePageVisibility({required this.hidden, required super.child});

  final bool hidden;

  @override
  _RenderLivePageVisibility createRenderObject(BuildContext context) =>
      _RenderLivePageVisibility(hidden);

  @override
  void updateRenderObject(
      BuildContext context, _RenderLivePageVisibility renderObject) {
    renderObject.hidden = hidden;
  }
}

class _RenderLivePageVisibility extends RenderProxyBox {
  _RenderLivePageVisibility(this._hidden);

  bool _hidden;
  set hidden(bool value) {
    if (value == _hidden) return;
    _hidden = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  bool paintsChild(RenderObject child) => !_hidden && super.paintsChild(child);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_hidden) super.paint(context, offset);
  }

  // Like the previous zero-opacity wrapper, leave hit testing intact.
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (!_hidden) super.visitChildrenForSemantics(visitor);
  }
}
