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

  Future<void> playTurn({
    required bool forward,
    required Future<void> Function() dispatchTurn,
    Future<bool> Function()? waitForReady,
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
      await turn.wait(SchedulerBinding.instance.endOfFrame);
      turn.checkActive();
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
      metrics['totalMs'] = total.elapsedMicroseconds / 1000;
      widget.onTurnMeasured?.call(Map.unmodifiable(metrics));
      if (mounted) setState(() {});
    }
  }

  Future<ui.Image?> _captureFor(PageTurnRequest request) async {
    // A timed-out GPU readback cannot be cancelled. Never start a second one
    // until it returns, and dispose its late image rather than retaining it.
    if (_capturePending) return null;
    _capturePending = true;
    var accepted = true;
    final capture =
        Future<ui.Image?>.sync(widget.captureFrame ?? _captureCurrentFrame)
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

  Future<ui.Image?> _captureCurrentFrame() async {
    try {
      // Wait for paint in all build modes. debugNeedsPaint is assert-only and
      // throws in profile/release; a zero-delay timer does not await paint.
      await SchedulerBinding.instance.endOfFrame;
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
          key: _captureKey,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = widget.curve.transform(_controller.value);
              final active = _outgoingImage != null && widget.enabled;

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
                          child ?? const SizedBox.shrink(),
                          if (active && !_preparing)
                            Align(
                              alignment: _forward
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              child: IgnorePointer(
                                child: Container(
                                  width: 22,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: _forward
                                          ? Alignment.centerLeft
                                          : Alignment.centerRight,
                                      end: _forward
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      colors: const [
                                        Color(0x22000000),
                                        Color(0x00000000),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (active)
                      Transform.translate(
                        offset: Offset(_preparing ? 0 : outgoingX, 0),
                        child: RawImage(
                          image: _outgoingImage,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                  ],
                ),
              );
            },
            // Moving the live page must not repaint its text on every animation
            // tick. Navigation can repaint this boundary independently.
            child: RepaintBoundary(child: widget.child),
          ),
        ),
      ),
    );
  }
}
