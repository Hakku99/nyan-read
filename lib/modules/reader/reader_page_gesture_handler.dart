part of 'reader_page.dart';

extension _ReaderPageGestureHandler on _ReaderPageState {
  void _handleTapDown(BuildContext context, TapDownDetails details) {
    _textSelections.beginInput();
    _tapDownPosition = details.globalPosition;
    _panStartPosition = details.globalPosition;
    _isPanning = false;
  }

  void _handleTapUp(BuildContext context, TapUpDetails details) {
    final controller = _boundController;
    if (controller != null &&
        controller.settingsManager.preferences.pageTurnMode ==
            PageTurnMode.tap) {
      _resetPanState();
      return;
    }
    if (!_isPanning && _tapDownPosition != null) {
      _handleTapLogic(context, details.globalPosition);
    }
    _resetPanState();
  }

  void _handlePanStart(BuildContext context, DragStartDetails details) {
    _tapDownPosition = details.globalPosition;
    _panStartPosition = details.globalPosition;
    _panLastPosition = details.globalPosition;
    _isPanning = false;
  }

  void _handlePanUpdate(BuildContext context, DragUpdateDetails details) {
    _panLastPosition = details.globalPosition;
    if (_panStartPosition != null) {
      final distance = (details.globalPosition - _panStartPosition!).distance;
      if (distance > _ReaderPageState._swipeThreshold) {
        _isPanning = true;
      }
    }
  }

  void _handlePanEnd(BuildContext context, DragEndDetails details) {
    if (_isPanning) {
      _handleSwipeLogic(details);
    }
    _resetPanState();
  }

  void _handleContentTap(
    BuildContext context,
    Offset globalPosition,
    ReaderController controller,
  ) {
    if (controller.settingsManager.preferences.pageTurnMode ==
        PageTurnMode.tap) {
      _smoothPageReaderKey.currentState?.handleExternalTap(globalPosition);
      return;
    }
    if (!_isPanning) {
      _handleTapLogic(context, globalPosition, controller: controller);
    }
  }

