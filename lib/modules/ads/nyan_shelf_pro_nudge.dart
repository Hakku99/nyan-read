import 'package:flutter/material.dart';

import '../../core/theme/nyan_radius.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/theme/nyan_typography.dart';
import '../../core/ui/nyan_icons.dart';
import '../../core/ui/nyan_theme_context.dart';

/// U22 "Option C" — Pro nudge: shown in the sponsored slot when no ad is
/// available. Matches `ProNudge` in the spec.
///
/// §4.4 gradient exception: this card uses large-area gradients that are
/// explicitly specified in the U22 delivery-package (§4.6 takes priority).
class NyanShelfProNudge extends StatelessWidget {
  final VoidCallback? onUpgrade;

  const NyanShelfProNudge({super.key, this.onUpgrade});

  static const _features = [
    'Remove all sponsored placements',
    'Unlock the private Privacy Shelf',
  ];

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;

    // ClipRRect wraps the Stack so the glow (Positioned outside content area)
    // is clipped at the card border — mirrors CSS overflow:hidden on the outer div.
    // Stack must be the direct child so Positioned coords are card-relative,
    // not content-area-relative (18px padding offset bug from old structure).
    return ClipRRect(
      borderRadius: BorderRadius.circular(NyanRadius.cardNested),
      child: Stack(
        // Clip.none lets the Positioned glow extend outside Stack bounds;
        // ClipRRect above handles the actual clipping at the card edge.
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NyanRadius.cardNested),
              // 155deg CSS → begin(-sin25°,-cos25°) end(+sin25°,+cos25°)
              gradient: LinearGradient(
                begin: const Alignment(-0.42, -0.91),
                end: const Alignment(0.42, 0.91),
                colors: [
                  Color.lerp(nyan.surface, nyan.primary, 0.17)!,
                  Color.lerp(nyan.surface, nyan.primary, 0.06)!,
                ],
              ),
              border: Border.all(
                color: nyan.accent.withValues(alpha: 0.22),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProHeader(nyan: nyan),
                const SizedBox(height: 15),
                _FeatureList(nyan: nyan),
                const SizedBox(height: 16),
                _UpgradeButton(onUpgrade: onUpgrade, nyan: nyan),
              ],
            ),
          ),
          // Decorative glow — card-relative, matches spec top:-42 right:-36 on outer div.
          // No stops: fills the full circle (CSS radial-gradient farthest-corner behavior).
          // ponytail: fade to same hue@0 not Colors.transparent — avoids dark-band lerp.
          Positioned(
            top: -42,
            right: -36,
            child: IgnorePointer(
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      nyan.primary.withValues(alpha: 0.11),
                      nyan.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProHeader extends StatelessWidget {
  final dynamic nyan;
  const _ProHeader({required this.nyan});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _LeafIcon(nyan: nyan),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Read without interruptions',
                style: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  fontSize: NyanTypography.body,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: nyan.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Nyan Read Pro · the calm way to read',
                style: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  fontSize: NyanTypography.responseDescription,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                  color: nyan.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeafIcon extends StatelessWidget {
  final dynamic nyan;
  const _LeafIcon({required this.nyan});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [nyan.primary, nyan.accent],
        ),
        boxShadow: [
          BoxShadow(
            color: nyan.accent.withValues(alpha: 0.60),
            blurRadius: 14,
            offset: const Offset(0, 6),
            spreadRadius: -6,
          ),
        ],
      ),
      child: const Icon(
        NyanIcons.leafFilled,
        size: 22,
        color: Colors.white,
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  final dynamic nyan;
  const _FeatureList({required this.nyan});

  static const _features = NyanShelfProNudge._features;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in _features) ...[
          if (f != _features.first) const SizedBox(height: 9),
          Row(
            children: [
              Icon(
                NyanIcons.checkCircleFilled,
                size: 16,
                color: nyan.accent,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  f,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: NyanTypography.meta,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: nyan.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  final VoidCallback? onUpgrade;
  final dynamic nyan;
  const _UpgradeButton({required this.onUpgrade, required this.nyan});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onUpgrade,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [nyan.primary, nyan.accent],
          ),
          boxShadow: [
            BoxShadow(
              color: nyan.accent.withValues(alpha: 0.65),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              NyanIcons.sparkleFilled,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: NyanSpacing.space8),
            Text(
              'Upgrade to Pro',
              style: TextStyle(
                fontFamily: NyanTypography.uiFontFamily,
                fontSize: NyanTypography.discoverBlockTitle,
                fontWeight: FontWeight.w600,
                height: 1.0,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
