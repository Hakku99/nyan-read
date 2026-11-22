import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nyan_read/core/services/feature_manager.dart';
import 'package:nyan_read/core/services/privacy_screen_service.dart';
import 'package:nyan_read/core/services/riverpod_providers.dart';
import 'package:nyan_read/modules/privacy/private_content_scope.dart';

void main() {
  late FeatureManager fm;
  late PrivacyScreenService screen;

  setUp(() {
    fm = FeatureManager()..unlockPrivateShelf();
    screen = PrivacyScreenService(nativeEnabled: false);
  });

  /// Pushes a route containing a [PrivateContentScope] on top of a home page.
  Future<GlobalKey<NavigatorState>> openScope(
    WidgetTester tester, {
    required bool isPrivate,
    Future<void> Function()? onLocked,
  }) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        featureManagerRpProvider.overrideWithValue(fm),
        privacyScreenRpProvider.overrideWithValue(screen),
      ],
      child: MaterialApp(
        navigatorKey: navKey,
        home: const Text('home'),
      ),
    ));
    navKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => PrivateContentScope(
        isPrivate: isPrivate,
        onLocked: onLocked,
        child: const Text('private-page'),
      ),
    ));
    await tester.pumpAndSettle();
    return navKey;
  }

  testWidgets('lock closes a private page (default pop) and releases FLAG',
      (tester) async {
    await openScope(tester, isPrivate: true);
    expect(find.text('private-page'), findsOneWidget);
    expect(screen.hasHolders, isTrue);

    fm.lockPrivateShelf(); // same call for manual lock and idle timeout
    await tester.pumpAndSettle();

    expect(find.text('private-page'), findsNothing);
    expect(find.text('home'), findsOneWidget);
    expect(screen.hasHolders, isFalse);
  });

  testWidgets('non-private page is untouched by lock and holds no flag',
      (tester) async {
    await openScope(tester, isPrivate: false);
    expect(screen.hasHolders, isFalse);

    fm.lockPrivateShelf();
    await tester.pumpAndSettle();

    expect(find.text('private-page'), findsOneWidget);
  });

  testWidgets('onLocked runs once, after overlays above are popped',
      (tester) async {
    var calls = 0;
    String? topRouteAtCall;
    late GlobalKey<NavigatorState> nav;
    nav = await openScope(tester, isPrivate: true, onLocked: () async {
      calls++;
      // expect() is not allowed inside a pumpAndSettle callback, so record
      // the top route here and assert after settling.
      nav.currentState!.popUntil((r) {
        topRouteAtCall = r.settings.name;
        return true;
      });
      nav.currentState!.pop();
    });
    nav.currentState!.push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'overlay'),
      builder: (_) => const Text('overlay'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('overlay'), findsOneWidget);

    fm.lockPrivateShelf();
    fm.lockPrivateShelf(); // duplicate notify must not re-enter
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(topRouteAtCall, isNot('overlay'),
        reason: 'overlays above must be popped before onLocked runs');
    expect(find.text('overlay'), findsNothing);
    expect(find.text('private-page'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('stacked private pages close top-down without skipping the top',
      (tester) async {
    final order = <String>[];
    late GlobalKey<NavigatorState> nav;
    nav = await openScope(tester, isPrivate: true, onLocked: () async {
      order.add('lower');
      nav.currentState!.pop();
    });
    nav.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => PrivateContentScope(
        isPrivate: true,
        onLocked: () async {
          order.add('upper-save');
          await Future<void>.delayed(const Duration(milliseconds: 20));
          nav.currentState!.pop();
        },
        child: const Text('upper'),
      ),
    ));
    await tester.pumpAndSettle();

    fm.lockPrivateShelf();
    await tester.pumpAndSettle();

    expect(order, ['upper-save', 'lower']);
    expect(find.text('home'), findsOneWidget);
  });

  test('autoLockAfterBackground: only locks past the threshold', () {
    expect(fm.autoLockAfterBackground(const Duration(minutes: 2)), isFalse);
    expect(fm.isPrivateShelfUnlocked, isTrue);
    expect(fm.autoLockAfterBackground(FeatureManager.autoLockAfter), isTrue);
    expect(fm.isPrivateShelfUnlocked, isFalse);
    expect(fm.autoLockAfterBackground(const Duration(hours: 1)), isFalse,
        reason: 'already locked: nothing to do');
  });

  testWidgets('route already popping: onLocked is skipped (no double pop)',
      (tester) async {
    var calls = 0;
    late GlobalKey<NavigatorState> nav;
    nav = await openScope(tester, isPrivate: true, onLocked: () async {
      calls++;
      nav.currentState!.pop();
    });

    nav.currentState!.pop(); // back press lands first
    fm.lockPrivateShelf(); // lock lands before the pop animation ends
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('works on go_router page routes with an overlay above',
      (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Text('home')),
      GoRoute(
        path: '/private',
        builder: (_, __) => PrivateContentScope(
          isPrivate: true,
          child: const Text('private-page'),
        ),
      ),
      GoRoute(path: '/overlay', builder: (_, __) => const Text('overlay')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        featureManagerRpProvider.overrideWithValue(fm),
        privacyScreenRpProvider.overrideWithValue(screen),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    unawaited(router.push('/private'));
    await tester.pumpAndSettle();
    unawaited(router.push('/overlay'));
    await tester.pumpAndSettle();
    expect(find.text('overlay'), findsOneWidget);

    fm.lockPrivateShelf();
    await tester.pumpAndSettle();

    expect(find.text('overlay'), findsNothing);
    expect(find.text('private-page'), findsNothing);
    expect(find.text('home'), findsOneWidget);
    expect(screen.hasHolders, isFalse);
  });

  testWidgets('lock drops text focus so the keyboard does not flash',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        featureManagerRpProvider.overrideWithValue(fm),
        privacyScreenRpProvider.overrideWithValue(screen),
      ],
      child: MaterialApp(
        navigatorKey: navKey,
        home: Scaffold(
          body: PrivateContentScope(
            isPrivate: true,
            onLocked: () async {},
            child: TextField(focusNode: node, autofocus: true),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(node.hasFocus, isTrue);

    fm.lockPrivateShelf();
    await tester.pump();

    expect(node.hasFocus, isFalse);
  });

  testWidgets('going to background drops text focus before any lock',
      (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        featureManagerRpProvider.overrideWithValue(fm),
        privacyScreenRpProvider.overrideWithValue(screen),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: PrivateContentScope(
            isPrivate: true,
            child: TextField(focusNode: node, autofocus: true),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(node.hasFocus, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(node.hasFocus, isTrue,
        reason: 'inactive alone must not steal focus');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(node.hasFocus, isFalse);
  });
}
