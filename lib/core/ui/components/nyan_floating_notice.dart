import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/nyan_spacing.dart';
import 'nyan_overlay_style.dart';

enum NyanFloatingNoticeTone { info, success, error }

class NyanFloatingNotice extends StatelessWidget {
  const NyanFloatingNotice({
    super.key,
    required this.message,
    required this.icon,
    this.tone = NyanFloatingNoticeTone.info,
    this.maxLines = 2,
  });

  final String message;
  final IconData icon;
  final NyanFloatingNoticeTone tone;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = NyanOverlayStyle.tonePalette(
      context,
      switch (tone) {
        NyanFloatingNoticeTone.info => NyanOverlayTone.info,
        NyanFloatingNoticeTone.success => NyanOverlayTone.success,
        NyanFloatingNoticeTone.error => NyanOverlayTone.danger,
      },
    );
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = math.min(
      screenWidth * NyanOverlayStyle.noticeMaxWidthFactor,
      NyanOverlayStyle.noticeMaxWidthCap,
    );

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: NyanOverlayStyle.creamSurface(context),
            borderRadius: BorderRadius.circular(NyanOverlayStyle.toastRadius),
            border: Border.all(
              color: tone == NyanFloatingNoticeTone.error
                  ? NyanOverlayStyle.destructiveSubtleBorder(context)
                  : NyanOverlayStyle.divider(context, alpha: 0.22),
              width: 0.7,
            ),
            boxShadow: NyanOverlayStyle.noticeShadow(context),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 17,
              vertical: 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NoticeBadge(icon: icon, tone: tone, palette: palette),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    message,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.16,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.91),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NyanFloatingNoticeOverlay extends StatefulWidget {
  const NyanFloatingNoticeOverlay({
    super.key,
    required this.message,
    required this.icon,
    required this.bottomOffset,
    required this.duration,
    required this.onClosed,
    this.tone = NyanFloatingNoticeTone.info,
    this.maxLines = 2,
  });

  final String message;
  final IconData icon;
  final double bottomOffset;
  final Duration duration;
  final VoidCallback onClosed;
  final NyanFloatingNoticeTone tone;
  final int maxLines;

  @override
  State<NyanFloatingNoticeOverlay> createState() =>
      _NyanFloatingNoticeOverlayState();
}

class _NyanFloatingNoticeOverlayState extends State<NyanFloatingNoticeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NyanOverlayStyle.noticeEnterDuration,
    reverseDuration: NyanOverlayStyle.noticeExitDuration,
  );
  late final CurvedAnimation _opacity = CurvedAnimation(
    parent: _controller,
    curve: NyanOverlayStyle.overlayFadeCurve,
    reverseCurve: Curves.easeIn,
  );
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(0, 0.18),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: NyanOverlayStyle.overlayCurve,
      reverseCurve: Curves.easeInCubic,
    ),
  );

  Timer? _timer;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, dismiss);
  }

  Future<void> dismiss() async {
    if (_isClosing) return;
    _isClosing = true;
    _timer?.cancel();
    await _controller.reverse();
    if (mounted) {
      widget.onClosed();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: NyanSpacing.space16,
              right: NyanSpacing.space16,
              bottom: widget.bottomOffset,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FadeTransition(
                opacity: _opacity,
                child: SlideTransition(
                  position: _offset,
                  child: NyanFloatingNotice(
                    message: widget.message,
                    icon: widget.icon,
                    tone: widget.tone,
                    maxLines: widget.maxLines,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeBadge extends StatelessWidget {
  const _NoticeBadge({
    required this.icon,
    required this.tone,
    required this.palette,
  });

  final IconData icon;
  final NyanFloatingNoticeTone tone;
  final NyanOverlayTonePalette palette;

  @override
  Widget build(BuildContext context) {
    final iconColor = switch (tone) {
      NyanFloatingNoticeTone.success => NyanOverlayStyle.successNoticeIcon(context),
      NyanFloatingNoticeTone.error => NyanOverlayStyle.destructiveText(context),
      NyanFloatingNoticeTone.info => NyanOverlayStyle.brandOlive(context),
    };
    final backgroundColor = tone == NyanFloatingNoticeTone.error
        ? NyanOverlayStyle.destructiveSubtleBackground(context)
        : NyanOverlayStyle.recessedSurface(
            context,
            seed: NyanOverlayStyle.brandOlive(context),
            strength: 0.04,
          );
    final borderColor = tone == NyanFloatingNoticeTone.error
        ? NyanOverlayStyle.destructiveSubtleBorder(context)
        : palette.border.withValues(alpha: 0.24);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: borderColor, width: 0.65),
      ),
      child: SizedBox(
        width: 22,
        height: 22,
        child: Icon(
          icon,
          size: 15,
          color: iconColor.withValues(alpha: 0.94),
        ),
      ),
    );
  }
}