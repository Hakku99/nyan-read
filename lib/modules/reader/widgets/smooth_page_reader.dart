import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

class SmoothPageReader extends StatefulWidget {
  const SmoothPageReader({
    super.key,
    required this.child,
    required this.onPreviousTap,
    required this.onNextTap,
    required this.onCenterTap,
    this.enabled = true,
    this.duration = const Duration(milliseconds: 360),
    this.curve = Curves.easeInOutCubic,
  });

  final bool enabled;
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
  int _interactionEpoch = 0;
  bool _forward = true;
  ui.Image? _outgoingImage;
  bool _isAnimating = false;

  bool get isAnimating => _isAnimating;

  @override
  void didUpdateWidget(covariant SmoothPageReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _interactionEpoch++;
      if (!widget.enabled) _controller.stop(canceled: true);
    }
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
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
  }) async {
    if (!mounted || _isAnimating || !widget.enabled) return;
    final epoch = _interactionEpoch;
    // Reserve the turn before capture yields, so concurrent inputs cannot
    // capture and dispatch the same outgoing page twice.
    _isAnimating = true;
    Future<void>? dispatch;
    Object? dispatchError;
    StackTrace? dispatchStack;
    void runDispatchOnce() {
      if (dispatch != null || !mounted || epoch != _interactionEpoch) return;
      // Observe failures immediately; rethrow to the caller after animation.
      dispatch = Future<void>.sync(dispatchTurn).then<void>((_) {},
          onError: (Object error, StackTrace stack) {
        dispatchError = error;
        dispatchStack = stack;
      });
    }

    void progressListener() {
      if (_controller.value >= 0.5) runDispatchOnce();
    }

    var listening = false;
    try {
      final captured = await _captureCurrentFrame();
      if (!mounted || epoch != _interactionEpoch) {
        captured?.dispose();
        return;
      }
      _outgoingImage = captured;
      _forward = forward;
      if (captured != null) {
        setState(() {});
        _controller.addListener(progressListener);
        listening = true;
        try {
          await _controller.forward(from: 0).orCancel;
        } on TickerCanceled {
          // Disposal cancels an in-flight animation without dispatching a new
          // navigation against a reader that is no longer mounted.
        }
      }
      runDispatchOnce();
      if (dispatch != null) await dispatch;
      if (dispatchError != null) {
        Error.throwWithStackTrace(dispatchError!, dispatchStack!);
      }
    } finally {
      if (listening) _controller.removeListener(progressListener);
      _isAnimating = false;
      _outgoingImage?.dispose();
      _outgoingImage = null;
      if (mounted) {
        setState(() {});
      }
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
    return GestureDetector(
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
                  if (active)
                    Transform.translate(
                      offset: Offset(outgoingX, 0),
                      child: RawImage(
                        image: _outgoingImage,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  // The live reader stays at one keyed location through capture,
                  // animation, cancellation and mode changes.
                  Transform.translate(
                    key: const ValueKey('live-reader'),
                    offset: Offset(active ? incomingX : 0, 0),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        child ?? const SizedBox.shrink(),
                        if (active)
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
                ],
              ),
            );
          },
          // Moving the live page must not repaint its text on every animation
          // tick. Navigation can repaint this boundary independently.
          child: RepaintBoundary(child: widget.child),
        ),
      ),
    );
  }
}
