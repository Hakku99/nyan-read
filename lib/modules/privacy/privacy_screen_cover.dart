import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/riverpod_providers.dart';
import '../../core/theme/theme_presets.dart';

/// iOS has no FLAG_SECURE equivalent, so while private content is on screen
/// and the app leaves the foreground (app switcher snapshot) we paint an
/// opaque cover over everything.
///
/// UNVERIFIED on a real device (no iOS hardware available at time of writing).
/// Android relies on FLAG_SECURE instead; `inactive` also fires there for
/// pickers and dialogs, which would flash the cover needlessly.
class PrivacyScreenCover extends ConsumerStatefulWidget {
  const PrivacyScreenCover({super.key, required this.child, bool? enabled})
      : _enabled = enabled;

  final Widget child;
  final bool? _enabled;

  @override
  ConsumerState<PrivacyScreenCover> createState() => _PrivacyScreenCoverState();
}

class _PrivacyScreenCoverState extends ConsumerState<PrivacyScreenCover>
    with WidgetsBindingObserver {
  bool _backgrounded = false;

  bool get _enabled =>
      widget._enabled ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final away = state != AppLifecycleState.resumed;
    if (away != _backgrounded) setState(() => _backgrounded = away);
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    final background = resolveNyanTheme(Theme.of(context)).background;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_backgrounded)
          Positioned.fill(
            child: ValueListenableBuilder<bool>(
              valueListenable: ref.read(privacyScreenRpProvider).active,
              builder: (_, active, __) =>
                  active ? ColoredBox(color: background) : const SizedBox(),
            ),
          ),
      ],
    );
  }
}
