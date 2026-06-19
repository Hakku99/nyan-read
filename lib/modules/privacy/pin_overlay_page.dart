import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nyan_read/core/theme/nyan_colors.dart';
import 'package:nyan_read/core/theme/nyan_radius.dart';
import 'package:nyan_read/core/theme/nyan_shadows.dart';
import 'package:nyan_read/core/theme/nyan_spacing.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/pin_service.dart';
import 'widgets/pin_input_widget.dart';

enum PinOverlayMode { setup, verify, change }

/// Full-screen PIN takeover (U16). Light branch uses resolved NyanTheme tokens;
/// dark branch uses bespoke ink literals (`#1D211E` / `#E8E1D5`) matching the
/// handoff mock — see AGENTS.md §4.2.1 for the documented exception.
/// Source: `screens/bundle4.jsx` `PinOverlay`.
class PinOverlayPage extends StatefulWidget {
  final PinOverlayMode mode;
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;

  /// Injected by [PrivacyLockService]. Null in setup/change modes — the
  /// fingerprint button is never shown outside of verify mode.
  final BiometricService? biometricService;

  const PinOverlayPage({
    super.key,
    required this.mode,
    this.onSuccess,
    this.onCancel,
    this.biometricService,
  });

  @override
  State<PinOverlayPage> createState() => _PinOverlayPageState();
}

class _PinOverlayPageState extends State<PinOverlayPage> {
  final _pinService = PinService.instance;
  bool _isError = false;
  String? _firstPin;
  bool _biometricAvailable = false;

  // Cancelled in dispose and on every new error to prevent stale callbacks.
  Timer? _errorResetTimer;

