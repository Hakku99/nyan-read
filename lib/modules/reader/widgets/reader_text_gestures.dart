import 'package:flutter/widgets.dart';

/// Mounted selection ownership only; never stores reading position or text.
class ReaderTextSelectionRegistry {
  final _owners = <Object>{};
  int _inputEpoch = 0;
  int get inputEpoch => _inputEpoch;
  void beginInput() => _inputEpoch++;
  bool get hasSelection => _owners.isNotEmpty;
  void update(Object owner, bool selected) {
    if (selected) {
      _owners.add(owner);
    } else {
      _owners.remove(owner);
    }
  }
}

/// Routes a text recognizer's winning drag to the reader without competing
/// against that same recognizer in a parent gesture arena.
class ReaderTextGestures extends InheritedWidget {
  const ReaderTextGestures({
    super.key,
    required this.horizontal,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    this.isTurnZone,
    this.selections,
    this.onCenterInteraction,
    required super.child,
  });

  final bool horizontal;
  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;
  final bool Function(Offset position)? isTurnZone;
  final ReaderTextSelectionRegistry? selections;
  final VoidCallback? onCenterInteraction;

  static ReaderTextGestures? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReaderTextGestures>();

  @override
  bool updateShouldNotify(ReaderTextGestures oldWidget) =>
      horizontal != oldWidget.horizontal ||
      onStart != oldWidget.onStart ||
      onUpdate != oldWidget.onUpdate ||
      onEnd != oldWidget.onEnd ||
      isTurnZone != oldWidget.isTurnZone ||
      selections != oldWidget.selections ||
      onCenterInteraction != oldWidget.onCenterInteraction;
}
