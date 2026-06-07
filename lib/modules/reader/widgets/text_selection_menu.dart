import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nyan_read/core/theme/nyan_radius.dart';
import 'package:nyan_read/core/theme/nyan_shadows.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
import '../../../core/models/highlight.dart';
import '../../../core/theme/nyan_colors.dart';
import '../../../core/theme/theme_presets.dart';

/// Custom floating text-selection toolbar — icon+label actions, warm divider,
/// 5 Nyan highlight-color dots.  Matches U5 design spec.
class TextSelectionMenu extends StatelessWidget {
  final String selectedText;
  final Offset position;
  final Function(String colorCode) onHighlight;
  final VoidCallback onCopy;
  final VoidCallback onSearch;
  final VoidCallback onDismiss;

  const TextSelectionMenu({
    super.key,
    required this.selectedText,
    required this.position,
    required this.onHighlight,
    required this.onCopy,
    required this.onSearch,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final nyan = Theme.of(context).extension<NyanTheme>()!;
    // Opt out of text scaling so icon size (18pt) and label size (10pt) stay
    // at their spec pixel values regardless of the device's accessibility scale.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Material(
        color: Colors.transparent,
        // Force the icon theme so the overlay's ambient icon style cannot
        // override the matcha-green color we explicitly pass to each Icon.
        child: IconTheme(
          data: IconThemeData(color: nyan.primary, size: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: nyan.surface,
              borderRadius: BorderRadius.circular(NyanRadius.cardNested),
              border: Border.all(color: nyan.borderColor, width: 1),
              boxShadow: NyanShadows.lightCard(nyan),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                // gap: 4 between every flex child, matching spec's `gap: 4`.
                children: [
                  _ActionButton(
                    icon: NyanIcons.copy,
                    label: 'Copy',
                    nyan: nyan,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: selectedText));
                      onCopy();
                    },
                  ),
                  const SizedBox(width: 4),
                  _ActionButton(
                    icon: NyanIcons.search,
                    label: 'Search',
                    nyan: nyan,
                    onTap: onSearch,
                  ),
                  const SizedBox(width: 4),
                  _Divider(nyan: nyan),
                  const SizedBox(width: 4),
                  for (int i = 0; i < HighlightColors.all.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    _ColorButton(
                      colorCode: HighlightColors.all[i],
                      nyan: nyan,
                      onTap: () => onHighlight(HighlightColors.all[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final NyanTheme nyan;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.nyan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NyanRadius.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: nyan.primary),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: NyanTypography.uiFontFamily,
                fontSize: 10,
                height: 1,
                color: nyan.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final NyanTheme nyan;

  const _Divider({required this.nyan});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.72,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: nyan.divider.withValues(alpha: 0.6),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final String colorCode;
  final NyanTheme nyan;
  final VoidCallback onTap;

  const _ColorButton({
    required this.colorCode,
    required this.nyan,
    required this.onTap,
  });

  // Ink-tinted dot colors (HL_DOTS in U5 spec). These are the display colors
  // for the selection menu circles — more saturated than the paper highlight
  // colors stored in the DB. Source: colors_and_type.css --hl-ink-*.
  // HL_DOTS order from U5 spec (bundle2-screens.jsx):
  // yellow=#D8C06B  green=#A9C08E  blue=#7FABAC  pink=#CDA2A8  orange=#DBB686
  // Blue uses readerInfoBlue (#7FABAC), NOT highlightInkBlue (#B9C1C2).
  static const Map<String, Color> _inkDotColors = {
    HighlightColors.yellow: NyanColors.highlightInkYellow,
    HighlightColors.green: NyanColors.highlightInkGreen,
    HighlightColors.blue: NyanColors.readerInfoBlue,
    HighlightColors.pink: NyanColors.highlightInkPink,
    HighlightColors.orange: NyanColors.highlightInkOrange,
  };

  @override
  Widget build(BuildContext context) {
    final dotColor = _inkDotColors[colorCode] ?? NyanColors.highlightInkYellow;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: nyan.surface.withValues(alpha: 0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