  // Increments only on deliberate step transitions (not on error) so the
  // existing PinInputWidget instance can play its shake before being replaced.
  int _widgetGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (widget.biometricService != null &&
        widget.mode == PinOverlayMode.verify) {
      widget.biometricService!.isAvailable().then((available) {
        if (mounted) setState(() => _biometricAvailable = available);
      });
    }
  }

  @override
  void dispose() {
    _errorResetTimer?.cancel();
    super.dispose();
  }

  String _title(AppLocalizations loc) {
    switch (widget.mode) {
      case PinOverlayMode.setup:
      case PinOverlayMode.change:
        return _firstPin == null ? loc.pinSet : loc.pinConfirm;
      case PinOverlayMode.verify:
        return loc.pinEnter;
    }
  }

  String _subtitle(AppLocalizations loc) {
    switch (widget.mode) {
      case PinOverlayMode.setup:
      case PinOverlayMode.change:
        return _firstPin == null
            ? loc.pinSubtitleSetup
            : loc.pinSubtitleConfirm;
      case PinOverlayMode.verify:
        return loc.pinSubtitleVerify;
    }
  }

  Future<void> _handlePinComplete(String pin) async {
    if (widget.mode == PinOverlayMode.verify) {
      await _handleVerify(pin);
    } else {
      await _handleSetOrChange(pin);
    }
  }

  Future<void> _handleSetOrChange(String pin) async {
    if (_firstPin == null) {
      setState(() {
        _firstPin = pin;
        _isError = false;
        _widgetGeneration++;
      });
    } else {
      if (_firstPin == pin) {
        _errorResetTimer?.cancel();
        await _pinService.setPin(pin);
        widget.onSuccess?.call();
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _showErrorThenReset();
      }
    }
  }

  Future<void> _handleVerify(String pin) async {
    final isValid = await _pinService.verifyPin(pin);
    if (isValid) {
      _errorResetTimer?.cancel();
      widget.onSuccess?.call();
      if (mounted) Navigator.of(context).pop(true);
    } else {
      _showErrorThenReset();
    }
  }

  /// Shows the error for ~2 s, then resets. Does NOT bump the generation
  /// immediately so PinInputWidget can play its shake animation first.
  void _showErrorThenReset() {
    setState(() => _isError = true);
    _errorResetTimer?.cancel();
    _errorResetTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() {
        _isError = false;
        _firstPin = null;
        _widgetGeneration++;
      });
    });
  }

  void _onWidgetErrorAnimationDone() {
    // Intentionally empty — error visibility is driven by _errorResetTimer.
  }

  Future<void> _handleBiometric() async {
    final loc = AppLocalizations.of(context)!;
    final success = await widget.biometricService!
        .authenticate(loc.pinBiometricReason);
    if (success && mounted) {
      widget.onSuccess?.call();
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final nyan = resolveNyanTheme(Theme.of(context));
    final isDark = nyan.brightness == Brightness.dark;

    // Background + foreground ink — bespoke in dark, token-resolved in light.
    final bg = isDark ? NyanColors.pinOverlayInkBackground : nyan.background;
    final fg = isDark ? NyanColors.pinOverlayInk : nyan.textPrimary;

    // Colours resolved for PinInputWidget.
    final dotFill = nyan.primary; // primary (matcha/sage) fills dots
    final dotRing = fg.withValues(alpha: 0.26);
    final dotError = nyan.errorPrimaryTextColor;
    final keyBg =
        isDark ? NyanColors.pinOverlayInk.withValues(alpha: 0.09) : nyan.surface;
    final keyShadow = isDark ? const <BoxShadow>[] : NyanShadows.subtle(nyan);
    final keyText = fg;
    final ghostColor = isDark
        ? NyanColors.pinOverlayInk.withValues(alpha: 0.52)
        : nyan.textMuted;

    // Spacing around subtitle: shrinks when error hint takes space.
    final subtitleBottom = _isError ? 22.0 : 38.0;
    final padAboveKeypad = _isError ? 28.0 : 42.0;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Soft matcha bloom behind the medallion — paper-warm, very low alpha.
            Positioned(
              top: MediaQuery.of(context).size.height * 0.13,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        nyan.primary.withValues(alpha: 0.15),
                        nyan.primary.withValues(alpha: 0),
                      ],
                      stops: const [0.0, 0.68],
                    ),
                  ),
                ),
              ),
            ),

            // Main content — vertically centred.
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: NyanSpacing.space24 + 4, // mock: 28px
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lock medallion — 76×76 card-radius tile, shadow + ring.
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        // color-mix(in srgb, primary 11%, surface) — opaque blend, not alpha
                        color: Color.lerp(nyan.surface, nyan.primary, 0.11)!,
                        borderRadius:
                            BorderRadius.circular(NyanRadius.card),
                        boxShadow: NyanShadows.lightCard(nyan),
                        border: Border.all(
                          color: nyan.primary.withValues(alpha: 0.26),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        NyanIcons.lockFilled,
                        size: 31,
                        color: nyan.primary,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // "PRIVACY SHELF" eyebrow — .nyan-caption has text-transform:uppercase
                    Text(
                      loc.pinEyebrow.toUpperCase(),
                      style: NyanTypography.eyebrowStyle(nyan.primaryDeep),
                    ),
                    const SizedBox(height: 9),

                    // Title — 22pt / w600 / -0.2 tracking
                    Text(
                      _title(loc),
                      style: TextStyle(
                        fontFamily: NyanTypography.uiFontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      _subtitle(loc),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: NyanTypography.uiFontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        height: 1.45,
                        color: isDark
                            ? NyanColors.pinOverlayInk.withValues(alpha: 0.55)
                            : nyan.textMuted,
                      ),
                    ),
                    SizedBox(height: subtitleBottom),

                    // PIN dots (shaking + error-coloured inside widget)
                    PinInputWidget(
                      key: ValueKey(_widgetGeneration),
                      onPinComplete: _handlePinComplete,
                      dotFill: dotFill,
                      dotRing: dotRing,
                      dotError: dotError,
                      keyBackground: keyBg,
                      keyShadow: keyShadow,
                      keyText: keyText,
                      ghostColor: ghostColor,
                      isError: _isError,
                      showBiometric: _biometricAvailable &&
                          widget.mode == PinOverlayMode.verify,
                      onBiometricTap: _handleBiometric,
                      onError: _onWidgetErrorAnimationDone,
                    ),

                    // Error hint — visible for the full 2 s timer window.
                    if (_isError) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            NyanIcons.warningCircleFilled,
                            size: 15,
                            color: dotError,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            loc.pinMismatch,
                            style: TextStyle(
                              fontFamily: NyanTypography.uiFontFamily,
                              fontSize: NyanTypography.meta,
                              fontWeight: FontWeight.w500,
                              color: dotError,
                            ),
                          ),
                        ],
                      ),
                    ],

                    SizedBox(height: padAboveKeypad),

                    // Footer — "Forgot PIN?" or device-only reassurance.
                    _buildFooter(loc, nyan, isDark),
                    const SizedBox(height: NyanSpacing.space24),
                  ],
                ),
              ),
            ),

            // Cancel X (top-right).
            Positioned(
              top: NyanSpacing.space16,
              right: NyanSpacing.space16,
              child: SizedBox(
                width: 42,
                height: 42,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      widget.onCancel?.call();
                      Navigator.of(context).pop(false);
                    },
                    customBorder: const CircleBorder(),
                    child: Center(
                      child: Icon(
                        NyanIcons.close,
                        size: 20,
                        color: isDark
                            ? NyanColors.pinOverlayInk.withValues(alpha: 0.52)
                            : nyan.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(
      AppLocalizations loc, NyanTheme nyan, bool isDark) {
    if (widget.mode == PinOverlayMode.verify) {
      return TextButton(
        onPressed: () {
          // TODO(#pin-forgot): implement forgot-PIN recovery flow
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          loc.pinForgot,
          style: TextStyle(
            fontFamily: NyanTypography.uiFontFamily,
            fontSize: NyanTypography.meta,
            fontWeight: FontWeight.w500,
            color: nyan.primaryDeep,
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          NyanIcons.shieldCheckFilled,
          size: 14,
          color: nyan.primary,
        ),
        const SizedBox(width: 6),
        Text(
          loc.pinStoredDeviceOnly,
          style: TextStyle(
            fontFamily: NyanTypography.uiFontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: isDark
                ? NyanColors.pinOverlayInk.withValues(alpha: 0.52)
                : nyan.textMuted,
          ),
        ),
      ],
    );
  }
}
