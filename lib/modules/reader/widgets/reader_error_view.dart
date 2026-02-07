import 'package:flutter/material.dart';
import '../../../../core/services/mascot_manager.dart';
import '../../../../core/theme/theme_presets.dart';
import '../reader_error.dart';

class ReaderErrorView extends StatefulWidget {
  final ReaderErrorState errorState;
  final VoidCallback onBack;
  final VoidCallback? onRetry;

  const ReaderErrorView({
    super.key,
    required this.errorState,
    required this.onBack,
    this.onRetry,
  });

  @override
  State<ReaderErrorView> createState() => _ReaderErrorViewState();
}

class _ReaderErrorViewState extends State<ReaderErrorView> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    // Find the NyanTheme from ThemePresets that matches the current theme if possible,
    // or we can just access it from the current context if we had a ThemeProvider.
    // However, ReaderPage sets the theme dynamically in its build.
    // We should rely on a passed theme or look it up.
    // The requirement says "Error UI 不使用 Reader 背景色", and "必须使用专用 ErrorTheme".
    // We can lookup the current ThemePreset based on context or just use hardcoded style from NyanTheme.
    // Since ReaderPage might be wrapping us in a Theme, but we want a specific Error Theme.
    // We'll iterate the presets to find the matching one, or just use a default safe one if not found.
    // Actually, we can get the colors from the Theme extension if we had one, but we added them to NyanTheme.

    // HACK: Since we don't have easy access to the current NyanTheme object (it's not in the context directly, only ThemeData is),
    // we will try to find the NyanTheme that matches the scaffoldBackgroundColor or primary color.
    // OR, better, we pass the NyanTheme to this widget.
    // But for now, let's assume we can find it.

    final currentScaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    final nyanTheme = themePresets.values.firstWhere(
      (t) => t.background == currentScaffoldColor,
      orElse: () => themePresets[ThemePreset.creamLight]!,
    );

    final errorBg = nyanTheme.errorBackgroundColor;
    final errorPrimary = nyanTheme.errorPrimaryTextColor;
    final errorSecondary = nyanTheme.errorSecondaryTextColor;
    final errorAccent = nyanTheme.errorAccentColor;

    return Container(
      color: errorBg,
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MascotManager().render(
            MascotScene.error,
            size: 120,
            color: errorPrimary,
          ),
          const SizedBox(height: 32),
          Text(
            widget.errorState.userMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: errorPrimary,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: widget.onBack,
                icon: Icon(Icons.arrow_back, color: errorSecondary),
                label: Text("返回书架", style: TextStyle(color: errorSecondary)),
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: widget.onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: errorAccent,
                    foregroundColor: errorPrimary,
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text("重试"),
                ),
              ],
            ],
          ),

          // Technical Details (Hidden by default)
          if (widget.errorState.technicalMessage != null) ...[
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => setState(() => _showDetails = !_showDetails),
              child: Text(
                _showDetails ? "隐藏技术细节" : "显示技术细节",
                style: TextStyle(
                  color: errorSecondary.withOpacity(0.5),
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            if (_showDetails) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: errorSecondary.withOpacity(0.1)),
                ),
                width: double.infinity,
                child: Text(
                  widget.errorState.technicalMessage!,
                  style: TextStyle(
                    fontFamily: 'Courier', // Monospace
                    fontSize: 11,
                    color: errorSecondary,
                  ),
                ),
              ),
            ]
          ]
        ],
      ),
    );
  }
}
