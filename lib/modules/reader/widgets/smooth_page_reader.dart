import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class SmoothPageReader extends StatefulWidget {
  const SmoothPageReader({
    super.key,
    required this.child,
    required this.onPreviousTap,
    required this.onNextTap,
    required this.onCenterTap,
    this.duration = const Duration(milliseconds: 360),
    this.curve = Curves.easeInOutCubic,
  });

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
  bool _forward = true;
  ui.Image? _outgoingImage;
  bool _isAnimating = false;

  bool get isAnimating => _isAnimating;

  @override
  void didUpdateWidget(covariant SmoothPageReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _outgoingImage?.dispose();
    super.dispose();
  }

  void handleExternalTap(Offset globalPosition) {
    _handleTap(TapUpDetails(
      globalPosition: globalPosition,
      kind: PointerDeviceKind.touch,
    ));
  }

  void _handleTap(TapUpDetails details) {
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
    if (_isAnimating) return;

    final captured = await _captureCurrentFrame();
    if (!mounted) return;
    _outgoingImage?.dispose();
    _outgoingImage = captured;
    _forward = forward;
    _isAnimating = true;
    setState(() {});

    var didDispatch = false;
    final dispatchDone = Completer<void>();

    Future<void> runDispatchOnce() async {
      if (didDispatch) return;
      didDispatch = true;
      try {
        await dispatchTurn();
      } finally {
        if (!dispatchDone.isCompleted) {
          dispatchDone.complete();
        }
      }
    }

    void progressListener() {
      if (_controller.value >= 0.5 && !didDispatch) {
        unawaited(runDispatchOnce());
      }
    }

    _controller.addListener(progressListener);
    try {
      if (!mounted) return;
      await _controller.forward(from: 0);
      if (!didDispatch) {
        await runDispatchOnce();
      }
      await dispatchDone.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    } finally {
      _controller.removeListener(progressListener);
      _isAnimating = false;
      _outgoingImage?.dispose();
      _outgoingImage = null;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<ui.Image?> _captureCurrentFrame() async {
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final boundary =
        _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || boundary.debugNeedsPaint) {
      await Future<void>.delayed(Duration.zero);
    }
    final readyBoundary =
        _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (readyBoundary == null) return null;
    return readyBoundary.toImage(pixelRatio: pixelRatio);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _handleTap,
      child: RepaintBoundary(
        key: _captureKey,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = widget.curve.transform(_controller.value);
            if (_outgoingImage == null) {
              return child ?? const SizedBox.shrink();
            }

            final width = MediaQuery.sizeOf(context).width;
            final outgoingX = _forward ? -t * width : t * width;
            final incomingX = _forward ? (1 - t) * width : -(1 - t) * width;

            return ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Transform.translate(
                    offset: Offset(outgoingX, 0),
                    child: RawImage(
                      image: _outgoingImage,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(incomingX, 0),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        child ?? const SizedBox.shrink(),
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
          child: widget.child,
        ),
      ),
    );
  }
}
