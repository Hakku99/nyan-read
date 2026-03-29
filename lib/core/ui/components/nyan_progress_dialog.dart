import 'package:flutter/material.dart';

import '../../theme/nyan_spacing.dart';
import 'nyan_overlay_style.dart';

class NyanProgressDialog extends StatelessWidget {
  const NyanProgressDialog({
    super.key,
    required this.title,
    required this.description,
    this.icon,
  });

  final String title;
  final String description;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = NyanOverlayStyle.tonePalette(
      context,
      NyanOverlayTone.success,
    );

    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: NyanSpacing.space24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 284,
            minHeight: 168,
          ),
          child: NyanOverlayPanel(
            padding: const EdgeInsets.fromLTRB(
              NyanSpacing.space24,
              NyanSpacing.space24,
              NyanSpacing.space24,
              NyanSpacing.space24,
            ),
            shadows: NyanOverlayStyle.loadingShadow(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon == null)
                  _NyanDialogDots(color: palette.foreground)
                else
                  Icon(
                    icon,
                    color: palette.foreground,
                    size: 22,
                  ),
                const SizedBox(height: NyanSpacing.space16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: NyanSpacing.space12),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.3,
                    color: palette.secondary,
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

class _NyanDialogDots extends StatefulWidget {
  const _NyanDialogDots({required this.color});

  final Color color;

  @override
  State<_NyanDialogDots> createState() => _NyanDialogDotsState();
}

class _NyanDialogDotsState extends State<_NyanDialogDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NyanOverlayStyle.loaderCycleDuration,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final shifted = (_controller.value - (index * 0.16)) % 1.0;
            final wave = Curves.easeInOut.transform(
              (1 - ((shifted - 0.5).abs() * 2)).clamp(0.0, 1.0),
            );
            final opacity = 0.24 + (wave * 0.58);
            final scale = 0.88 + (wave * 0.14);

            return Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 6),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}