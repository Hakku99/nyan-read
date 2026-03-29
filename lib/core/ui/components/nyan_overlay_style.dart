import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import '../nyan_theme_context.dart';

enum NyanOverlayTone { neutral, success, info, danger }

@immutable
class NyanOverlayTonePalette {
  const NyanOverlayTonePalette({
    required this.tint,
    required this.foreground,
    required this.secondary,
    required this.fill,
    required this.softFill,
    required this.border,
    required this.iconSurface,
  });

  final Color tint;
  final Color foreground;
  final Color secondary;
  final Color fill;
  final Color softFill;
  final Color border;
  final Color iconSurface;
}

class NyanOverlayStyle {
  const NyanOverlayStyle._();

  static const Duration overlayTransitionDuration = Duration(milliseconds: 220);
  static const Duration noticeEnterDuration = Duration(milliseconds: 220);
  static const Duration noticeExitDuration = Duration(milliseconds: 160);
  static const Duration loaderCycleDuration = Duration(milliseconds: 840);
  static const Curve overlayCurve = Curves.easeOutCubic;
  static const Curve overlayFadeCurve = Curves.easeOut;
  static const double dialogRadius = 30;
  static const double toastRadius = 999;
  static const double buttonRadius = 19;
  static const double optionRowRadius = 18;
  static const double checkboxRadius = 8;
  static const double noticeMaxWidthFactor = 0.74;
  static const double noticeMaxWidthCap = 296;

  static Color creamSurface(BuildContext context) => panelSurface(context);

  static Color brandOlive(BuildContext context) => context.nyanTheme.primary;

  static Color mutedBrandOlive(BuildContext context) {
    final nyanTheme = context.nyanTheme;
    return Color.lerp(nyanTheme.primary, nyanTheme.textSecondary, 0.34)!;
  }

  static Color successNoticeIcon(BuildContext context) => brandOlive(context);

