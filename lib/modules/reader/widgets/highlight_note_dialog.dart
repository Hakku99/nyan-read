import 'package:flutter/material.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../../core/models/highlight.dart';
import '../../../core/theme/nyan_colors.dart';
import '../../../core/theme/nyan_radius.dart';
import '../../../core/theme/nyan_spacing.dart';
import '../../../core/ui/components/nyan_overlay_style.dart';
import '../../../core/ui/components/nyan_primary_button.dart';
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
    final nyan = context.nyanTheme;
    final highlightColor = _parseColor(_selectedColorCode);
    final excerpt = widget.highlight?.selectedText.trim();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: _HighlightNoteDialogTokens.outerInset,
        vertical: _HighlightNoteDialogTokens.outerInset,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _HighlightNoteDialogTokens.maxWidth,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: nyan.surfaceRaised,
            borderRadius: BorderRadius.circular(
              _HighlightNoteDialogTokens.surfaceRadius,
            ),
            border: Border.all(
              color: _HighlightDialogPalette.dialogBorder(context),
              width: 1,
            ),
            boxShadow: _HighlightDialogPalette.dialogShadow(context),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(_HighlightNoteDialogTokens.padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title row ──
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
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.16,
                                letterSpacing: -0.1,
                                color: nyan.textPrimary.withValues(alpha: 0.94),
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
                        onTap: _handleDelete,
                      ),
                    ],
                  ],
                ),
                // ── Excerpt preview ──
                if (excerpt != null && excerpt.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _HighlightPreviewCard(
                    text: excerpt,
                    highlightColor: highlightColor,
                  ),
                ],
                const SizedBox(height: 12),
                // ── Color picker ──
                _ColorPickerRow(
                  colors: HighlightColors.all,
                  selectedColorCode:
                      _selectedColorCode ?? HighlightColors.yellow,
                  onSelected: (color) {
                    setState(() => _selectedColorCode = color);
                  },
                ),
                const SizedBox(height: 12),
                // ── Note input ──
                _NoteInputCard(
                  controller: _controller,
                  focusNode: _focusNode,
                  hintText: loc.addNoteHint,
                ),
                const SizedBox(height: 14),
                // ── Actions ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    NyanPrimaryButton(
                      label: loc.cancel,
                      onPressed: () => Navigator.of(context).pop(),
                      variant: NyanPrimaryButtonVariant.ghost,
                      size: NyanPrimaryButtonSize.comfortable,
                    ),
                    const SizedBox(width: 10),
                    NyanPrimaryButton(
                      label: loc.save,
                      onPressed: _handleSave,
                      variant: NyanPrimaryButtonVariant.primary,
                      size: NyanPrimaryButtonSize.comfortable,
                    ),
                  ],
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
  // Floating dialog sits at dock level per --r-dock / NyanRadius.dock.
  static const double surfaceRadius = NyanRadius.dock;
  static const double padding = 18;
  // All inner cards use cardNested (concentric inside dock).
  static const double pickerRadius = NyanRadius.cardNested;
  static const double pickerSwatchSize = 26;
  static const double previewRadius = NyanRadius.cardNested;
  static const double previewMinHeight = 48;
  static const double inputMinHeight = 82;
  static const double inputRadius = NyanRadius.cardNested;
  static const double inputPadding = 15;
  static const double iconButtonTapSize = 40;
}

class _HighlightDialogPalette {
  const _HighlightDialogPalette._();

