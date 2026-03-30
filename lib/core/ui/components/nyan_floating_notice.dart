import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../nyan_theme_context.dart';
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
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          minHeight: NyanOverlayStyle.noticeMinHeight,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: NyanOverlayStyle.creamSurface(context),
            borderRadius: BorderRadius.circular(NyanOverlayStyle.toastRadius),
            border: Border.all(
              color: NyanOverlayStyle.divider(context, alpha: 0.18),
              width: 1,
            ),
            boxShadow: NyanOverlayStyle.noticeShadow(context),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NyanOverlayStyle.noticeHorizontalPadding,
              vertical: NyanOverlayStyle.noticeVerticalPadding,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NoticeBadge(icon: icon, tone: tone, palette: palette),
                const SizedBox(width: NyanOverlayStyle.noticeIconGap),
                Flexible(
                  child: Text(
                    message,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.18,
                      color: context.nyanTheme.textPrimary.withValues(alpha: 0.92),
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
    setState(() {
      _isClosing = true;
    });
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
              left: 16,
              right: 16,
              bottom: widget.bottomOffset,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final curve = _isClosing
                      ? Curves.easeInCubic.transform(_controller.value)
                      : Curves.easeOutCubic.transform(_controller.value);
                  final opacity = curve;
                  final translateY = _isClosing
                      ? (1 - curve) * 6
                      : (1 - curve) * 16;

                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, translateY),
                      child: child,
                    ),
                  );
                },
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
    final olive = NyanOverlayStyle.brandOlive(context);
    final iconColor = switch (tone) {
      NyanFloatingNoticeTone.success => NyanOverlayStyle.brandOliveDeep(context),
      NyanFloatingNoticeTone.error => NyanOverlayStyle.destructiveText(context),
      NyanFloatingNoticeTone.info => NyanOverlayStyle.brandOliveDeep(context),
    };
    final backgroundColor = switch (tone) {
      NyanFloatingNoticeTone.success => Color.alphaBlend(
          olive.withValues(alpha: 0.12),
          NyanOverlayStyle.creamSurface(context),
        ),
      NyanFloatingNoticeTone.error => NyanOverlayStyle.destructiveSubtleBackground(context),
      NyanFloatingNoticeTone.info => Color.alphaBlend(
          palette.tint.withValues(alpha: 0.08),
          NyanOverlayStyle.creamSurface(context),
        ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: NyanOverlayStyle.noticeIconBadgeSize,
        height: NyanOverlayStyle.noticeIconBadgeSize,
        child: Icon(
          icon,
          size: NyanOverlayStyle.noticeIconSize,
          color: iconColor,
        ),
      ),
    );
  }
}