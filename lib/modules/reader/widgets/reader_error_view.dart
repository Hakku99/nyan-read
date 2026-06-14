import 'package:flutter/material.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import '../../../../core/theme/nyan_radius.dart';
import '../../../../core/theme/nyan_spacing.dart';
import '../../../../core/theme/nyan_typography.dart';
import '../../../../core/ui/components/nyan_primary_button.dart';
import '../../../../core/ui/nyan_theme_context.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../reader_error.dart';

/// Per-error-type display data matching the U8 design spec.
class _ErrorMeta {
  const _ErrorMeta({
    required this.icon,
    required this.getTitle,
    required this.getBody,
    required this.showRetry,
    required this.showTechDetails,
  });

  final IconData icon;
  final String Function(AppLocalizations) getTitle;
  final String Function(AppLocalizations) getBody;
  final bool showRetry;
  final bool showTechDetails;
}

const _kIconContainerSize = 84.0;
const _kIconSize = 36.0;
const _kIconOpacity = 0.82;
const _kIconBgAlpha = 0.08;
const _kIconBorderAlpha = 0.22;
const _kTitleOpacity = 0.84;
const _kBodyOpacity = 0.74;
const _kBodyMaxWidth = 268.0;

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

  _ErrorMeta _metaFor(ReaderErrorType type) {
    return switch (type) {
      ReaderErrorType.fileNotFound => _ErrorMeta(
          icon: NyanIcons.compass,
          getTitle: (l) => l.errorFileNotFoundTitle,
          getBody: (l) => l.errorFileNotFoundBody,
          showRetry: false,
          showTechDetails: false,
        ),
      ReaderErrorType.parseFailed => _ErrorMeta(
          icon: NyanIcons.error,
          getTitle: (l) => l.errorParseFailedTitle,
          getBody: (l) => l.errorParseFailedBody,
          showRetry: true,
          showTechDetails: true,
        ),
      ReaderErrorType.unsupportedFormat => _ErrorMeta(
          icon: NyanIcons.fileDashed,
          getTitle: (l) => l.errorUnsupportedFormatTitle,
          getBody: (l) => l.errorUnsupportedFormatBody,
          showRetry: false,
          showTechDetails: false,
        ),
      ReaderErrorType.unknown => _ErrorMeta(
          icon: NyanIcons.error,
          getTitle: (l) => l.errorUnknownTitle,
          getBody: (l) => l.errorUnknownBody,
          showRetry: widget.onRetry != null,
          showTechDetails: false,
        ),
    };
  }

  Future<void> _reportError(AppLocalizations loc) async {
    final errorText =
        widget.errorState.technicalMessage ?? _metaFor(widget.errorState.type).getBody(loc);
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'ivanlee9906@gmail.com',
      query: _encodeQueryParameters(<String, String>{
        'subject': 'Nyan Read Error Report',
        'body': 'Error Details:\n$errorText',
      }),
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) SnackBarUtils.show(context, loc.couldNotLaunchEmail, tone: NyanSnackTone.error);
      }
    } catch (e) {
      if (mounted) SnackBarUtils.show(context, loc.failedToOpenEmail(e.toString()), tone: NyanSnackTone.error);
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final nyan = context.nyanTheme;
    final meta = _metaFor(widget.errorState.type);

    final errorPrimary = nyan.errorPrimaryTextColor;

    // Icon container: error-primary @8% tint into surface — matches CSS
    // `color-mix(in srgb, var(--error-primary) 8%, var(--nyan-surface))`.
    final iconBg = Color.lerp(nyan.surface, errorPrimary, _kIconBgAlpha)!;
    final iconBorder = errorPrimary.withValues(alpha: _kIconBorderAlpha);

    return Container(
      color: nyan.background,
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: NyanSpacing.space32,
        vertical: NyanSpacing.space32,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Circular icon wash ──────────────────────────────────────────
          Container(
            width: _kIconContainerSize,
            height: _kIconContainerSize,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              border: Border.all(color: iconBorder, width: 0.7),
            ),
            child: Center(
              child: Opacity(
                opacity: _kIconOpacity,
                child: Icon(meta.icon, size: _kIconSize, color: errorPrimary),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ── Title ───────────────────────────────────────────────────────
          Opacity(
            opacity: _kTitleOpacity,
            child: Text(
              meta.getTitle(loc),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: NyanTypography.uiFontFamily,
                // 18pt is between ladder steps (section=20, body=16).
                // U8 spec: `font: "600 18px/1.25"` — AGENTS.md §4.6 delivery-package priority.
                // Exception documented in AGENTS.md §4.2.5.
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: nyan.textPrimary,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Body ────────────────────────────────────────────────────────
          Opacity(
            opacity: _kBodyOpacity,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kBodyMaxWidth),
              child: Text(
                meta.getBody(loc),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: NyanTypography.uiFontFamily,
                  // 14pt is between ladder steps (body=16, meta=13).
                  // U8 spec: `font: "400 14px/1.5"` — AGENTS.md §4.6 delivery-package priority.
                  // Exception documented in AGENTS.md §4.2.5.
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: nyan.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),

          // ── Action buttons ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NyanPrimaryButton(
                label: loc.backToBookshelf,
                onPressed: widget.onBack,
                icon: const Icon(NyanIcons.back),
                variant: NyanPrimaryButtonVariant.ghost,
              ),
              if (meta.showRetry && widget.onRetry != null) ...[
                const SizedBox(width: 10),
                NyanPrimaryButton(
                  label: loc.retry,
                  onPressed: widget.onRetry,
                  icon: const Icon(NyanIcons.refresh),
                  variant: NyanPrimaryButtonVariant.primary,
                ),
              ],
            ],
          ),

          // ── Report link ─────────────────────────────────────────────────
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _reportError(loc),
            child: SizedBox(
              height: NyanSpacing.minTapTarget,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(NyanIcons.bugBeetle, size: 15, color: nyan.textMuted),
                  const SizedBox(width: 7),
                  Text(
                    loc.reportToDeveloper,
                    style: TextStyle(
                      fontFamily: NyanTypography.uiFontFamily,
                      fontSize: NyanTypography.meta, // 13px w500
                      fontWeight: FontWeight.w500,
                      color: nyan.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Tech details (parseFailed only) ─────────────────────────────
          if (meta.showTechDetails && widget.errorState.technicalMessage != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _showDetails = !_showDetails),
              child: SizedBox(
                height: NyanSpacing.minTapTarget,
                child: Center(
                  child: Text(
                    _showDetails ? loc.hideTechnicalDetails : loc.showTechnicalDetails,
                    style: TextStyle(
                      fontFamily: NyanTypography.uiFontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: nyan.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            if (_showDetails) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: nyan.surfaceMuted,
                    borderRadius: BorderRadius.circular(NyanRadius.chip),
                    border: Border.all(color: nyan.divider),
                  ),
                  width: double.infinity,
                  child: SelectableText(
                    widget.errorState.technicalMessage!,
                    style: TextStyle(
                      fontFamily: NyanTypography.monoFontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                      color: nyan.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