  static Color destructiveAccent(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return const Color(0xFFD1A79A);
    }
    return const Color(0xFF9A7567);
  }

  static Color destructiveText(BuildContext context) {
    final theme = Theme.of(context);
    return Color.lerp(
      destructiveAccent(context),
      theme.colorScheme.onSurface,
      theme.brightness == Brightness.dark ? 0.12 : 0.18,
    )!;
  }

  static Color destructiveSubtleBackground(BuildContext context) {
    final theme = Theme.of(context);
    return Color.alphaBlend(
      destructiveAccent(context).withValues(
        alpha: theme.brightness == Brightness.dark ? 0.12 : 0.055,
      ),
      creamSurface(context),
    );
  }

  static Color destructiveSubtleBorder(BuildContext context) {
    final theme = Theme.of(context);
    return destructiveAccent(context).withValues(
      alpha: theme.brightness == Brightness.dark ? 0.24 : 0.15,
    );
  }

  static Color panelSurface(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Color.alphaBlend(
      theme.colorScheme.surface.withValues(alpha: isDark ? 0.92 : 0.988),
      theme.scaffoldBackgroundColor,
    );
  }

  static Color recessedSurface(
    BuildContext context, {
    Color? seed,
    double strength = 0.04,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = Color.alphaBlend(
      theme.colorScheme.surface.withValues(alpha: isDark ? 0.12 : 0.68),
      panelSurface(context),
    );
    if (seed == null) {
      return base;
    }

    final resolvedStrength = isDark ? strength * 1.55 : strength;
    return Color.alphaBlend(
      seed.withValues(alpha: resolvedStrength),
      base,
    );
  }

  static Color divider(BuildContext context, {double? alpha}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return theme.dividerColor.withValues(alpha: alpha ?? (isDark ? 0.2 : 0.42));
  }

  static Color modalBarrierColor(BuildContext context) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final isDark = theme.brightness == Brightness.dark;
    final tint = Color.lerp(
      theme.shadowColor,
      nyanTheme.textSecondary,
      isDark ? 0.12 : 0.08,
    )!;
    return tint.withValues(alpha: isDark ? 0.56 : 0.2);
  }

  static List<BoxShadow> dialogShadow(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return const [];
    }

    final shadow = theme.shadowColor;
    return [
      BoxShadow(
        color: shadow.withValues(alpha: 0.032),
        blurRadius: 34,
        offset: const Offset(0, 16),
      ),
      BoxShadow(
        color: shadow.withValues(alpha: 0.014),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> loadingShadow(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return const [];
    }

    final shadow = theme.shadowColor;
    return [
      BoxShadow(
        color: shadow.withValues(alpha: 0.024),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: shadow.withValues(alpha: 0.012),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ];
  }

  static List<BoxShadow> noticeShadow(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return const [];
    }

    final shadow = theme.shadowColor;
    return [
      BoxShadow(
        color: shadow.withValues(alpha: 0.011),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: shadow.withValues(alpha: 0.006),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static NyanOverlayTonePalette tonePalette(
    BuildContext context,
    NyanOverlayTone tone,
  ) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final isDark = theme.brightness == Brightness.dark;
    final surface = panelSurface(context);

    final base = switch (tone) {
      NyanOverlayTone.neutral => nyanTheme.textSecondary,
      NyanOverlayTone.success => brandOlive(context),
      NyanOverlayTone.info => Color.lerp(
        nyanTheme.textSecondary,
        nyanTheme.primaryDeep,
        isDark ? 0.24 : 0.12,
      )!,
      NyanOverlayTone.danger => destructiveText(context),
    };

    final toneSeed = tone == NyanOverlayTone.danger
        ? destructiveAccent(context)
        : base;

    final fill = Color.alphaBlend(
      toneSeed.withValues(
        alpha: switch (tone) {
          NyanOverlayTone.neutral => isDark ? 0.08 : 0.024,
          NyanOverlayTone.success => isDark ? 0.095 : 0.04,
          NyanOverlayTone.info => isDark ? 0.08 : 0.032,
          NyanOverlayTone.danger => isDark ? 0.085 : 0.03,
        },
      ),
      surface,
    );
    final softFill = Color.alphaBlend(
      toneSeed.withValues(
        alpha: switch (tone) {
          NyanOverlayTone.neutral => isDark ? 0.12 : 0.036,
          NyanOverlayTone.success => isDark ? 0.15 : 0.056,
          NyanOverlayTone.info => isDark ? 0.12 : 0.046,
          NyanOverlayTone.danger => isDark ? 0.12 : 0.045,
        },
      ),
      recessedSurface(context),
    );

    return NyanOverlayTonePalette(
      tint: base,
      foreground: base.withValues(
        alpha: switch (tone) {
          NyanOverlayTone.neutral => isDark ? 0.78 : 0.66,
          NyanOverlayTone.success => isDark ? 0.84 : 0.72,
          NyanOverlayTone.info => isDark ? 0.8 : 0.68,
          NyanOverlayTone.danger => isDark ? 0.84 : 0.76,
        },
      ),
      secondary: nyanTheme.textSecondary.withValues(alpha: isDark ? 0.78 : 0.68),
      fill: fill,
      softFill: softFill,
      border: tone == NyanOverlayTone.danger
          ? destructiveSubtleBorder(context)
          : base.withValues(alpha: isDark ? 0.2 : 0.11),
      iconSurface: Color.alphaBlend(
        toneSeed.withValues(
          alpha: switch (tone) {
            NyanOverlayTone.neutral => isDark ? 0.08 : 0.028,
            NyanOverlayTone.success => isDark ? 0.09 : 0.04,
            NyanOverlayTone.info => isDark ? 0.085 : 0.034,
            NyanOverlayTone.danger => isDark ? 0.08 : 0.028,
          },
        ),
        surface,
      ),
    );
  }
}

class NyanOverlayPanel extends StatelessWidget {
  const NyanOverlayPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NyanSpacing.space24),
    this.radius = NyanOverlayStyle.dialogRadius,
    this.shadows,
    this.borderColor,
    this.borderWidth = 0.7,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final List<BoxShadow>? shadows;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NyanOverlayStyle.panelSurface(context),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? NyanOverlayStyle.divider(context, alpha: 0.34),
          width: borderWidth,
        ),
        boxShadow: shadows ?? NyanOverlayStyle.dialogShadow(context),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}