import 'package:flutter/widgets.dart';

/// Routes a text recognizer's winning drag to the reader without competing
/// against that same recognizer in a parent gesture arena.
class ReaderTextGestures extends InheritedWidget {
  const ReaderTextGestures({
    super.key,
    required this.horizontal,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required super.child,
  });

  final bool horizontal;
  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;

  static ReaderTextGestures? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReaderTextGestures>();

  @override
  bool updateShouldNotify(ReaderTextGestures oldWidget) =>
      horizontal != oldWidget.horizontal ||
      onStart != oldWidget.onStart ||
      onUpdate != oldWidget.onUpdate ||
      onEnd != oldWidget.onEnd;
}
