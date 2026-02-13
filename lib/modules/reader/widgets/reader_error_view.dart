import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import '../../../../core/services/mascot_manager.dart';
import '../../../../core/theme/theme_presets.dart';
import '../../../../core/utils/snackbar_utils.dart';
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

  Future<void> _reportError() async {
    final loc = AppLocalizations.of(context)!;
    final errorText =
        widget.errorState.technicalMessage ?? widget.errorState.userMessage;
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'ivanlee9906@gmail.com',
      query: _encodeQueryParameters(<String, String>{
        'subject': 'Nyan Read Error Report',
        'body': 'Error Details:\n$errorText',
      }),
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        if (mounted) {
          SnackBarUtils.show(context, loc.couldNotLaunchEmail);
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.show(context, loc.failedToOpenEmail(e.toString()));
      }
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
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
          SelectableText(
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
                label: Text(loc.backToBookshelf,
                    style: TextStyle(color: errorSecondary)),
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
                  label: Text(loc.retry),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _reportError,
            icon: Icon(Icons.bug_report, color: errorSecondary),
            label: Text(loc.reportToDeveloper,
                style: TextStyle(color: errorSecondary)),
          ),

          // Technical Details (Hidden by default)
          if (widget.errorState.technicalMessage != null) ...[
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => setState(() => _showDetails = !_showDetails),
              child: Text(
                _showDetails
                    ? loc.hideTechnicalDetails
                    : loc.showTechnicalDetails,
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
                child: SelectableText(
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
