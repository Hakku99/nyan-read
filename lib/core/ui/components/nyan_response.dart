import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_shadows.dart';
import '../../theme/nyan_spacing.dart';
import '../../theme/nyan_typography.dart';
import '../../theme/theme_presets.dart';
import '../nyan_icons.dart';
import '../nyan_theme_context.dart';

/// The single shared "what just happened" surface — shown after any action
/// completes, fails, is skipped, or is mid-flight. One card for the whole app
/// so confirmations read the same everywhere.
///
/// Floating-chrome doctrine (AGENTS.md §4.3): a rounded [NyanRadius.cardNested]
/// card on [NyanTheme.surface], lifted on [NyanShadows.subtle] (the token
/// reserved for toasts), inset [NyanSpacing.space12] from the edges, no scrim.
///
/// Source of truth: `.design/project/components/surfaces/NyanResponse.jsx`.
enum NyanResponseStatus { success, error, skipped, info, loading }

// ── Component-internal metrics ───────────────────────────────────────────────
// These sit off the standard spacing/size ladders by design (§4.6 delivery
// package priority); they are confined to this one surface.
//
// Source: `NyanResponse.jsx` — `padding: "10px 12px"`, `minHeight: 56`,
// title→description `marginTop: 2`, icon tile `36×36`, glyph `fontSize: 20`,
// dismiss button `32×32` with `fontSize: 16`.
const double _kCardPaddingV = 10.0;
const double _kMinHeight = 56.0;
const double _kTitleDescGap = 2.0;
const double _kIconTileSize = 36.0;
const double _kIconGlyphSize = 20.0;
const double _kDismissButtonSize = 32.0;
const double _kDismissGlyphSize = 16.0;

/// On wide screens the card stops stretching and floats centered; on phones the
/// 12pt insets win and it spans the width (full-bleed minus inset, per spec).
const double _kMaxWidth = 480.0;

const Duration _kSpinDuration = Duration(milliseconds: 900);

// ── Internal payload (private to this file) ──────────────────────────────────

class _ToastPayload {
  const _ToastPayload({
    required this.status,
    required this.title,
    this.description,
    required this.duration,
    this.maxLines = 2,
    this.actionLabel,
    this.onActionTap,
  });

  final NyanResponseStatus status;
  final String title;
  final String? description;
  final Duration duration;
  final int maxLines;

  /// Optional inline action label (e.g. "Undo"). When non-null, a tappable
  /// label chip is shown on the trailing edge of the toast card.
  final String? actionLabel;
  final VoidCallback? onActionTap;
}

// ── Controller ────────────────────────────────────────────────────────────────

/// Drives a live [NyanResponseOverlay]: call [replace] to swap content without
/// tearing down the overlay entry, or [triggerDismiss] to animate it away.
///
/// Created and owned by [SnackBarUtils]; the overlay reads from it via package-
/// private [ValueNotifier] fields (same file, so private is accessible).
class NyanToastController {
  NyanToastController({
    required NyanResponseStatus status,
    required String title,
    String? description,
    required Duration duration,
    int maxLines = 2,
    String? actionLabel,
    VoidCallback? onActionTap,
  }) : _payloadNotifier = ValueNotifier<_ToastPayload>(
          _ToastPayload(
            status: status,
            title: title,
            description: description,
            duration: duration,
            maxLines: maxLines,
            actionLabel: actionLabel,
            onActionTap: onActionTap,
          ),
        );

  final ValueNotifier<_ToastPayload> _payloadNotifier;
  final ValueNotifier<bool> _dismissNotifier = ValueNotifier<bool>(false);

  /// Swaps the displayed content in-place; the card container does not move.
  void replace({
    required NyanResponseStatus status,
    required String title,
    String? description,
    required Duration duration,
    int maxLines = 2,
    String? actionLabel,
    VoidCallback? onActionTap,
  }) {
    if (_dismissNotifier.value) return;
    _payloadNotifier.value = _ToastPayload(
      status: status,
      title: title,
      description: description,
      duration: duration,
      maxLines: maxLines,
      actionLabel: actionLabel,
      onActionTap: onActionTap,
    );
  }

  /// Starts the card's exit animation. Safe to call more than once.
  void triggerDismiss() {
    if (!_dismissNotifier.value) _dismissNotifier.value = true;
  }

  void dispose() {
    _payloadNotifier.dispose();
    _dismissNotifier.dispose();
  }
}

// ── Static display widget ─────────────────────────────────────────────────────

