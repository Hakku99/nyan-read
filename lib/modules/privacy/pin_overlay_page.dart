import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nyan_read/core/theme/nyan_colors.dart';
import 'package:nyan_read/core/theme/nyan_radius.dart';
import 'package:nyan_read/core/theme/nyan_spacing.dart';
import 'package:nyan_read/core/theme/nyan_typography.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import '../../../core/services/pin_service.dart';
import 'widgets/pin_input_widget.dart';

enum PinOverlayMode { setup, verify, change }

/// Full-screen PIN takeover (U16). A single layout, themed two ways:
/// cream-paper in light, bespoke ink (`#1D211E` / `#E8E1D5`) in dark — matching
/// the handoff mock literals exactly. The dark ink sits outside both NyanTheme
/// presets by design (AGENTS.md §4.2.1), so it is read from [NyanColors]
/// directly; the light branch uses the resolved [NyanTheme] tokens.
/// Source: `screens/bundle4.jsx` `PinOverlay`.
class PinOverlayPage extends StatefulWidget {
  final PinOverlayMode mode;
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;

  const PinOverlayPage({
    super.key,
    required this.mode,
    this.onSuccess,
    this.onCancel,
  });

  @override
  State<PinOverlayPage> createState() => _PinOverlayPageState();
}

class _PinOverlayPageState extends State<PinOverlayPage> {
  final _pinService = PinService.instance;
  bool _isError = false;
  String? _firstPin; // For setup/change mode confirmation

  // Keeps the error message visible long enough to read before resetting.
  // Cancelled in dispose and on every new error, to prevent stale callbacks.
  Timer? _errorResetTimer;

  // Drives the ValueKey on PinInputWidget. Increments only on deliberate
  // step transitions (step-1 → step-2 on first entry; reset → step-1 after
  // the error window ends). Critically, it does NOT change the moment an error
  // fires, so the existing widget instance receives isError:true via
  // didUpdateWidget and can play the shake animation.
  int _widgetGeneration = 0;

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

  Future<void> _handlePinComplete(String pin) async {
    if (widget.mode == PinOverlayMode.verify) {
      await _handleVerify(pin);
    } else {
      await _handleSetOrChange(pin);
    }
  }

  Future<void> _handleSetOrChange(String pin) async {
    if (_firstPin == null) {
      // Step 1 → step 2: bump the generation so a fresh widget is mounted for
      // the confirm step with an empty dot row.
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

  /// Shows the mismatch error for ~2 s, then resets to step 1.
  ///
  /// Intentionally does NOT flip [_firstPin] or [_widgetGeneration] right
  /// away: keeping those stable ensures the current [PinInputWidget] instance
  /// receives `isError: true` through `didUpdateWidget` and can fire its shake
  /// + clear animation before we bump the generation key.
  void _showErrorThenReset() {
    // Show the error and let the widget shake.
    setState(() {
      _isError = true;
    });

    _errorResetTimer?.cancel();
    _errorResetTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      // Now reset: clear error, go back to step-1, and mount a fresh widget.
      setState(() {
        _isError = false;
        _firstPin = null;
        _widgetGeneration++;
      });
    });
  }

  /// Called by [PinInputWidget] after its shake animation completes (≈320 ms).
  /// The page timer still owns the authoritative dismiss at t=2 s; this
  /// callback is a no-op so the message is not prematurely hidden.
  void _onWidgetErrorAnimationDone() {
    // Intentionally empty — error visibility is driven by _errorResetTimer.
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final nyan = resolveNyanTheme(Theme.of(context));
    final isDark = nyan.brightness == Brightness.dark;

    // Mock palette: light uses NyanTheme tokens, dark uses bespoke ink literals.
    final bg = isDark ? NyanColors.pinOverlayInkBackground : nyan.background;
    final fg = isDark ? NyanColors.pinOverlayInk : nyan.textPrimary;
    final subtle = isDark ? fg.withValues(alpha: 0.52) : nyan.textMuted;
    final lockTint = isDark
        ? fg.withValues(alpha: 0.12)
        : nyan.primary.withValues(alpha: 0.12);
    final lockIcon = isDark ? fg : nyan.primaryDeep;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Lock glyph — 56×56 rounded square, tinted (mock).
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: lockTint,
                      borderRadius: BorderRadius.circular(NyanRadius.cardNested),
                    ),
                    child: Icon(NyanIcons.lock, size: 26, color: lockIcon),
                  ),
                  const SizedBox(height: NyanSpacing.space20 + 2), // mock 22
                  // Title — section 20pt / w500 / +0.4 tracking.
                  Text(
                    _title(loc),
                    style: TextStyle(
                      fontFamily: NyanTypography.uiFontFamily,
                      fontSize: NyanTypography.section,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                      color: fg,
                    ),
                  ),
                  SizedBox(height: _isError ? NyanSpacing.space16 : 48),
                  // Error hint — kept visible for the full 2 s timer window.
                  if (_isError) ...[
                    Text(
                      loc.pinMismatch,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: NyanTypography.uiFontFamily,
                        fontSize: NyanTypography.meta,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.3,
                        color: subtle,
                      ),
                    ),
                    const SizedBox(height: NyanSpacing.space20),
                  ],
                  // _widgetGeneration is the authoritative key: it changes only
                  // on deliberate step transitions, not the instant an error
                  // fires — that keeps the widget alive for the shake animation.
                  PinInputWidget(
                    key: ValueKey(_widgetGeneration),
                    onPinComplete: _handlePinComplete,
                    foreground: fg,
                    isError: _isError,
                    onError: _onWidgetErrorAnimationDone,
                  ),
                ],
              ),
            ),
            // Cancel X (top-right).
            Positioned(
              top: NyanSpacing.space12 + 2, // mock 14
              right: NyanSpacing.space12 + 2,
              child: SizedBox(
                width: NyanSpacing.minTapTarget,
                height: NyanSpacing.minTapTarget,
                child: IconButton(
                  icon: Icon(NyanIcons.close, size: NyanTypography.pinKeyGlyph),
                  color: subtle,
                  onPressed: () {
                    widget.onCancel?.call();
                    Navigator.of(context).pop(false);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
