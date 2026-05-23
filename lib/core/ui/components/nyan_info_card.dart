import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_shadows.dart';
import '../../theme/nyan_spacing.dart';
import '../nyan_theme_context.dart';

/// Surface tone for [NyanInfoCard]. Defaults to [surface] which keeps every
/// existing call site identical; pages that sit beside the reader sheet (e.g.
/// book details) opt into [muted] so the card and the sheet read as the same
/// tonal family instead of a brighter "white island" floating on cream.
enum NyanInfoCardTone { surface, muted }

/// [standard] — shelf / reader-adjacent cards (20px radius, [NyanShadows.lightCard]).
/// [grouped] — Settings-style white islands (16px radius, hairline border,
/// [NyanShadows.settingsGrouped]).
enum NyanInfoCardVariant { standard, grouped }

class NyanInfoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final NyanInfoCardTone tone;
  final NyanInfoCardVariant variant;

  const NyanInfoCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.tone = NyanInfoCardTone.surface,
    this.variant = NyanInfoCardVariant.standard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final isDark = theme.brightness == Brightness.dark;
    final isGrouped = variant == NyanInfoCardVariant.grouped;

    final Color cardSurface = switch (tone) {
      NyanInfoCardTone.surface => theme.cardColor,
      NyanInfoCardTone.muted => nyanTheme.surfaceMuted,
    };

    final double radius =
        isGrouped ? NyanRadius.input : NyanRadius.card;

    final double borderWidth = isGrouped ? 0.72 : 0.5;
    final double borderAlpha = isGrouped
        ? (isDark ? 0.2 : 0.16)
        : (isDark ? 0.24 : 0.3);

    final bool isMuted = tone == NyanInfoCardTone.muted;
    final List<BoxShadow> shadows = (isDark || isMuted)
        ? const []
        : (isGrouped
            ? NyanShadows.settingsGrouped(theme.shadowColor)
            : NyanShadows.lightCard(theme.shadowColor));

    final content = Container(
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows,
        border: Border.all(
          color: nyanTheme.divider.withValues(alpha: borderAlpha),
          width: borderWidth,
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(NyanSpacing.space16),
        child: child,
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}