class _StatusVisual {
  const _StatusVisual({
    required this.icon,
    required this.spin,
    required this.foreground,
    required this.tile,
  });

  final IconData icon;
  final bool spin;
  final Color foreground;
  final Color tile;
}

_StatusVisual _statusVisual(NyanResponseStatus status, NyanTheme nyan) {
  switch (status) {
    case NyanResponseStatus.success:
      return _StatusVisual(
        icon: NyanIcons.checkCircle,
        spin: false,
        foreground: nyan.successColor,
        tile: Color.lerp(nyan.surface, nyan.successColor, 0.13)!,
      );
    case NyanResponseStatus.error:
      return _StatusVisual(
        icon: NyanIcons.error,
        spin: false,
        foreground: nyan.errorPrimaryTextColor,
        tile: nyan.errorBackgroundColor,
      );
    case NyanResponseStatus.skipped:
      return _StatusVisual(
        icon: NyanIcons.skipNext,
        spin: false,
        foreground: nyan.textMuted,
        tile: nyan.surfaceMuted,
      );
    case NyanResponseStatus.info:
      return _StatusVisual(
        icon: NyanIcons.info,
        spin: false,
        foreground: nyan.infoColor,
        tile: Color.lerp(nyan.surface, nyan.infoColor, 0.13)!,
      );
    case NyanResponseStatus.loading:
      return _StatusVisual(
        icon: NyanIcons.circleNotch,
        spin: true,
        foreground: nyan.primary,
        tile: Color.lerp(nyan.surface, nyan.primary, 0.12)!,
      );
  }
}

/// The static display card; consumed by [NyanResponseOverlay] and usable
/// stand-alone in tests or static contexts.
class NyanResponse extends StatelessWidget {
  const NyanResponse({
    super.key,
    required this.status,
    required this.title,
    this.description,
    this.onDismiss,
    this.actionLabel,
    this.onActionTap,
    this.maxLines = 2,
  });

  final NyanResponseStatus status;
  final String title;
  final String? description;

  /// When non-null, a quiet ✕ is shown. The app's timed path leaves this null.
  final VoidCallback? onDismiss;

  /// Optional inline action label (e.g. "Undo"). When non-null, a tappable
  /// label chip is shown on the trailing edge of the card.
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final isDark = nyan.brightness == Brightness.dark;
    final visual = _statusVisual(status, nyan);
    final hasDescription = description != null && description!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kMinHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: nyan.surface,
            borderRadius: BorderRadius.circular(NyanRadius.cardNested),
            border: Border.all(
              color: isDark ? nyan.divider : Colors.transparent,
              width: 1,
            ),
            boxShadow: NyanShadows.subtle(nyan),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NyanSpacing.space12,
              vertical: _kCardPaddingV,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ResponseIconTile(visual: visual),
                const SizedBox(width: NyanSpacing.space12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: hasDescription ? 1 : maxLines,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: NyanTypography.uiFontFamily,
                          fontSize: NyanTypography.responseTitle,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: nyan.textPrimary,
                        ),
                      ),
                      if (hasDescription) ...[
                        const SizedBox(height: _kTitleDescGap),
                        Text(
                          description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: NyanTypography.uiFontFamily,
                            fontSize: NyanTypography.responseDescription,
                            fontWeight: FontWeight.w400,
                            height: 1.35,
                            color: nyan.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(width: NyanSpacing.space8),
                  _ActionButton(label: actionLabel!, onTap: onActionTap),
                ],
                if (onDismiss != null) ...[
                  const SizedBox(width: NyanSpacing.space8),
                  _DismissButton(onDismiss: onDismiss!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResponseIconTile extends StatefulWidget {
  const _ResponseIconTile({required this.visual});

  final _StatusVisual visual;

  @override
  State<_ResponseIconTile> createState() => _ResponseIconTileState();
}

class _ResponseIconTileState extends State<_ResponseIconTile>
    with SingleTickerProviderStateMixin {
  AnimationController? _spin;

  @override
  void initState() {
    super.initState();
    if (widget.visual.spin) {
      _spin = AnimationController(vsync: this, duration: _kSpinDuration)
        ..repeat();
    }
  }

  @override
  void didUpdateWidget(_ResponseIconTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visual.spin == oldWidget.visual.spin) return;
    if (widget.visual.spin) {
      _spin = AnimationController(vsync: this, duration: _kSpinDuration)
        ..repeat();
    } else {
      _spin?.dispose();
      _spin = null;
    }
  }

  @override
  void dispose() {
    _spin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visual = widget.visual;
    Widget glyph = Icon(visual.icon, size: _kIconGlyphSize, color: visual.foreground);
    if (_spin != null) {
      glyph = RotationTransition(turns: _spin!, child: glyph);
    }

    return Container(
      width: _kIconTileSize,
      height: _kIconTileSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: visual.tile,
        borderRadius: BorderRadius.circular(NyanRadius.chip),
      ),
      child: glyph,
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    return InkWell(
      onTap: onDismiss,
      borderRadius: BorderRadius.circular(NyanRadius.chip),
      child: SizedBox(
        width: _kDismissButtonSize,
        height: _kDismissButtonSize,
        child: Icon(NyanIcons.close, size: _kDismissGlyphSize, color: nyan.textMuted),
      ),
    );
  }
}

/// Inline action chip — "Undo", "Retry", etc. — shown on the toast trailing edge.
/// Source: `screens/bundle3.jsx` phase="deleted": `action={{ label: "Undo" }}`.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: nyan.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(NyanRadius.chip),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: NyanTypography.uiFontFamily,
            fontSize: NyanTypography.meta,
            fontWeight: FontWeight.w600,
            height: 1.0,
            color: nyan.primaryDeep,
          ),
        ),
      ),
    );
  }
}