  static Color dialogBorder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Light: chrome-edge is transparent. Dark: divider ring for elevation.
    return isDark ? context.nyanTheme.divider : Colors.transparent;
  }

  static List<BoxShadow> dialogShadow(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      final divider = context.nyanTheme.divider;
      return [
        // Luminous hairline ring (v3 elevation ladder).
        BoxShadow(
          color: divider.withValues(alpha: 0.88),
          blurRadius: 0,
          spreadRadius: 0.375,
          offset: Offset.zero,
        ),
        const BoxShadow(
          color: Color(0x70000000),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
        const BoxShadow(
          color: Color(0x57000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ];
    }
    return const [
      BoxShadow(
        color: NyanColors.shadowSoft,
        blurRadius: 24,
        offset: Offset(0, 8),
      ),
      BoxShadow(
        color: NyanColors.shadowHairline,
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
    ];
  }

  static Color badgeSurface(BuildContext context, Color highlightColor) {
    // Spec: color-mix(in srgb, ink 12%, nyan-surface) — flat 12% for all colors.
    return Color.lerp(
      context.nyanTheme.surfaceRaised,
      displayHighlight(highlightColor),
      0.12,
    )!;
  }

  static Color previewBackground(BuildContext context, Color highlightColor) {
    return Color.lerp(
      context.nyanTheme.surfaceMuted,
      displayHighlight(highlightColor),
      0.06,
    )!;
  }

  static Color previewBorder(BuildContext context, Color highlightColor) {
    return Color.lerp(
      context.nyanTheme.divider,
      displayHighlight(highlightColor),
      0.14,
    )!;
  }

  // Flutter 3.27+: Color.r/.g/.b are 0-1 doubles; multiply by 255 before comparing.
  static int _r255(Color c) => (c.r * 255).round();
  static int _g255(Color c) => (c.g * 255).round();
  static int _b255(Color c) => (c.b * 255).round();

  static bool isYellowHighlight(Color color) {
    return _r255(color) > 230 && _g255(color) > 210 && _b255(color) < 170;
  }

  // Dialog-specific ink colours — from HL_SWATCHES.ink in bundle1.jsx.
  // These are darker/more saturated than the NyanColors.highlightInk* tokens,
  // which are lighter variants used for text-highlight backgrounds elsewhere.
  static const Color _inkYellow = Color(0xFFB89A2C);
  static const Color _inkGreen  = Color(0xFF4E8A2D);
  static const Color _inkBlue   = Color(0xFF2E6B96);
  static const Color _inkPink   = Color(0xFFA84070);
  static const Color _inkOrange = Color(0xFFB8662A);

  static Color displayHighlight(Color color) {
    if (isYellowHighlight(color)) return _inkYellow;
    final r = _r255(color);
    final g = _g255(color);
    final b = _b255(color);
    if (b > r && b > g) return _inkBlue;
    if (r > 220 && b > 150) return _inkPink;
    if (r > 220 && g > 150 && b < 150) return _inkOrange;
    if (g > r && g > b) return _inkGreen;
    return Color.alphaBlend(NyanColors.highlightPaperLiftTint, color);
  }
}

class _SelectedColorBadge extends StatelessWidget {
  const _SelectedColorBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final nyan = context.nyanTheme;
    final inkColor = _HighlightDialogPalette.displayHighlight(color);
    // Spec: color-mix(in srgb, ink 88%, nyan-text) — strongly tinted toward the ink.
    final iconColor = Color.lerp(nyan.textPrimary, inkColor, 0.88)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _HighlightDialogPalette.badgeSurface(context, color),
        border: Border.all(
          color: inkColor.withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      child: SizedBox(
        width: 24,
        height: 24,
        child: Icon(NyanIcons.editNote, size: 12, color: iconColor),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.nyanTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(_HighlightNoteDialogTokens.pickerRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < colors.length; i++) ...[
            _HighlightColorSwatch(
              color: _parseColor(colors[i]),
              isSelected: colors[i] == selectedColorCode,
              onTap: () => onSelected(colors[i]),
            ),
            if (i != colors.length - 1) const SizedBox(width: 16),
          ],
        ],
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
    final nyan = context.nyanTheme;
    final inkColor = _HighlightDialogPalette.displayHighlight(color);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: _HighlightNoteDialogTokens.pickerSwatchSize,
        height: _HighlightNoteDialogTokens.pickerSwatchSize,
        decoration: BoxDecoration(
          // Swatch shows the highlight fill colour, not the ink variant.
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? null
              : Border.all(color: inkColor.withValues(alpha: 0.20), width: 1),
          boxShadow: isSelected
              ? [
                  // Outer matcha ring — drawn first (bottommost layer).
                  BoxShadow(
                    color: nyan.primaryDeep,
                    blurRadius: 0,
                    spreadRadius: 3,
                    offset: Offset.zero,
                  ),
                  // surfaceMuted gap — drawn second (top layer), creates 2 px gap.
                  BoxShadow(
                    color: nyan.surfaceMuted,
                    blurRadius: 0,
                    spreadRadius: 2,
                    offset: Offset.zero,
                  ),
                ]
              : const [],
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
    final nyan = context.nyanTheme;
    final inkColor = _HighlightDialogPalette.displayHighlight(highlightColor);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: _HighlightNoteDialogTokens.previewMinHeight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _HighlightDialogPalette.previewBackground(context, highlightColor),
        borderRadius: BorderRadius.circular(_HighlightNoteDialogTokens.previewRadius),
        border: Border.all(
          color: _HighlightDialogPalette.previewBorder(context, highlightColor),
          width: 1,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vertical accent bar — stretches to match text height.
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                width: 2.5,
                decoration: BoxDecoration(
                  color: inkColor.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.38,
                  color: nyan.textPrimary.withValues(alpha: 0.88),
                ),
              ),
            ),
          ],
        ),
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
    final nyan = context.nyanTheme;
    final primaryText = nyan.textPrimary.withValues(alpha: 0.94);
    // Solid blend: 88% surfaceMuted + 12% surface (matches spec's color-mix).
    final inputBg = Color.lerp(nyan.surface, nyan.surfaceMuted, 0.88)!;
    final mergedListenable = Listenable.merge([focusNode, controller]);

    return ListenableBuilder(
      listenable: mergedListenable,
      builder: (context, _) {
        final isFocused = focusNode.hasFocus;
        final hasText = controller.text.isNotEmpty;
        final borderColor = isFocused
            ? nyan.primary.withValues(alpha: 0.30)
            : nyan.divider.withValues(alpha: 0.42);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: _HighlightNoteDialogTokens.inputMinHeight,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: _HighlightNoteDialogTokens.inputPadding,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(_HighlightNoteDialogTokens.inputRadius),
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
                          color: nyan.textSecondary.withValues(alpha: 0.74),
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
    required this.onTap,
  });

  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NyanRadius.control),
          child: SizedBox(
            width: _HighlightNoteDialogTokens.iconButtonTapSize,
            height: _HighlightNoteDialogTokens.iconButtonTapSize,
            child: Center(
              child: Icon(
                NyanIcons.delete,
                size: 19,
                color: context.nyanTheme.textMuted,
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
