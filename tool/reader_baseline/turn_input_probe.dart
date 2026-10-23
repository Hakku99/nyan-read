// Development-only input probe, used by the full-app recovery harness.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/modules/reader/controllers/reader_controller.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';
import 'package:nyan_read/modules/reader/widgets/smooth_page_reader.dart';

int _pointer = 100;

Future<void> _pause(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

(SmoothPageReaderState, RenderBox) _reader() {
  (SmoothPageReaderState, RenderBox)? result;
  void visit(Element element) {
    if (element is StatefulElement && element.state is SmoothPageReaderState) {
      result = (
        element.state as SmoothPageReaderState,
        element.findRenderObject()! as RenderBox
      );
    }
    element.visitChildren(visit);
  }

  visit(WidgetsBinding.instance.rootElement!);
  return result ?? (throw StateError('Missing horizontal reader'));
}

Future<void> _tap(double x) async {
  final box = _reader().$2;
  final position =
      box.localToGlobal(Offset(box.size.width * x, box.size.height * .5));
  final pointer = _pointer++;
  GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(pointer: pointer, position: position));
  await _pause(15);
  GestureBinding.instance
      .handlePointerEvent(PointerUpEvent(pointer: pointer, position: position));
}

Future<void> _swipe({double startRatio = .98}) async {
  final box = _reader().$2;
  final start = box
      .localToGlobal(Offset(box.size.width * startRatio, box.size.height * .5));
  final pointer = _pointer++;
  GestureBinding.instance
      .handlePointerEvent(PointerDownEvent(pointer: pointer, position: start));
  var last = start;
  for (var i = 1; i <= 8; i++) {
    await _pause(20);
    final position = start.translate(-box.size.width * .65 * i / 8, 0);
    GestureBinding.instance.handlePointerEvent(PointerMoveEvent(
        pointer: pointer,
        position: position,
        delta: position - last,
        timeStamp: Duration(milliseconds: i * 20)));
    last = position;
  }
  GestureBinding.instance.handlePointerEvent(PointerUpEvent(
      pointer: pointer,
      position: last,
      timeStamp: const Duration(milliseconds: 180)));
}

void _same(ReadingPosition expected, ReadingPosition actual) {
  if (expected.paragraphIndex != actual.paragraphIndex ||
      expected.textOffset != actual.textOffset ||
      ((expected.paragraphLeadingEdge ?? 0) -
                  (actual.paragraphLeadingEdge ?? 0))
              .abs() >
          .005) {
    debugPrint('NYAN_TURN ${jsonEncode({
          'event': 'viewport-mismatch',
          'expected': [
            expected.paragraphIndex,
            expected.textOffset,
            expected.paragraphLeadingEdge
          ],
          'actual': [
            actual.paragraphIndex,
            actual.textOffset,
            actual.paragraphLeadingEdge
          ]
        })}');
    throw StateError('Input changed the expected viewport');
  }
}

Future<Map<String, Object>> verifyTurnInputs(
    ReaderController controller) async {
  controller.setPageTurnMode(PageTurnMode.tap);
  await _pause(800);
  if (!_reader().$1.widget.enabled) {
    throw StateError('Mode change did not reach the gesture surface');
  }
  final start = controller.currentPosition!;
  await _tap(.98);
  await _pause(1200);
  final next = controller.currentPosition!;
  if (next.toJson() == start.toJson()) throw StateError('Tap did not navigate');
  await _tap(.02);
  await _pause(1200);
  _same(start, controller.currentPosition!);
  // All inputs go through the real app's hit testing and gesture recognizers.
  for (var i = 0; i < 3; i++) {
    await _tap(.98);
    await _pause(30);
  }
  await _pause(1200);
  _same(next, controller.currentPosition!);
  await _tap(.02);
  await _pause(1200);
  _same(start, controller.currentPosition!);
  await _swipe();
  await _pause(1200);
  _same(next, controller.currentPosition!);
  await _tap(.02);
  await _pause(1200);
  await _tap(.98);
  await _pause(100);
  final accepted = controller.currentPosition!;
  controller.setPageTurnMode(PageTurnMode.swipe);
  await _pause(1200);
  if (_reader().$1.isAnimating) {
    throw StateError('Mode change left an active turn');
  }
  if (accepted.paragraphIndex != controller.currentPosition!.paragraphIndex ||
      accepted.textOffset != controller.currentPosition!.textOffset) {
    throw StateError('Mode cancellation changed the accepted anchor');
  }
  controller.setPageTurnMode(PageTurnMode.tap);
  await _pause(800);
  await _tap(.98);
  await _pause(100);
  final beforeOverlay = controller.currentPosition!;
  await _tap(.5);
  await _pause(1000);
  if (_reader().$1.isAnimating) throw StateError('Overlay left an active turn');
  _same(beforeOverlay, controller.currentPosition!);
  await _tap(.5);
  await _pause(800);
  // Keep the independently observed text-selection conflict visible in results.
  // It is distinct from input locking at the blank page-turn edge.
  await controller.handleBookmarkSelection({
    'position_type': controller.book.format,
    'position_payload': start.toJson(),
  });
  await _pause(400);
  _same(start, controller.currentPosition!);
  for (var i = 0; i < 3; i++) {
    await _tap(.94);
    await _pause(30);
  }
  await _pause(1200);
  final bodyAdvanced = controller.currentPosition!;
  var selectedFields = 0;
  void inspect(Element element) {
    final widget = element.widget;
    if (widget is EditableText && !widget.controller.selection.isCollapsed) {
      selectedFields++;
    }
    element.visitChildren(inspect);
  }

  inspect(WidgetsBinding.instance.rootElement!);
  await _tap(.06);
  await _pause(1200);
  var bodyRoundTrip = true;
  try {
    _same(next, bodyAdvanced);
    _same(start, controller.currentPosition!);
  } on StateError {
    bodyRoundTrip = false;
    debugPrint(
        'Reader input probe: body rapid-tap/selection conflict remains.');
  }
  await controller.handleBookmarkSelection({
    'position_type': controller.book.format,
    'position_payload': start.toJson(),
  });
  await _pause(400);
  _same(start, controller.currentPosition!);
  await _swipe(startRatio: .8);
  await _pause(1200);
  var bodySwipe = true;
  try {
    _same(next, controller.currentPosition!);
  } on StateError {
    bodySwipe = false;
    debugPrint(
        'Reader input probe: swipe starting on text remains unresolved.');
  }
  await controller.handleBookmarkSelection({
    'position_type': controller.book.format,
    'position_payload': start.toJson(),
  });
  await _pause(400);
  return {
    'bodyHorizontalSwipe': bodySwipe,
    'bodyRapidRoundTrip': bodyRoundTrip,
    'selectedTextFieldsAfterBodyBurst': selectedFields,
    'tapRoundTrip': true,
    'rapidThreeTapsOneTurn': true,
    'horizontalSwipe': true,
    'modeCancellation': true,
    'overlayCancellation': true
  };
}
