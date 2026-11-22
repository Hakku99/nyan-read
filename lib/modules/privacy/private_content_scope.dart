import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/feature_manager.dart';
import '../../core/services/privacy_screen_service.dart';
import '../../core/services/riverpod_providers.dart';
import '../../core/theme/theme_presets.dart';
import '../../core/ui/nyan_app_keys.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../l10n/app_localizations.dart';

/// Wraps a screen that shows private-shelf content.
///
/// While [isPrivate] it (1) registers with [PrivacyScreenService] so Android
/// raises `FLAG_SECURE`, and (2) closes the screen when the private shelf
/// locks (idle timeout, manual lock, any `lockPrivateShelf()` caller).
///
/// Closing order on lock: opaque cover first (hides content during async
/// work) → wait for private screens stacked above → pop overlays above this
/// route → [onLocked] (e.g. save reading progress, then pop) → toast.
class PrivateContentScope extends ConsumerStatefulWidget {
  const PrivateContentScope({
    super.key,
    required this.isPrivate,
    required this.child,
    this.onLocked,
  });

  final bool isPrivate;
  final Widget child;

  /// Replaces the default "pop this route". It MUST pop the route itself
  /// (the reader needs to save progress first, then pop).
  final Future<void> Function()? onLocked;

  @override
  ConsumerState<PrivateContentScope> createState() =>
      _PrivateContentScopeState();
}

class _PrivateContentScopeState extends ConsumerState<PrivateContentScope> {
  // Bounds the wait for a screen stacked above us; a hung exit there must not
  // leave private content open here.
  static const Duration _aboveExitTimeout = Duration(seconds: 3);

  late final FeatureManager _featureManager;
  late final PrivacyScreenService _screen;
  late bool _wasUnlocked;
  ModalRoute<Object?>? _route;
  bool _covering = false;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _featureManager = ref.read(featureManagerRpProvider);
    _screen = ref.read(privacyScreenRpProvider);
    _wasUnlocked = _featureManager.isPrivateShelfUnlocked;
    _featureManager.addListener(_onFeatureChanged);
    if (widget.isPrivate) _screen.acquire(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void didUpdateWidget(PrivateContentScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPrivate == widget.isPrivate) return;
    if (widget.isPrivate) {
      _screen.acquire(this);
    } else {
      _screen.release(this);
    }
  }

  @override
  void dispose() {
    _featureManager.removeListener(_onFeatureChanged);
    _screen.release(this);
    super.dispose();
  }

  void _onFeatureChanged() {
    final unlocked = _featureManager.isPrivateShelfUnlocked;
    final justLocked = _wasUnlocked && !unlocked;
    _wasUnlocked = unlocked;
    if (justLocked && widget.isPrivate && !_exiting && mounted) {
      // Fire-and-forget: the exit owns its own error handling.
      unawaited(_exitForLock());
    }
  }

  Future<void> _exitForLock() async {
    _exiting = true;
    setState(() => _covering = true);
    final route = _route;
    final nav = Navigator.maybeOf(context);
    try {
      await _screen
          .untilNewerReleased(this)
          .timeout(_aboveExitTimeout, onTimeout: () {});
      if (!mounted || nav == null) return;
      // The route is already on its way out (e.g. a back press landed first):
      // a second pop here would take the page below it with it.
      if (route != null && !route.isActive) return;
      if (route != null) {
        nav.popUntil((r) => identical(r, route));
      }
      final custom = widget.onLocked;
      if (custom != null) {
        await custom();
      } else if (route != null && route.isActive) {
        nav.pop();
      }
    } catch (e, st) {
      debugPrint('PrivateContentScope lock exit failed: $e\n$st');
      if (route != null && route.isActive) nav?.pop();
    }
    _showLockedToast();
  }

  void _showLockedToast() {
    final rootContext = nyanRootNavigatorKey.currentContext;
    if (rootContext == null || !rootContext.mounted) return;
    final loc = AppLocalizations.of(rootContext);
    if (loc == null) return;
    // SnackBarUtils swaps an active toast in place, so several scopes
    // closing together still show a single card.
    SnackBarUtils.show(rootContext, loc.privacyShelfLocked);
  }

  @override
  Widget build(BuildContext context) {
    // Always a Stack so toggling the cover never re-parents (remounts) child.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_covering)
          Positioned.fill(
            child: ColoredBox(
                color: resolveNyanTheme(Theme.of(context)).background),
          ),
      ],
    );
  }
}
