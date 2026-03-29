import 'package:flutter/material.dart';

import '../../theme/nyan_radius.dart';
import '../../theme/nyan_spacing.dart';
import 'nyan_info_card.dart';
import 'nyan_primary_button.dart';

class NyanSecureFieldConfig {
  const NyanSecureFieldConfig({
    required this.label,
    required this.controller,
    this.autofocus = false,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final bool autofocus;
  final TextInputAction? textInputAction;
}

Future<bool?> showNyanSecureEntryDialog(
  BuildContext context, {
  required String title,
  String? description,
  required List<NyanSecureFieldConfig> fields,
  required String confirmLabel,
  required String cancelLabel,
  required Future<String?> Function(List<String> values) onConfirm,
  IconData icon = Icons.lock_outline_rounded,
  bool barrierDismissible = true,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => NyanSecureEntryDialog(
      title: title,
      description: description,
      fields: fields,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      onConfirm: onConfirm,
      icon: icon,
    ),
  );
}

class NyanSecureEntryDialog extends StatefulWidget {
  const NyanSecureEntryDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    this.description,
    this.icon = Icons.lock_outline_rounded,
  });

  final String title;
  final String? description;
  final List<NyanSecureFieldConfig> fields;
  final String confirmLabel;
  final String cancelLabel;
  final Future<String?> Function(List<String> values) onConfirm;
  final IconData icon;

  @override
  State<NyanSecureEntryDialog> createState() => _NyanSecureEntryDialogState();
}

class _NyanSecureEntryDialogState extends State<NyanSecureEntryDialog> {
  bool _isSubmitting = false;
  bool _obscureText = true;
  String? _errorText;

  Future<void> _handleConfirm() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final result = await widget.onConfirm([
      for (final field in widget.fields) field.controller.text.trim(),
    ]);

    if (!mounted) return;

    if (result == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _errorText = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: NyanSpacing.space24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: NyanInfoCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(NyanRadius.input),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: NyanSpacing.space12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: NyanSpacing.space4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.08,
                          ),
                        ),
                        if (widget.description != null) ...[
                          const SizedBox(height: NyanSpacing.space8),
                          Text(
                            widget.description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.35,
                              color: theme.textTheme.bodyMedium?.color?.withValues(
                                alpha: 0.78,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NyanSpacing.space16),
            for (var index = 0; index < widget.fields.length; index++) ...[
              _SecureTextField(
                label: widget.fields[index].label,
                controller: widget.fields[index].controller,
                autofocus: widget.fields[index].autofocus,
                obscureText: _obscureText,
                textInputAction: widget.fields[index].textInputAction ??
                    (index == widget.fields.length - 1
                        ? TextInputAction.done
                        : TextInputAction.next),
                onSubmitted: index == widget.fields.length - 1
                    ? (_) => _handleConfirm()
                    : null,
                onToggleVisibility: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              ),
              if (index != widget.fields.length - 1)
                const SizedBox(height: NyanSpacing.space12),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: NyanSpacing.space12),
              Text(
                _errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error.withValues(alpha: 0.88),
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: NyanSpacing.space20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(NyanSpacing.minTapTarget),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(NyanRadius.input),
                      ),
                    ),
                    child: Text(widget.cancelLabel),
                  ),
                ),
                const SizedBox(width: NyanSpacing.space12),
                Expanded(
                  child: NyanPrimaryButton(
                    label: widget.confirmLabel,
                    expanded: true,
                    onPressed: _isSubmitting ? null : _handleConfirm,
                    padding: const EdgeInsets.symmetric(
                      horizontal: NyanSpacing.space16,
                      vertical: NyanSpacing.space12,
                    ),
                    icon: _isSubmitting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SecureTextField extends StatelessWidget {
  const _SecureTextField({
    required this.label,
    required this.controller,
    required this.obscureText,
    required this.onToggleVisibility,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: theme.colorScheme.surface.withValues(alpha: isDark ? 0.22 : 0.56),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: NyanSpacing.space16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NyanRadius.input),
          borderSide: BorderSide(
            color: theme.dividerColor.withValues(alpha: isDark ? 0.22 : 0.28),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NyanRadius.input),
          borderSide: BorderSide(
            color: theme.dividerColor.withValues(alpha: isDark ? 0.22 : 0.28),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NyanRadius.input),
          borderSide: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
            width: 1.1,
          ),
        ),
        suffixIcon: IconButton(
          onPressed: onToggleVisibility,
          icon: Icon(
            obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 20,
          ),
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.76),
        ),
      ),
    );
  }
}
