import 'package:flutter/material.dart';

/// Attached to [MaterialApp.router] for reliable [SnackBar] fallback.
final GlobalKey<ScaffoldMessengerState> nyanScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Bound to [GoRouter] in `app_router.dart` — the overlay that
/// actually paints route content. [ScaffoldMessenger]'s context sits *above*
/// the navigator, so [Overlay.maybeOf] on the messenger never finds this.
final GlobalKey<NavigatorState> nyanRootNavigatorKey =
    GlobalKey<NavigatorState>();
