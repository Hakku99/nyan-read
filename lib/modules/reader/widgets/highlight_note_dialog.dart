import 'package:flutter/material.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../../core/models/highlight.dart';
import '../../../core/theme/nyan_colors.dart';
import '../../../core/theme/nyan_spacing.dart';
import '../../../core/ui/components/nyan_overlay_style.dart';
import '../../../core/ui/nyan_theme_context.dart';

/// Dialog for adding or editing a note on a highlight.
class HighlightNoteDialog extends StatefulWidget {
  const HighlightNoteDialog({
    super.key,
    this.highlight,
    this.initialNote,
    required this.onSave,
    this.onDelete,
  });

  final Highlight? highlight;
  final String? initialNote;
  final Function(String? note, String? colorCode) onSave;
  final VoidCallback? onDelete;

  @override
  State<HighlightNoteDialog> createState() => _HighlightNoteDialogState();
}

class _HighlightNoteDialogState extends State<HighlightNoteDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _selectedColorCode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialNote ?? widget.highlight?.note ?? '',
    );
    _focusNode = FocusNode();
    _selectedColorCode = widget.highlight?.colorCode ?? HighlightColors.yellow;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Color _parseColor(String? colorCode) {
    if (colorCode == null) return NyanColors.highlightYellow;
    try {
      final hex = colorCode.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return NyanColors.highlightYellow;
    }
  }

  void _handleSave() {
    final note = _controller.text.trim();
    widget.onSave(note.isEmpty ? null : note, _selectedColorCode);
    Navigator.of(context).pop();
  }

  void _handleDelete() {
    widget.onDelete?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primaryText = context.nyanTheme.textPrimary.withValues(alpha: 0.94);
    final surfaceColor = _HighlightDialogPalette.dialogSurface(context);
    final borderColor = _HighlightDialogPalette.dialogBorder(context);
    final highlightColor = _parseColor(_selectedColorCode);
    final excerpt = widget.highlight?.selectedText.trim();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: _HighlightNoteDialogTokens.outerInset,
        vertical: _HighlightNoteDialogTokens.outerInset,
      ),
      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0),
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _HighlightNoteDialogTokens.maxWidth,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(
              _HighlightNoteDialogTokens.surfaceRadius,
            ),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: _HighlightDialogPalette.dialogShadow(context),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(_HighlightNoteDialogTokens.padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _SelectedColorBadge(color: highlightColor),
                          const SizedBox(width: NyanSpacing.space12),
                          Expanded(
                            child: Text(
                              loc.editNote,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.16,
                                color: primaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onDelete != null) ...[
                      const SizedBox(width: NyanSpacing.space12),
                      _DeleteIconButton(
                        semanticLabel: loc.deleteNote,
                        color: _HighlightDialogPalette.deleteTone(context),
                        onTap: _handleDelete,
                        backgroundColor: _HighlightDialogPalette.deleteSurface(
                          context,
                        ),
                      ),
                    ],
                  ],
                ),
                if (excerpt != null && excerpt.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _HighlightPreviewCard(
                    text: excerpt,
                    highlightColor: highlightColor,
                  ),
                ],
                const SizedBox(height: 12),
                _ColorPickerRow(
                  colors: HighlightColors.all,
                  selectedColorCode:
                      _selectedColorCode ?? HighlightColors.yellow,
                  onSelected: (color) {
                    setState(() {
                      _selectedColorCode = color;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _NoteInputCard(
                  controller: _controller,
                  focusNode: _focusNode,
                  hintText: loc.addNoteHint,
                ),
                const SizedBox(height: 10),
                _DialogActionRow(
                  cancelLabel: loc.cancel,
                  saveLabel: loc.save,
                  primaryText: primaryText,
                  surfaceColor: surfaceColor,
                  onCancel: () => Navigator.of(context).pop(),
                  onSave: _handleSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightNoteDialogTokens {
  const _HighlightNoteDialogTokens._();

  static const double outerInset = 20;
  static const double maxWidth = 560;
  static const double surfaceRadius = 30;
  static const double padding = 18;
  static const double pickerHeight = 42;
  static const double pickerRadius = 20;
  static const double pickerSwatchSize = 38;
  static const double pickerInnerSwatchSize = 14;
  static const double previewRadius = 20;
  static const double previewMinHeight = 48;
  static const double inputMinHeight = 82;
  static const double inputRadius = 22;
  static const double inputPadding = 15;
  static const double iconButtonTapSize = 36;
  static const double iconButtonVisualSize = 26;
  static const double buttonHeight = 50;
  static const double buttonRadius = 17;
  static const double dialogBorderAlpha = 0.085;
  static const double pickerBorderAlpha = 0.022;
  static const double previewBorderAlpha = 0.06;
  static const double inputBorderAlpha = 0.105;
  static const double deleteBorderAlpha = 0.04;
  static const double cancelBorderAlpha = 0.11;
}

class _HighlightDialogPalette {
  const _HighlightDialogPalette._();

  static Color dialogSurface(BuildContext context) {
    return Color.alphaBlend(
      context.nyanTheme.textSecondary.withValues(alpha: 0.012),
      NyanColors.highlightPaperDialog,
    );
  }

  static Color dialogBorder(BuildContext context) {
    return surfaceBorder(context, _HighlightNoteDialogTokens.dialogBorderAlpha);
  }

  static List<BoxShadow> dialogShadow(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      return const [];
    }

    return const [
      BoxShadow(
        color: NyanColors.shadowSoft,
        blurRadius: 24,
        spreadRadius: 0,
        offset: Offset(0, 8),
      ),
      BoxShadow(
        color: NyanColors.shadowHairline,
        blurRadius: 8,
        spreadRadius: 0,
        offset: Offset(0, 2),
      ),
    ];
  }

  static Color pickerSurface(BuildContext context) {
    return Color.alphaBlend(
      context.nyanTheme.textSecondary.withValues(alpha: 0.006),
      NyanColors.highlightPaperPicker,
    );
  }

  static Color previewSurface(BuildContext context) {
    return Color.alphaBlend(
      context.nyanTheme.textSecondary.withValues(alpha: 0.012),
      NyanColors.highlightPaperPreview,
    );
  }

  static Color inputSurface(BuildContext context) {
    return Color.alphaBlend(
      context.nyanTheme.textSecondary.withValues(alpha: 0.015),
      NyanColors.highlightPaperInput,
    );
  }

  static Color badgeSurface(BuildContext context, Color highlightColor) {
    return Color.lerp(
      dialogSurface(context),
      displayHighlight(highlightColor),
      isYellowHighlight(highlightColor) ? 0.1 : 0.075,
    )!;
  }

  static Color deleteTone(BuildContext context) {
    return Color.alphaBlend(
      NyanColors.highlightInkSepia.withValues(alpha: 0.76),
      context.nyanTheme.textPrimary.withValues(alpha: 0.1),
    );
  }

  static Color deleteSurface(BuildContext context) {
    return Color.alphaBlend(
      context.nyanTheme.textSecondary.withValues(alpha: 0.04),
      dialogSurface(context),
    );
  }

  static Color surfaceBorder(BuildContext context, double alpha) {
    return Theme.of(context).colorScheme.outline.withValues(
          alpha: alpha,
        );
  }

  // Flutter 3.27+：Color.r/.g/.b 为 0-1 双精度。下列阈值按 0-255 整数范围给出，
  // 因此 compare 前乘 255 并 round。
  static int _r255(Color c) => (c.r * 255).round();
  static int _g255(Color c) => (c.g * 255).round();
  static int _b255(Color c) => (c.b * 255).round();

  static bool isYellowHighlight(Color color) {
    return _r255(color) > 230 && _g255(color) > 210 && _b255(color) < 170;
  }

  static Color displayHighlight(Color color) {
    if (isYellowHighlight(color)) {
      return NyanColors.highlightInkYellow;
    }
    final r = _r255(color);
    final g = _g255(color);
    final b = _b255(color);
    if (b > r && b > g) {
      return NyanColors.highlightInkBlue;
    }
    if (r > 220 && b > 150) {
      return NyanColors.highlightInkPink;
    }
    if (r > 220 && g > 150 && b < 150) {
      return NyanColors.highlightInkOrange;
    }
    if (g > r && g > b) {
      return NyanColors.highlightInkGreen;
    }
    return Color.alphaBlend(NyanColors.highlightPaperLiftTint, color);
  }

  static Color previewSurfaceFor(BuildContext context, Color highlightColor) {
    final base = previewSurface(context);
    final blend = isYellowHighlight(highlightColor) ? 0.02 : 0.008;
    return Color.lerp(base, displayHighlight(highlightColor), blend)!;
  }

  static Color previewBarColor(Color highlightColor) {
    if (isYellowHighlight(highlightColor)) {
      return NyanColors.highlightPreviewBar;
    }
    return displayHighlight(highlightColor).withValues(alpha: 0.54);
  }

  static Color pickerRingColor(Color highlightColor) {
    final fill = displayHighlight(highlightColor);
    return fill.withValues(
      alpha: isYellowHighlight(highlightColor) ? 0.2 : 0.17,
    );
  }

  static Color pickerOuterSurface(BuildContext context, Color highlightColor) {
    final base = pickerSurface(context);
    final fill = displayHighlight(highlightColor);
    final blend = isYellowHighlight(highlightColor) ? 0.13 : 0.095;
    return Color.lerp(base, fill, blend)!;
  }

  static Color pickerLiftSurface(BuildContext context, Color highlightColor) {
    final cream = Color.lerp(
      dialogSurface(context),
      Theme.of(context).colorScheme.surface,
      0.28,
    )!;
    final liftTint = displayHighlight(highlightColor).withValues(
      alpha: isYellowHighlight(highlightColor) ? 0.1 : 0.08,
    );
    return Color.alphaBlend(liftTint, cream);
  }

  static Color pickerShadowColor(Color highlightColor) {
    final fill = displayHighlight(highlightColor);
    return fill.withValues(
      alpha: isYellowHighlight(highlightColor) ? 0.045 : 0.03,
    );
  }

  static Color mutedText(BuildContext context) {
    return context.nyanTheme.textSecondary.withValues(alpha: 0.76);
  }
}

class _SelectedColorBadge extends StatelessWidget {
  const _SelectedColorBadge({
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    final iconColor = Color.lerp(
      context.nyanTheme.textPrimary.withValues(alpha: 0.7),
      _HighlightDialogPalette.displayHighlight(color),
      0.16,
    )!;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _HighlightDialogPalette.badgeSurface(context, color),
        border: Border.all(
          color: color.withValues(alpha: 0.02),
          width: 1,
        ),
      ),
      child: SizedBox(
        width: 24,
        height: 24,
        child: Icon(
          NyanIcons.editNote,
          size: 12,
          color: iconColor,
        ),
      ),
    );
  }
}

class _ColorPickerRow extends StatelessWidget {
  const _ColorPickerRow({
    required this.colors,
    required this.selectedColorCode,
    required this.onSelected,
  });

  final List<String> colors;
  final String selectedColorCode;
  final ValueChanged<String> onSelected;

  Color _parseColor(String colorCode) {
    final hex = colorCode.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final surface = _HighlightDialogPalette.pickerSurface(context);

    return Container(
      height: _HighlightNoteDialogTokens.pickerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(surface, Theme.of(context).colorScheme.surface, 0.1)!,
            surface,
          ],
        ),
        borderRadius: BorderRadius.circular(
          _HighlightNoteDialogTokens.pickerRadius,
        ),
        border: Border.all(
          color: _HighlightDialogPalette.surfaceBorder(
            context,
            _HighlightNoteDialogTokens.pickerBorderAlpha,
          ),
          width: 1,
        ),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < colors.length; index++) ...[
              _HighlightColorSwatch(
                color: _parseColor(colors[index]),
                isSelected: colors[index] == selectedColorCode,
                onTap: () => onSelected(colors[index]),
              ),
              if (index != colors.length - 1) const SizedBox(width: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _HighlightColorSwatch extends StatelessWidget {
  const _HighlightColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final creamSurface = _HighlightDialogPalette.dialogSurface(context);
    final softenedColor = _HighlightDialogPalette.displayHighlight(color);
    final borderColor = isSelected
        ? _HighlightDialogPalette.pickerRingColor(color)
        : Theme.of(context).colorScheme.surface.withValues(alpha: 0);
    final outerColor = isSelected
        ? _HighlightDialogPalette.pickerOuterSurface(context, color)
        : Theme.of(context).colorScheme.surface.withValues(alpha: 0);
    final liftSurface = _HighlightDialogPalette.pickerLiftSurface(
      context,
      color,
    );
    final shadow = isSelected
        ? [
            BoxShadow(
              color: _HighlightDialogPalette.pickerShadowColor(color),
              blurRadius: 4,
              spreadRadius: 0,
              offset: const Offset(0, 0.8),
            ),
          ]
        : const <BoxShadow>[];

    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: _HighlightNoteDialogTokens.pickerSwatchSize,
          height: _HighlightNoteDialogTokens.pickerSwatchSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: outerColor,
            border: Border.all(color: borderColor, width: 1),
            boxShadow: shadow,
          ),
          child: Center(
            child: Container(
              width: isSelected ? 26 : 20,
              height: isSelected ? 26 : 20,
              decoration: BoxDecoration(
                color: isSelected
                    ? liftSurface
                    : Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0),
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(
                        color: creamSurface.withValues(alpha: 0.92),
                        width: 0.9,
                      )
                    : null,
              ),
              child: Center(
                child: Container(
                  width: _HighlightNoteDialogTokens.pickerInnerSwatchSize +
                      (isSelected ? 2 : 0),
                  height: _HighlightNoteDialogTokens.pickerInnerSwatchSize +
                      (isSelected ? 2 : 0),
                  decoration: BoxDecoration(
                    color: softenedColor,
                    shape: BoxShape.circle,
                  ),
                  child: isSelected
                      ? Icon(
                          NyanIcons.checkFilled,
                          size: 10,
                          color: creamSurface.withValues(alpha: 0.98),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightPreviewCard extends StatelessWidget {
  const _HighlightPreviewCard({
    required this.text,
    required this.highlightColor,
  });

  final String text;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryText = context.nyanTheme.textPrimary.withValues(alpha: 0.92);
    final quoteColor = Color.lerp(
      _HighlightDialogPalette.mutedText(context),
      _HighlightDialogPalette.previewBarColor(highlightColor),
      _HighlightDialogPalette.isYellowHighlight(highlightColor) ? 0.4 : 0.22,
    )!;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: _HighlightNoteDialogTokens.previewMinHeight,
      ),
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              _HighlightDialogPalette.previewSurfaceFor(
                  context, highlightColor),
              theme.colorScheme.surface,
              0.12,
            )!,
            _HighlightDialogPalette.previewSurface(context),
          ],
        ),
        borderRadius: BorderRadius.circular(
          _HighlightNoteDialogTokens.previewRadius,
        ),
        border: Border.all(
          color: _HighlightDialogPalette.surfaceBorder(
            context,
            _HighlightNoteDialogTokens.previewBorderAlpha,
          ),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                NyanIcons.quote,
                size: 15,
                color: quoteColor.withValues(alpha: 0.88),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13.8,
                fontWeight: FontWeight.w500,
                height: 1.36,
                color: primaryText.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteInputCard extends StatelessWidget {
  const _NoteInputCard({
    required this.controller,
    required this.focusNode,
    required this.hintText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryText = context.nyanTheme.textPrimary.withValues(alpha: 0.94);
    final mergedListenable = Listenable.merge([focusNode, controller]);

    return ListenableBuilder(
      listenable: mergedListenable,
      builder: (context, _) {
        final isFocused = focusNode.hasFocus;
        final hasText = controller.text.isNotEmpty;
        final borderColor = isFocused
            ? NyanOverlayStyle.mutedBrandOlive(context).withValues(alpha: 0.16)
            : _HighlightDialogPalette.surfaceBorder(
                context,
                _HighlightNoteDialogTokens.inputBorderAlpha,
              );
        final inputSurface = _HighlightDialogPalette.inputSurface(context);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: _HighlightNoteDialogTokens.inputMinHeight,
          ),
          padding: const EdgeInsets.fromLTRB(
            _HighlightNoteDialogTokens.inputPadding,
            12,
            _HighlightNoteDialogTokens.inputPadding,
            12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(inputSurface, theme.colorScheme.surface, 0.08)!,
                inputSurface,
              ],
            ),
            borderRadius: BorderRadius.circular(
              _HighlightNoteDialogTokens.inputRadius,
            ),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: SizedBox(
            height: _HighlightNoteDialogTokens.inputMinHeight - 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasText && !isFocused)
                  IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1, bottom: 2),
                      child: Text(
                        hintText,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.44,
                          letterSpacing: 0.05,
                          color: context.nyanTheme.textSecondary.withValues(
                            alpha: 0.74,
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    textAlignVertical: TextAlignVertical.top,
                    cursorColor: NyanOverlayStyle.brandOlive(context),
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    scrollPadding: const EdgeInsets.only(bottom: 120),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.42,
                      color: primaryText,
                    ),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      isDense: true,
                      filled: false,
                      fillColor: NyanColors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DeleteIconButton extends StatelessWidget {
  const _DeleteIconButton({
    required this.semanticLabel,
    required this.color,
    required this.onTap,
    required this.backgroundColor,
  });

  final String semanticLabel;
  final Color color;
  final VoidCallback onTap;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: _HighlightNoteDialogTokens.iconButtonTapSize,
            height: _HighlightNoteDialogTokens.iconButtonTapSize,
            child: Center(
              child: Ink(
                width: _HighlightNoteDialogTokens.iconButtonVisualSize,
                height: _HighlightNoteDialogTokens.iconButtonVisualSize,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _HighlightDialogPalette.surfaceBorder(
                      context,
                      _HighlightNoteDialogTokens.deleteBorderAlpha,
                    ),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    NyanIcons.delete,
                    size: 13,
                    color: color.withValues(alpha: 0.86),
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

class _DialogActionRow extends StatelessWidget {
  const _DialogActionRow({
    required this.cancelLabel,
    required this.saveLabel,
    required this.primaryText,
    required this.surfaceColor,
    required this.onCancel,
    required this.onSave,
  });

  final String cancelLabel;
  final String saveLabel;
  final Color primaryText;
  final Color surfaceColor;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 320;
        final isTight = constraints.maxWidth < 360;
        final gap = isTight ? NyanSpacing.space8 : 10.0;
        final cancelPadding = isTight ? 18.0 : 20.0;
        final savePadding = isTight ? 22.0 : 24.0;
        final buttonGroup = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogActionButton(
              label: cancelLabel,
              onTap: onCancel,
              backgroundColor: Color.alphaBlend(
                context.nyanTheme.textSecondary.withValues(alpha: 0.026),
                surfaceColor,
              ),
              borderColor: _HighlightDialogPalette.surfaceBorder(
                context,
                _HighlightNoteDialogTokens.cancelBorderAlpha,
              ),
              foregroundColor: primaryText,
              fontWeight: FontWeight.w600,
              horizontalPadding: cancelPadding,
            ),
            SizedBox(width: gap),
            _DialogActionButton(
              label: saveLabel,
              onTap: onSave,
              backgroundColor: NyanOverlayStyle.brandOlive(context),
              borderColor: NyanOverlayStyle.brandOlive(context),
              foregroundColor: Theme.of(context)
                  .colorScheme
                  .onPrimary
                  .withValues(alpha: 0.97),
              fontWeight: FontWeight.w700,
              horizontalPadding: savePadding,
            ),
          ],
        );

        if (isCompact) {
          return Align(
            alignment: Alignment.centerRight,
            child: buttonGroup,
          );
        }

        return Align(
          alignment: Alignment.centerRight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: buttonGroup,
          ),
        );
      },
    );
  }
}

class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
    required this.fontWeight,
    required this.horizontalPadding,
  });

  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final FontWeight fontWeight;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          _HighlightNoteDialogTokens.buttonRadius,
        ),
        child: Ink(
          height: _HighlightNoteDialogTokens.buttonHeight,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(
              _HighlightNoteDialogTokens.buttonRadius,
            ),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                fontWeight: fontWeight,
                color: foregroundColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a dialog to add or edit a note.
Future<void> showHighlightNoteDialog(
  BuildContext context, {
  Highlight? highlight,
  String? initialNote,
  required Function(String? note, String? colorCode) onSave,
  VoidCallback? onDelete,
}) async {
  await showDialog(
    context: context,
    barrierColor: NyanOverlayStyle.modalBarrierColor(context),
    builder: (dialogContext) => TweenAnimationBuilder<double>(
      duration: NyanOverlayStyle.overlayTransitionDuration,
      curve: NyanOverlayStyle.overlayCurve,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: Transform.scale(
              scale: 0.98 + (0.02 * value),
              child: child,
            ),
          ),
        );
      },
      child: HighlightNoteDialog(
        highlight: highlight,
        initialNote: initialNote,
        onSave: onSave,
        onDelete: onDelete,
      ),
    ),
  );
}
