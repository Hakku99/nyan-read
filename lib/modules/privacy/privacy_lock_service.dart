import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/pin_service.dart';
import '../../core/services/riverpod_providers.dart';
import '../../core/utils/snackbar_utils.dart';
import '../bookshelf/bookshelf_view_model.dart';
import '../bookshelf/bookshelf_view_model_provider.dart';
import 'forgot_pin_sheet.dart';
import 'pin_overlay_page.dart';

/// Assembled here rather than in core's riverpod_providers: this facade
/// pushes Presentation overlays (PinOverlayPage), so core must not import
/// it — the provider lives with the module (§3.2 layer matrix, review #12).
/// Stateless, so a plain Provider is its singleton.
final privacyLockServiceRpProvider = Provider<PrivacyLockService>((ref) {
  return PrivacyLockService(
    ref.read(pinServiceRpProvider),
    ref.read(biometricServiceRpProvider),
    // Lazy: the shelf VM is only needed if the user picks "erase".
    () => ref.read(bookshelfViewModelRpProvider),
  );
});

/// Facade over PIN + biometric unlock flows, with constructor-injected
/// services (§2.3); UI obtains it via [privacyLockServiceRpProvider].
class PrivacyLockService {
  PrivacyLockService(this._pinService, this._biometricService, this._shelf);

  final PinService _pinService;
  final BiometricService _biometricService;
  final BookshelfViewModel Function() _shelf;

  /// Check if a PIN has been set up
  Future<bool> hasPassword() async {
    return await _pinService.hasPinSet();
  }

  /// Verify password (kept for backward compatibility, delegates to PIN)
  Future<bool> verifyPassword(String input) async {
    if (input.length == 4 && RegExp(r'^\d{4}$').hasMatch(input)) {
      return await _pinService.verifyPin(input);
    }
    return false;
  }

  /// Set password (kept for backward compatibility, delegates to PIN)
  Future<void> setPassword(String password) async {
    if (password.length == 4 && RegExp(r'^\d{4}$').hasMatch(password)) {
      await _pinService.setPin(password);
    }
  }

  /// Show PIN setup overlay
  Future<bool> showPinSetup(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PinOverlayPage(
          mode: PinOverlayMode.setup,
          pinService: _pinService,
        ),
        opaque: false,
        barrierDismissible: false,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    return result ?? false;
  }

  /// First-time PIN setup that refuses to hand over existing private books.
  ///
  /// With no PIN, plain [showPinSetup] unlocks the shelf for whoever sets one.
  /// That is fine for an empty shelf, but private rows can outlive the PIN
  /// (backup restore, DB self-heal after a forgot-PIN erase), so when any
  /// exist the user must prove ownership via the forgot-PIN flow instead.
  /// Fails closed: if the check itself errors, assume books exist.
  Future<bool> showPinSetupGuarded(BuildContext context) async {
    bool hasBooks;
    try {
      hasBooks = await _shelf().hasAnyPrivateBooks();
    } catch (e) {
      debugPrint('[PrivacyLockService] private book check failed: $e');
      hasBooks = true;
    }
    if (!context.mounted) return false;
    if (!hasBooks) return showPinSetup(context);
    return await runForgotPinFlow(context) == ForgotPinOutcome.pinReset;
  }

  /// Show PIN verification overlay
  Future<bool> showPinVerify(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PinOverlayPage(
          mode: PinOverlayMode.verify,
          pinService: _pinService,
          biometricService: _biometricService,
          onForgotPin: runForgotPinFlow,
        ),
        opaque: false,
        barrierDismissible: false,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    return result ?? false;
  }

  /// "Forgot PIN?" recovery. Two exits, neither of which ever leaves the
  /// private shelf reachable without proof of ownership:
  ///
  /// * verify with the device lock → set a NEW PIN (overwrites via setPin on
  ///   confirm, so backing out keeps the old PIN — never a PIN-less shelf);
  /// * erase the shelf → delete every private book FIRST, clear the PIN only
  ///   once none remain (a kill in between leaves an empty shelf + old PIN,
  ///   not an open shelf).
  ///
  /// There is deliberately no "move private books to public": that would let
  /// anyone holding the phone expose them with one tap.
  Future<ForgotPinOutcome> runForgotPinFlow(BuildContext context) async {
    final deviceAuth = await _biometricService.isDeviceAuthSupported();
    if (!context.mounted) return ForgotPinOutcome.cancelled;
    final choice =
        await showForgotPinSheet(context, deviceAuthAvailable: deviceAuth);
    if (choice == null || !context.mounted) return ForgotPinOutcome.cancelled;

    switch (choice) {
      case ForgotPinChoice.verifyDevice:
        return _recoverWithDeviceLock(context);
      case ForgotPinChoice.eraseShelf:
        return _eraseShelf(context);
    }
  }

  Future<ForgotPinOutcome> _recoverWithDeviceLock(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final result = await _biometricService.authenticate(
      loc.pinForgotDeviceReason,
      biometricOnly: false,
    );
    if (!context.mounted) return ForgotPinOutcome.cancelled;
    if (result == BiometricResult.error) {
      SnackBarUtils.show(context, loc.pinDeviceAuthUnavailable,
          tone: NyanSnackTone.error);
      return ForgotPinOutcome.cancelled;
    }
    if (result != BiometricResult.success) return ForgotPinOutcome.cancelled;

    final created = await showPinSetup(context);
    return created ? ForgotPinOutcome.pinReset : ForgotPinOutcome.cancelled;
  }

  Future<ForgotPinOutcome> _eraseShelf(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    if (!await showEraseShelfConfirmSheet(context)) {
      return ForgotPinOutcome.cancelled;
    }
    if (!context.mounted) return ForgotPinOutcome.cancelled;
    try {
      await _shelf().eraseAllPrivateBooks();
      await _pinService.resetPin();
    } catch (e) {
      debugPrint('[PrivacyLockService] erase private shelf failed: $e');
      if (context.mounted) {
        SnackBarUtils.show(context, loc.pinEraseFailed,
            tone: NyanSnackTone.error);
      }
      return ForgotPinOutcome.cancelled;
    }
    if (context.mounted) {
      SnackBarUtils.show(context, loc.pinEraseDone,
          description: loc.pinEraseDoneDesc, tone: NyanSnackTone.success);
    }
    return ForgotPinOutcome.erased;
  }
}
