import 'package:flutter/material.dart';

import '../../theme/nyan_colors.dart';
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

  static const double dialogRadius = 32;
  static const double dialogHorizontalInset = 24;
  static const double dialogMaxWidth = 700;
  static const double dialogPadding = 24;
  static const double dialogBadgeSize = 32;
  static const double dialogBadgeIconSize = 16;
  static const double dialogTitleGap = 14;
  static const double dialogSubtitleGap = 8;
  static const double dialogOptionGap = 22;
  static const double dialogActionGap = 18;

  static const double toastRadius = 999;
  static const double noticeMaxWidthFactor = 0.76;
  static const double noticeMaxWidthCap = 360;
  static const double noticeMinHeight = 56;
  static const double noticeHorizontalPadding = 16;
  static const double noticeVerticalPadding = 11;
  static const double noticeIconBadgeSize = 24;
  static const double noticeIconSize = 18;
  static const double noticeIconGap = 9;

  static const double optionRowRadius = 24;
  static const double optionTileMinHeight = 88;
  static const double optionTileHorizontalPadding = 18;
  static const double optionTileVerticalPadding = 16;

  static const double buttonRadius = 18;
  static const double buttonHeight = 56;
  static const double checkboxRadius = 8;
  static const double checkboxSize = 24;

  static Color creamSurface(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return panelSurface(context);
    }
    return NyanColors.overlayCreamSurface;
  }

  static Color panelSurface(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return Color.alphaBlend(
        theme.colorScheme.surface.withValues(alpha: 0.92),
        theme.scaffoldBackgroundColor,
      );
    }
    return NyanColors.overlayCreamSurface;
  }

  static Color brandOlive(BuildContext context) => context.nyanTheme.primary;

  static Color brandOliveDeep(BuildContext context) =>
      context.nyanTheme.primaryDeep;

  static Color mutedBrandOlive(BuildContext context) {
    final nyanTheme = context.nyanTheme;
    return Color.lerp(nyanTheme.primary, nyanTheme.textSecondary, 0.34)!;
  }

  static Color successNoticeIcon(BuildContext context) => brandOlive(context);

  static Color destructiveAccent(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return NyanColors.destructiveWarmDark;
    }
    return NyanColors.destructiveWarmLight;
  }

  static Color destructiveText(BuildContext context) {
    final theme = Theme.of(context);
    return Color.lerp(
      destructiveAccent(context),
      theme.colorScheme.onSurface,
      theme.brightness == Brightness.dark ? 0.16 : 0.2,
    )!;
  }

  static Color destructiveSubtleBackground(BuildContext context) {
    return Color.alphaBlend(
      destructiveAccent(context).withValues(alpha: 0.08),
      creamSurface(context),
    );
  }

  static Color destructiveSubtleBorder(BuildContext context) {
    return destructiveAccent(context).withValues(alpha: 0.14);
  }

  static Color recessedSurface(
    BuildContext context, {
    Color? seed,
    double strength = 0.04,
  }) {
    final theme = Theme.of(context);
    final base = theme.brightness == Brightness.dark
        ? Color.alphaBlend(
            theme.colorScheme.surface.withValues(alpha: 0.18),
            panelSurface(context),
          )
        : NyanColors.overlayRecessedSurface;
    if (seed == null) {
      return base;
    }

    final resolvedStrength =
        theme.brightness == Brightness.dark ? strength * 1.4 : strength;
    return Color.alphaBlend(
      seed.withValues(alpha: resolvedStrength),
      base,
    );
  }

  static Color divider(BuildContext context, {double? alpha}) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final base = Color.lerp(nyanTheme.divider, nyanTheme.textSecondary, 0.24)!;
    return base.withValues(
        alpha: alpha ?? (theme.brightness == Brightness.dark ? 0.3 : 0.34));
  }

  static Color modalBarrierColor(BuildContext context) {
    final theme = Theme.of(context);
    final nyanTheme = context.nyanTheme;
    final tint = Color.lerp(theme.shadowColor, nyanTheme.textSecondary, 0.08)!;
    return tint.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.56 : 0.2);
  }

  static List<BoxShadow> dialogShadow(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return const [];
    }

    return const [
      BoxShadow(
        color: NyanColors.overlayShadowDialogOuter,
        blurRadius: 28,
        spreadRadius: 0,
        offset: Offset(0, 10),
      ),
      BoxShadow(
        color: NyanColors.overlayShadowDialogInner,
        blurRadius: 8,
        spreadRadius: 0,
        offset: Offset(0, 2),
      ),
    ];
  }

  static List<BoxShadow> loadingShadow(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return const [];
    }

    return const [
      BoxShadow(
        color: NyanColors.overlayShadowLoadingOuter,
        blurRadius: 22,
        spreadRadius: 0,
        offset: Offset(0, 8),
      ),
      BoxShadow(
        color: NyanColors.overlayShadowLoadingInner,
        blurRadius: 8,
        spreadRadius: 0,
        offset: Offset(0, 2),
      ),
    ];
  }

  static Color noticeBorder(
    BuildContext context, {
    required NyanOverlayTone tone,
  }) {
    final palette = tonePalette(context, tone);
    final theme = Theme.of(context);
    final base = Color.lerp(divider(context), palette.border, 0.42)!;
    return base.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.34 : 0.26);
  }

  static Color noticeSurface(
    BuildContext context, {
    required NyanOverlayTone tone,
  }) {
    final theme = Theme.of(context);
    final palette = tonePalette(context, tone);
    final base = creamSurface(context);
    return Color.alphaBlend(
      palette.tint
          .withValues(alpha: theme.brightness == Brightness.dark ? 0.1 : 0.045),
      base,
    );
  }

  static List<BoxShadow> noticeShadow(
    BuildContext context, {
    required NyanOverlayTone tone,
  }) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return const [];
    }
    final palette = tonePalette(context, tone);

    return [
      BoxShadow(
        color: Color.alphaBlend(
          palette.tint.withValues(alpha: 0.04),
          NyanColors.overlayShadowNotice,
        ),
        blurRadius: 18,
        spreadRadius: 0,
        offset: Offset(0, 6),
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
      NyanOverlayTone.danger => destructiveAccent(context),
    };

    final fill = Color.alphaBlend(
      base.withValues(
        alpha: switch (tone) {
          NyanOverlayTone.neutral => isDark ? 0.08 : 0.028,
          NyanOverlayTone.success => isDark ? 0.095 : 0.052,
          NyanOverlayTone.info => isDark ? 0.08 : 0.038,
          NyanOverlayTone.danger => isDark ? 0.085 : 0.05,
        },
      ),
      surface,
    );

    final softFill = Color.alphaBlend(
      base.withValues(
        alpha: switch (tone) {
          NyanOverlayTone.neutral => isDark ? 0.12 : 0.04,
          NyanOverlayTone.success => isDark ? 0.16 : 0.1,
          NyanOverlayTone.info => isDark ? 0.12 : 0.06,
          NyanOverlayTone.danger => isDark ? 0.12 : 0.08,
        },
      ),
      recessedSurface(context),
    );

    return NyanOverlayTonePalette(
      tint: base,
      foreground: switch (tone) {
        NyanOverlayTone.neutral =>
          nyanTheme.textSecondary.withValues(alpha: isDark ? 0.8 : 0.72),
        NyanOverlayTone.success => brandOliveDeep(context),
        NyanOverlayTone.info =>
          brandOliveDeep(context).withValues(alpha: isDark ? 0.84 : 0.78),
        NyanOverlayTone.danger => destructiveText(context),
      },
      secondary: nyanTheme.textSecondary.withValues(alpha: isDark ? 0.78 : 0.7),
      fill: fill,
      softFill: softFill,
      border: switch (tone) {
        NyanOverlayTone.danger => destructiveSubtleBorder(context),
        _ => divider(context, alpha: isDark ? 0.3 : 0.22),
      },
      iconSurface: Color.alphaBlend(
        base.withValues(
            alpha: switch (tone) {
          NyanOverlayTone.neutral => isDark ? 0.08 : 0.03,
          NyanOverlayTone.success => isDark ? 0.1 : 0.1,
          NyanOverlayTone.info => isDark ? 0.085 : 0.06,
          NyanOverlayTone.danger => isDark ? 0.08 : 0.08,
        }),
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
    this.borderWidth = 1,
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
          color: borderColor ?? NyanOverlayStyle.divider(context, alpha: 0.18),
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
