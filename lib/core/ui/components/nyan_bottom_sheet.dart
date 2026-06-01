import 'package:flutter/material.dart';
import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import '../../theme/theme_presets.dart';
class NyanBottomSheet extends StatelessWidget {
  final String? title;
  final String? description;
  final Widget child;
  final Widget? footer;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;
  final Color? handleColor;
  final double titleTopSpacing;
  final double descriptionSpacing;
  final double titleChildSpacing;
  const NyanBottomSheet({
    super.key,
    this.title,
    this.description,
    required this.child,
    this.footer,
    this.contentPadding,
    this.titleStyle,
    this.descriptionStyle,
    this.handleColor,
    this.titleTopSpacing = NyanSpacing.space16,
    this.descriptionSpacing = NyanSpacing.space8,
    this.titleChildSpacing = NyanSpacing.space16,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nyan = resolveNyanTheme(theme);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.bottomSheetTheme.backgroundColor ?? theme.cardColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(NyanRadius.sheet),
          ),
          // Dark catch-light: 1px top edge at 5% white simulates the CSS
          // `inset 0 1px 0 rgba(255,255,255,0.05)` that Flutter BoxShadow
          // cannot express directly (no inset mode).
          border: nyan.brightness == Brightness.dark
              ? const Border(
                  top: BorderSide(
                    color: Color(0x0DFFFFFF), // white @ ~5%
                    width: 1,
                  ),
                )
              : null,
        ),
        child: Padding(
          padding: contentPadding ??
              EdgeInsets.only(
                left: NyanSpacing.space24,
                right: NyanSpacing.space24,
                top: NyanSpacing.space12,
                bottom:
                    NyanSpacing.space24 + MediaQuery.of(context).padding.bottom,
              ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: NyanSpacing.space4,
                  decoration: BoxDecoration(
                    // Spec: `text-muted` token (not divider).
                    color: handleColor ?? nyan.textMuted,
                    // Spec: `border-radius: 999px` — pill ends.
                    // height/2 = space4/2 = 2pt gives perfect semicircles.
                    borderRadius: BorderRadius.circular(NyanSpacing.space4 / 2),
                  ),
                ),
              ),
              if (title != null) ...[
                SizedBox(height: titleTopSpacing),
                Text(
                  title!,
                  style: titleStyle ?? theme.textTheme.titleLarge,
                ),
              ],
              if (description != null) ...[
                SizedBox(height: descriptionSpacing),
                Text(
                  description!,
                  style:
                      descriptionStyle ??
                      theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.72,
                        ),
                      ),
                ),
              ],
              SizedBox(height: titleChildSpacing),
              child,
              if (footer != null) ...[
                const SizedBox(height: NyanSpacing.space20),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