// ── Overlay host ──────────────────────────────────────────────────────────────

/// Persistent overlay host driven by a [NyanToastController].
///
/// The card container (background, shadow, border-radius, position) is static
/// for the lifetime of this widget. Only the inner content crossfades when
/// [NyanToastController.replace] is called, so successive toasts feel like a
/// seamless in-place update rather than a flash of two separate cards.
class NyanResponseOverlay extends StatefulWidget {
  const NyanResponseOverlay({
    super.key,
    required this.controller,
    required this.bottomOffset,
    required this.onClosed,
  });

  final NyanToastController controller;
  final double bottomOffset;
  final VoidCallback onClosed;

  @override
  State<NyanResponseOverlay> createState() => _NyanResponseOverlayState();
}

class _NyanResponseOverlayState extends State<NyanResponseOverlay>
    with SingleTickerProviderStateMixin {
  // Card enter / exit — runs once per overlay lifetime.
  late final AnimationController _cardCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 160),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _cardCtrl,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.22),
    end: Offset.zero,
  ).animate(_fade);

  Timer? _timer;
  bool _exiting = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _cardCtrl.forward();
    _scheduleTimer(widget.controller._payloadNotifier.value.duration);
    widget.controller._payloadNotifier.addListener(_onPayloadReplaced);
    widget.controller._dismissNotifier.addListener(_onDismissRequested);
  }

  void _onPayloadReplaced() {
    if (_exiting) return;
    // Content crossfade is driven by ValueListenableBuilder; we only reset the
    // auto-dismiss timer here.
    _timer?.cancel();
    _scheduleTimer(widget.controller._payloadNotifier.value.duration);
  }

  void _onDismissRequested() {
    if (widget.controller._dismissNotifier.value) _beginExit();
  }

  void _scheduleTimer(Duration d) {
    _timer = Timer(d, _beginExit);
  }

  Future<void> _beginExit() async {
    if (_exiting || _isDragging) return;
    _exiting = true;
    _timer?.cancel();
    await _cardCtrl.reverse();
    if (mounted) widget.onClosed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cardCtrl.dispose();
    widget.controller._payloadNotifier.removeListener(_onPayloadReplaced);
    widget.controller._dismissNotifier.removeListener(_onDismissRequested);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = math.min(screenWidth, _kMaxWidth);

    // The transparent area above the card must not absorb touches — only the
    // card itself should be interactive (for the dismiss button). Column puts
    // IgnorePointer only on the spacer row, leaving the card fully hittable.
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: NyanSpacing.space12,
            right: NyanSpacing.space12,
            bottom: widget.bottomOffset,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Expanded(child: IgnorePointer(child: SizedBox.expand())),
              Dismissible(
                key: const ValueKey('nyan-toast'),
                direction: DismissDirection.horizontal,
                // Transparent backgrounds so no colour bleeds in during the swipe.
                background: const SizedBox.shrink(),
                secondaryBackground: const SizedBox.shrink(),
                onUpdate: (details) {
                  final dragging = details.progress > 0 && !details.reached;
                  if (dragging && !_isDragging) {
                    // Drag started — pause auto-dismiss timer.
                    _isDragging = true;
                    _timer?.cancel();
                    _timer = null;
                  } else if (!dragging && _isDragging && !details.reached) {
                    // Snapped back — reschedule remaining duration.
                    _isDragging = false;
                    if (!_exiting) {
                      _scheduleTimer(
                          widget.controller._payloadNotifier.value.duration);
                    }
                  }
                },
                onDismissed: (_) {
                  _timer?.cancel();
                  if (!_exiting) {
                    _exiting = true;
                    widget.onClosed();
                  }
                },
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      // Card shell is static — only the content inside crossfades.
                      child: _CardShell(controller: widget.controller),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The outer card decoration (surface, shadow, border, radius). Stateless and
/// never rebuilt during content replacements — only its [_CardContent] child
/// is swapped via [AnimatedSwitcher].
class _CardShell extends StatefulWidget {
  const _CardShell({required this.controller});

  final NyanToastController controller;

  @override
  State<_CardShell> createState() => _CardShellState();
}

class _CardShellState extends State<_CardShell>
    with SingleTickerProviderStateMixin {
  // Fade out (reverse) is faster than fade in (forward) so the swap feels snappy.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    value: 1.0,
    duration: const Duration(milliseconds: 120),   // fade in
    reverseDuration: const Duration(milliseconds: 70), // fade out
  );

  late _ToastPayload _shown;
  VoidCallback? _shownOnDismiss;
  bool _transitioning = false;

  @override
  void initState() {
    super.initState();
    _shown = widget.controller._payloadNotifier.value;
    _updateDismiss();
    widget.controller._payloadNotifier.addListener(_onPayloadChanged);
  }

  void _updateDismiss() {
    // Overlay-driven toasts always auto-dismiss via timer or programmatic
    // triggerDismiss() — the DS contract says "自动消失的 toast 省略 ✕".
    // The static NyanResponse widget still accepts onDismiss for persistent
    // surfaces; the overlay path never shows the × button.
    _shownOnDismiss = null;
  }

  Future<void> _onPayloadChanged() async {
    // If already mid-transition, jump straight to the latest value to avoid
    // a queued chain of fades when multiple replace() calls arrive quickly.
    if (_transitioning) {
      setState(() {
        _shown = widget.controller._payloadNotifier.value;
        _updateDismiss();
      });
      return;
    }
    _transitioning = true;

    await _fade.reverse(); // existing content fades out completely
    if (!mounted) return;

    setState(() {
      _shown = widget.controller._payloadNotifier.value;
      _updateDismiss();
    });

    await _fade.forward(); // new content fades in
    if (mounted) _transitioning = false;
  }

  @override
  void dispose() {
    widget.controller._payloadNotifier.removeListener(_onPayloadChanged);
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final isDark = nyan.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: nyan.surface,
          borderRadius: BorderRadius.circular(NyanRadius.cardNested),
          border: Border.all(
            color: isDark ? nyan.divider : Colors.transparent,
            width: 1,
          ),
          boxShadow: NyanShadows.subtle(nyan),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NyanSpacing.space12,
            vertical: _kCardPaddingV,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _kMinHeight - _kCardPaddingV * 2),
            // Only one _CardContent is ever in the tree; the FadeTransition
            // fades it out, setState swaps it, then fades it in — no layout
            // shift from two overlapping children.
            child: FadeTransition(
              opacity: _fade,
              child: _CardContent(
                payload: _shown,
                onDismiss: _shownOnDismiss,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.payload,
    this.onDismiss,
  });

  final _ToastPayload payload;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final visual = _statusVisual(payload.status, nyan);
    final hasDescription =
        payload.description != null && payload.description!.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ResponseIconTile(visual: visual),
        const SizedBox(width: NyanSpacing.space12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payload.title,
                maxLines: hasDescription ? 1 : payload.maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  fontSize: NyanTypography.responseTitle,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: nyan.textPrimary,
                ),
              ),
              if (hasDescription) ...[
                const SizedBox(height: _kTitleDescGap),
                Text(
                  payload.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: NyanTypography.responseDescription,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                    color: nyan.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (payload.actionLabel != null) ...[
          const SizedBox(width: NyanSpacing.space8),
          _ActionButton(label: payload.actionLabel!, onTap: payload.onActionTap),
        ],
        if (onDismiss != null) ...[
          const SizedBox(width: NyanSpacing.space8),
          _DismissButton(onDismiss: onDismiss!),
        ],
      ],
    );
  }
}
