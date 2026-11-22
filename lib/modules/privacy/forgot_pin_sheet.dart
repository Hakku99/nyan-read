import 'package:flutter/material.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import '../../core/theme/nyan_radius.dart';
import '../../core/theme/nyan_spacing.dart';
import '../../core/theme/nyan_typography.dart';
import '../../core/ui/components/components.dart';
import '../../core/ui/nyan_icons.dart';
import '../../core/ui/nyan_sheet.dart';
import '../../core/ui/nyan_theme_context.dart';

/// What the user picked on the "Forgot PIN?" sheet.
enum ForgotPinChoice { verifyDevice, eraseShelf }

/// How the forgot-PIN flow ended, from the PIN overlay's point of view.
enum ForgotPinOutcome {
  /// Backed out (or verification failed): the overlay stays open.
  cancelled,

  /// Owner proved identity and set a new PIN: treat as unlocked.
  pinReset,

  /// Private shelf erased and PIN cleared: nothing left to unlock.
  erased,
}

/// "Forgot PIN?" recovery picker. [deviceAuthAvailable] hides the keep-books
/// path on devices with no lock screen / biometrics, where the only way to
/// prove ownership does not exist.
Future<ForgotPinChoice?> showForgotPinSheet(
  BuildContext context, {
  required bool deviceAuthAvailable,
}) {
  return showNyanSheet<ForgotPinChoice>(
    context: context,
    builder: (ctx) {
      final loc = AppLocalizations.of(ctx)!;
      final nyan = ctx.nyanTheme;
      return NyanOnePaperSheet(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            NyanSpacing.space16,
            NyanSpacing.space16,
            NyanSpacing.space16,
            NyanSpacing.space16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: NyanSpacing.space8),
                child: Text(
                  loc.pinForgotSheetTitle,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: NyanTypography.section,
                    fontWeight: FontWeight.w600,
                    color: nyan.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: NyanSpacing.space8),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: NyanSpacing.space8),
                child: Text(
                  loc.pinForgotSheetBody,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: NyanTypography.meta,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                    color: nyan.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: NyanSpacing.space12),
              if (deviceAuthAvailable)
                NyanActionSheetRow(
                  icon: NyanIcons.fingerprint,
                  title: loc.pinForgotVerifyTitle,
                  subtitle: loc.pinForgotVerifySubtitle,
                  onTap: () =>
                      Navigator.of(ctx).pop(ForgotPinChoice.verifyDevice),
                ),
              NyanActionSheetRow(
                icon: NyanIcons.delete,
                title: loc.pinForgotEraseTitle,
                subtitle: loc.pinForgotEraseSubtitle,
                onTap: () => Navigator.of(ctx).pop(ForgotPinChoice.eraseShelf),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Destructive confirmation for the erase path. Returns true only on an
/// explicit tap of the Erase button.
Future<bool> showEraseShelfConfirmSheet(BuildContext context) async {
  final result = await showNyanSheet<bool>(
    context: context,
    builder: (ctx) {
      final loc = AppLocalizations.of(ctx)!;
      final nyan = ctx.nyanTheme;
      return NyanOnePaperSheet(
        child: Padding(
          padding: const EdgeInsets.all(NyanSpacing.space16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: NyanSpacing.space8),
                child: Text(
                  loc.pinEraseConfirmTitle,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: NyanTypography.section,
                    fontWeight: FontWeight.w600,
                    color: nyan.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: NyanSpacing.space8),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: NyanSpacing.space8),
                child: Text(
                  loc.pinEraseConfirmBody,
                  style: TextStyle(
                    fontFamily: NyanTypography.uiFontFamily,
                    fontSize: NyanTypography.meta,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: nyan.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: NyanSpacing.space16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: Container(
                        height: NyanSpacing.minTapTarget + 6,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(NyanRadius.cardNested),
                          border: Border.all(
                            color: nyan.divider.withValues(alpha: 0.60),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          loc.cancel,
                          style: TextStyle(
                            fontFamily: NyanTypography.uiFontFamily,
                            fontSize: NyanTypography.body,
                            fontWeight: FontWeight.w600,
                            color: nyan.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: NyanSpacing.space8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Container(
                        height: NyanSpacing.minTapTarget + 6,
                        decoration: BoxDecoration(
                          color: nyan.errorPrimaryTextColor,
                          borderRadius:
                              BorderRadius.circular(NyanRadius.cardNested),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          loc.pinEraseConfirmAction,
                          style: TextStyle(
                            fontFamily: NyanTypography.uiFontFamily,
                            fontSize: NyanTypography.body,
                            fontWeight: FontWeight.w600,
                            color: nyan.surface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
