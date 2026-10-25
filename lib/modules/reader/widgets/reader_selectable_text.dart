import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'reader_text_gestures.dart';

/// A read-only rich editable using Flutter's public selection builder. Owning
/// the builder lets touch drags navigate without disabling selection handles.
class ReaderSelectableText extends StatefulWidget {
  const ReaderSelectableText({
    super.key,
    required this.span,
    required this.style,
    required this.onSelectionChanged,
    required this.contextMenuBuilder,
  });

  final TextSpan span;
  final TextStyle style;
  final SelectionChangedCallback onSelectionChanged;
  final EditableTextContextMenuBuilder contextMenuBuilder;

  @override
  State<ReaderSelectableText> createState() => _ReaderSelectableTextState();
}

class _SpanController extends TextEditingController {
  _SpanController(this.span)
      : super(text: span.toPlainText(includeSemanticsLabels: false));
  TextSpan span;

  @override
  TextSpan buildTextSpan(
          {required BuildContext context,
          TextStyle? style,
          required bool withComposing}) =>
      TextSpan(style: style, children: [span]);
}

class _ReaderSelectableTextState extends State<ReaderSelectableText>
    implements TextSelectionGestureDetectorBuilderDelegate {
  @override
  final editableTextKey = GlobalKey<EditableTextState>();
  late final _controller = _SpanController(widget.span);
  final _focus = FocusNode(skipTraversal: true);
  late final _gestures = _ReaderSelectionBuilder(this);
  ReaderTextGestures? routing;
  bool _handles = false;

  @override
  bool get forcePressEnabled =>
      Theme.of(context).platform == TargetPlatform.iOS;
  @override
  bool get selectionEnabled => true;
  bool get hasSelection =>
      _controller.selection.isValid && !_controller.selection.isCollapsed;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (!_focus.hasFocus &&
        SchedulerBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _controller.selection = const TextSelection.collapsed(offset: -1);
      widget.onSelectionChanged(
          _controller.selection, SelectionChangedCause.tap);
      if (_handles) setState(() => _handles = false);
    }
  }

  @override
  void didUpdateWidget(ReaderSelectableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.span != oldWidget.span) {
      _controller.span = widget.span;
      final text = widget.span.toPlainText(includeSemanticsLabels: false);
      if (_controller.text != text) {
        _controller.value = TextEditingValue(text: text);
      }
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _selectionChanged(
      TextSelection selection, SelectionChangedCause? cause) {
    final handles = hasSelection &&
        cause != SelectionChangedCause.keyboard &&
        _gestures.shouldShowSelectionToolbar;
    if (_handles != handles) setState(() => _handles = handles);
    widget.onSelectionChanged(selection, cause);
    if (cause == SelectionChangedCause.longPress &&
        (Theme.of(context).platform == TargetPlatform.iOS ||
            Theme.of(context).platform == TargetPlatform.macOS)) {
      editableTextKey.currentState?.bringIntoView(selection.base);
    }
  }

  @override
  Widget build(BuildContext context) {
    routing = ReaderTextGestures.of(context);
    final theme = Theme.of(context);
    final defaults = DefaultTextStyle.of(context);
    final selection = DefaultSelectionStyle.of(context);
    final ios = theme.platform == TargetPlatform.iOS;
    final apple = ios || theme.platform == TargetPlatform.macOS;
    final controls = switch (theme.platform) {
      TargetPlatform.iOS => cupertinoTextSelectionHandleControls,
      TargetPlatform.macOS => cupertinoDesktopTextSelectionHandleControls,
      TargetPlatform.linux ||
      TargetPlatform.windows =>
        desktopTextSelectionHandleControls,
      _ => materialTextSelectionHandleControls,
    };
    return Semantics(
      onLongPress: _focus.requestFocus,
      child: _gestures.buildGestureDetector(
        behavior: HitTestBehavior.translucent,
        child: RepaintBoundary(
            child: EditableText(
          key: editableTextKey,
          controller: _controller,
          focusNode: _focus,
          style: defaults.style.merge(widget.style),
          readOnly: true,
          showCursor: false,
          forceLine: false,
          maxLines: defaults.maxLines,
          strutStyle: const StrutStyle(),
          textAlign: defaults.textAlign ?? TextAlign.start,
          textWidthBasis: defaults.textWidthBasis,
          textHeightBehavior: defaults.textHeightBehavior,
          rendererIgnoresPointer: true,
          showSelectionHandles: _handles,
          selectionControls: controls,
          selectionColor: selection.selectionColor ??
              theme.colorScheme.primary.withValues(alpha: .4),
          cursorColor: selection.cursorColor ?? theme.colorScheme.primary,
          backgroundCursorColor: theme.colorScheme.onSurface,
          paintCursorAboveText: apple,
          cursorOpacityAnimates: apple,
          cursorOffset: ios
              ? Offset(
                  iOSHorizontalOffset / MediaQuery.devicePixelRatioOf(context),
                  0)
              : null,
          magnifierConfiguration: TextMagnifier.adaptiveMagnifierConfiguration,
          onSelectionChanged: _selectionChanged,
          onSelectionHandleTapped: () {
            if (_controller.selection.isCollapsed) {
              editableTextKey.currentState?.toggleToolbar();
            }
          },
          contextMenuBuilder: widget.contextMenuBuilder,
          autofillHints: null,
        )),
      ),
    );
  }
}

class _ReaderSelectionBuilder extends TextSelectionGestureDetectorBuilder {
  _ReaderSelectionBuilder(this.owner) : super(delegate: owner);
  final _ReaderSelectableTextState owner;
  bool _selectedAtDown = false;
  ReaderTextGestures? _dragRoute;

  @override
  void onTapDown(TapDragDownDetails details) {
    _selectedAtDown = owner.hasSelection;
    super.onTapDown(details);
  }

  @override
  void onDragSelectionStart(TapDragStartDetails details) {
    final route = owner.routing;
    final touch = details.kind == PointerDeviceKind.touch;
    if (route?.horizontal == true &&
        touch &&
        !_selectedAtDown &&
        !owner.hasSelection &&
        details.consecutiveTapCount == 1) {
      _dragRoute = route;
      route!.onStart(DragStartDetails(
          globalPosition: details.globalPosition,
          localPosition: details.localPosition,
          kind: details.kind,
          sourceTimeStamp: details.sourceTimeStamp));
    } else {
      _dragRoute = null;
      super.onDragSelectionStart(details);
    }
  }

  @override
  void onDragSelectionUpdate(TapDragUpdateDetails details) {
    final route = _dragRoute;
    if (route != null) {
      if (owner.routing?.horizontal != true) return;
      route.onUpdate(DragUpdateDetails(
          globalPosition: details.globalPosition,
          localPosition: details.localPosition,
          delta: details.delta,
          sourceTimeStamp: details.sourceTimeStamp));
    } else {
      super.onDragSelectionUpdate(details);
    }
  }

  @override
  void onDragSelectionEnd(TapDragEndDetails details) {
    final route = _dragRoute;
    _dragRoute = null;
    if (route != null) {
      if (owner.routing?.horizontal == true) {
        route.onEnd(DragEndDetails(
            velocity: details.velocity,
            globalPosition: details.globalPosition,
            localPosition: details.localPosition));
      }
    } else {
      super.onDragSelectionEnd(details);
    }
  }
}
