part of 'reader_page.dart';

extension _ReaderPageGestureHandler on _ReaderPageState {
  void _handleTapDown(BuildContext context, TapDownDetails details) {
    _tapDownPosition = details.globalPosition;
    _panStartPosition = details.globalPosition;
    _isPanning = false;
  }

  void _handleTapUp(BuildContext context, TapUpDetails details) {
    if (!_isPanning && _tapDownPosition != null) {
      _handleTapLogic(context, details.globalPosition);
    }
    _resetPanState();
  }

  void _handlePanStart(BuildContext context, DragStartDetails details) {
    _tapDownPosition = details.globalPosition;
    _panStartPosition = details.globalPosition;
    _isPanning = false;
  }

  void _handlePanUpdate(BuildContext context, DragUpdateDetails details) {
    if (_panStartPosition != null) {
      final distance = (details.globalPosition - _panStartPosition!).distance;
      if (distance > _ReaderPageState._swipeThreshold) {
        _isPanning = true;
      }
    }
  }

  void _handlePanEnd(BuildContext context, DragEndDetails details) {
    _resetPanState();
  }

  void _handleContentTap(
    BuildContext context,
    Offset globalPosition,
    ReaderController controller,
  ) {
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
    double localY;

    if (box != null && box.hasSize) {
      height = box.size.height;
      localY = box.globalToLocal(globalPosition).dy;
    } else {
      height = MediaQuery.sizeOf(context).height;
      localY = globalPosition.dy;
    }

    if (height <= 0) return;

    final now = DateTime.now();
    final ratio = localY / height;
    if (ratio < 0.40) {
      _triggerPageTurn(c, forward: false, at: now);
    } else if (ratio > 0.60) {
      _triggerPageTurn(c, forward: true, at: now);
    } else {
      _showReaderControls(context, c);
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

    final turnFuture =
        forward ? controller.nextPage() : controller.previousPage();
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
  }
}
