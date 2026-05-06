part of 'reader_page.dart';

extension _ReaderPageGestureHandler on _ReaderPageState {
  void _handleTapDown(BuildContext context, TapDownDetails details) {
    _tapDownPosition = details.globalPosition;
    _panStartPosition = details.globalPosition;
    _isPanning = false;
  }

  void _handleTapUp(BuildContext context, TapUpDetails details) {
    final controller = _boundController;
    if (controller != null &&
        controller.settingsManager.preferences.pageTurnMode ==
            PageTurnMode.leftRight) {
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
        PageTurnMode.leftRight) {
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
    if (turnMode == PageTurnMode.leftRight) {
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
      _triggerPageTurn(c, forward: false, at: now);
    } else if (ratioY > 0.60) {
      _triggerPageTurn(c, forward: true, at: now);
    } else {
      _showReaderControls(context, c);
    }
  }

  void _handleSwipeLogic(DragEndDetails details) {
    final controller = _boundController;
    final start = _panStartPosition;
    final end = _panLastPosition;
    if (controller == null || start == null || end == null) return;

    final delta = end - start;
    if (delta.distance < _ReaderPageState._swipeThreshold) return;

    final now = DateTime.now();
    final mode = controller.settingsManager.preferences.pageTurnMode;
    final velocity = details.velocity.pixelsPerSecond;

    if (mode == PageTurnMode.leftRight) {
      final isMostlyHorizontal = delta.dx.abs() > delta.dy.abs();
      if (!isMostlyHorizontal) return;
      final dx = velocity.dx.abs() > 50 ? velocity.dx : delta.dx;
      if (dx < 0) {
        _triggerPageTurn(controller, forward: true, at: now);
      } else if (dx > 0) {
        _triggerPageTurn(controller, forward: false, at: now);
      }
      return;
    }

    final isMostlyVertical = delta.dy.abs() > delta.dx.abs();
    if (!isMostlyVertical) return;
    final dy = velocity.dy.abs() > 50 ? velocity.dy : delta.dy;
    if (dy < 0) {
      _triggerPageTurn(controller, forward: true, at: now);
    } else if (dy > 0) {
      _triggerPageTurn(controller, forward: false, at: now);
    }
  }

  void _triggerPageTurn(
    ReaderController controller, {
    required bool forward,
    required DateTime at,
  }) {
    if (_lastTapLogicAt != null &&
        at.difference(_lastTapLogicAt!) <
            _ReaderPageState._tapLogicDedupWindow) {
      return;
    }
    if (_isPageTurning) {
      return;
    }
    if (_lastPageTurnAt != null &&
        at.difference(_lastPageTurnAt!) <
            _ReaderPageState._pageTurnMinInterval) {
      return;
    }

    _lastTapLogicAt = at;
    _lastPageTurnAt = at;
    _isPageTurning = true;

    final turnFuture = _dispatchPageTurn(
      controller,
      forward: forward,
    );
    unawaited(turnFuture.whenComplete(() {
      if (!mounted) return;
      _isPageTurning = false;
    }));
  }

  void _showReaderControls(BuildContext context, ReaderController controller) {
    unawaited(_showQuickActionsBottomSheet(context, controller));
  }

  void _resetPanState() {
    _isPanning = false;
    _panStartPosition = null;
    _panLastPosition = null;
  }
}