  void _scheduleDebouncedChapterSync(ReaderController controller) {
    _chapterSyncDebounce?.cancel();
    _chapterSyncDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      unawaited(controller.syncChapterAfterScroll());
    });
  }

  void _handleTapLogic(
    BuildContext context,
    Offset globalPosition, {
    ReaderController? controller,
  }) {
    final c = controller ?? _boundController;
    if (c == null) return;

    if (_isPanning) return;

    if (_showControls) {
      _setControlsVisible(false);
      return;
    }

    final box = _readerBodyKey.currentContext?.findRenderObject() as RenderBox?;
    final double height;
    final double width;
    double localY;
    double localX;

    if (box != null && box.hasSize) {
      height = box.size.height;
      width = box.size.width;
      localY = box.globalToLocal(globalPosition).dy;
      localX = box.globalToLocal(globalPosition).dx;
    } else {
      height = MediaQuery.sizeOf(context).height;
      width = MediaQuery.sizeOf(context).width;
      localY = globalPosition.dy;
      localX = globalPosition.dx;
    }

    if (height <= 0 || width <= 0) return;

    final now = DateTime.now();
    final turnMode = c.settingsManager.preferences.pageTurnMode;

    // Disabled mode: no tap-to-turn; any tap toggles the overlay instead.
    if (turnMode == PageTurnMode.disabled) {
      _showReaderControls(context, c);
      return;
    }

    if (turnMode == PageTurnMode.tap) {
      final ratioX = localX / width;
      if (ratioX < 0.20) {
        _triggerPageTurn(c, forward: false, at: now);
      } else if (ratioX > 0.80) {
        _triggerPageTurn(c, forward: true, at: now);
      } else {
        _showReaderControls(context, c);
      }
      return;
    }

    final ratioY = localY / height;
    if (ratioY < 0.40) {
      // Up/down mode expects top-tap and bottom-tap to move by symmetric
      // viewport distance; engine-level logic enforces that invariant.
      _triggerPageTurn(c, forward: false, at: now);
    } else if (ratioY > 0.60) {
      _triggerPageTurn(c, forward: true, at: now);
    } else {
      _showReaderControls(context, c);
    }
  }

  void _handleSwipeLogic(DragEndDetails details) {
    // A selection in any mounted paragraph owns dragging, including when the
    // parent recognizer wins on iOS or the pointer starts in paragraph padding.
    if (_textSelections.hasSelection) return;
    final controller = _boundController;
    final start = _panStartPosition;
    final end = _panLastPosition;
    if (controller == null || start == null || end == null) return;

    final delta = end - start;
    if (delta.distance < _ReaderPageState._swipeThreshold) return;

    final now = DateTime.now();
    final mode = controller.settingsManager.preferences.pageTurnMode;
    final velocity = details.velocity.pixelsPerSecond;

    // Disabled mode: swipe gestures do not turn pages.
    if (mode == PageTurnMode.disabled) return;

    if (mode == PageTurnMode.tap) {
      final isMostlyHorizontal = delta.dx.abs() > delta.dy.abs() * 1.5;
      if (!isMostlyHorizontal) return;
      final vx = velocity.dx.abs();
      final dx = delta.dx.abs();
      // Require either fast velocity or a deliberate large delta; slow drags
      // (e.g. text-selection) are suppressed.
      if (vx < _ReaderPageState._swipeMinVelocity &&
          dx < _ReaderPageState._swipeMinDelta) {
        return;
      }
      final signedDx =
          vx >= _ReaderPageState._swipeMinVelocity ? velocity.dx : delta.dx;
      if (signedDx < 0) {
        _triggerPageTurn(controller, forward: true, at: now);
      } else if (signedDx > 0) {
        _triggerPageTurn(controller, forward: false, at: now);
      }
      return;
    }

    final isMostlyVertical = delta.dy.abs() > delta.dx.abs() * 1.5;
    if (!isMostlyVertical) return;
    final vy = velocity.dy.abs();
    final dy = delta.dy.abs();
    if (vy < _ReaderPageState._swipeMinVelocity &&
        dy < _ReaderPageState._swipeMinDelta) {
      return;
    }
    final signedDy =
        vy >= _ReaderPageState._swipeMinVelocity ? velocity.dy : delta.dy;
    if (signedDy < 0) {
      _triggerPageTurn(controller, forward: true, at: now);
    } else if (signedDy > 0) {
      _triggerPageTurn(controller, forward: false, at: now);
    }
  }

  void _triggerPageTurn(
    ReaderController controller, {
    required bool forward,
    required DateTime at,
  }) {
    if (_textSelections.hasSelection) {
      FocusScope.of(context).unfocus();
      return;
    }
    if (!_pageTurnGate.offer(forward: forward, at: at)) return;
    _drainQueuedPageTurn(controller);
  }

  /// Starts the queued turn if the gate allows it; otherwise re-arms a timer
  /// for the interval, or waits for [_completePageTurn] to call back.
  void _drainQueuedPageTurn(ReaderController controller) {
    if (!mounted) return;
    final next = _pageTurnGate.take(DateTime.now());
    final forward = next.forward;
    if (forward == null) {
      if (next.retryAfter > Duration.zero) {
        _queuedPageTurnTimer?.cancel();
        _queuedPageTurnTimer =
            Timer(next.retryAfter, () => _drainQueuedPageTurn(controller));
      }
      return;
    }

    final request = _pageTurnRequest = PageTurnRequest();
    _pageTurnLockTimer?.cancel();
    _pageTurnLockTimer = Timer(_ReaderPageState._pageTurnLockTimeout, () {
      // Invalidate late capture/queued navigation before releasing input.
      request.cancel();
    });
    // The handler owns completion and user-visible failure feedback.
    unawaited(_completePageTurn(controller, forward, request));
  }

  Future<void> _completePageTurn(ReaderController controller, bool forward,
      PageTurnRequest request) async {
    var succeeded = false;
    try {
      await request.wait(
          _dispatchPageTurn(controller, forward: forward, request: request));
      succeeded = true;
    } on PageTurnCancelled {
      // A changed layout, route or deadline supersedes this presentation.
    } catch (error) {
      debugPrint('Reader page turn failed (${error.runtimeType}).');
      if (mounted) {
        SnackBarUtils.show(
            context, AppLocalizations.of(context)!.errorUnknownBody,
            tone: NyanSnackTone.error);
      }
    } finally {
      request.cancel();
      // A late completion cannot unlock a newer input or cancel its deadline,
      // nor touch the gate's notifier after dispose.
      if (mounted && identical(_pageTurnRequest, request)) {
        _pageTurnLockTimer?.cancel();
        _pageTurnRequest = null;
        _pageTurnGate.finish(succeeded: succeeded);
        _drainQueuedPageTurn(controller);
      }
    }
  }

  void _showReaderControls(BuildContext context, ReaderController controller) {
    _pageTurnGate.clearQueue();
    _pageTurnRequest?.cancel();
    unawaited(_showQuickActionsBottomSheet(context, controller));
  }

  void _resetPanState() {
    _isPanning = false;
    _panStartPosition = null;
    _panLastPosition = null;
  }
}
