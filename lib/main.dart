import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import 'core/services/backup_recovery_service.dart';
import 'core/services/riverpod_providers.dart';
import 'core/services/signature_backfill_service.dart';

import 'core/services/service_locator.dart';
import 'core/router/app_router.dart';
import 'core/ui/nyan_app_keys.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Global Error Monitoring
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('💥 [FlutterError] ${details.exception}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('💥 [PlatformError] $error\n$stack');
    return true;
  };

  // 1. Initialize dependency injection with fail-fast timeout
  try {
    await _bootstrapServices();
  } catch (e, stack) {
    debugPrint('DI Initialization Failed: $e\n$stack');
    runApp(_BootstrapErrorApp(error: e.toString()));
    return;
  }

  runApp(
    ProviderScope(
      child: const NyanApp(),
    ),
  );
}

/// Runs DI setup with a two-stage timeout: 5s fast path, then a 25s grace
/// period on the *same* future — a large library on a slow device is "slow",
/// not "dead", and restarting setup would double-register singletons.
Future<void> _bootstrapServices() async {
  final setup = setupServiceLocator();
  try {
    await setup.timeout(const Duration(seconds: 5));
  } on TimeoutException {
    debugPrint(
        'DI setup exceeded 5s (large DB / slow device?); waiting up to 25s more');
    await setup.timeout(const Duration(seconds: 25));
  }
}

class NyanApp extends ConsumerStatefulWidget {
  const NyanApp({super.key});

  @override
  ConsumerState<NyanApp> createState() => _NyanAppState();
}

class _NyanAppState extends ConsumerState<NyanApp> with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    if (getIt.isRegistered<BackupRecoveryService>()) {
      getIt<BackupRecoveryService>().dispose();
    }
    if (getIt.isRegistered<SignatureBackfillService>()) {
      getIt<SignatureBackfillService>().dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null) {
        final diff = DateTime.now().difference(_pausedAt!);
        if (diff.inMinutes >= 3) {
          final fm = ref.read(featureManagerRpProvider);
          if (fm.isPrivateShelfUnlocked) {
            fm.lockPrivateShelf();
            debugPrint("Auto-locked Private Shelf after 3 mins background.");
          }
        }
        _pausedAt = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = ref.watch(themeManagerRpProvider);
    final languageManager = ref.watch(languageManagerRpProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([themeManager, languageManager]),
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Nyan Read',
          scaffoldMessengerKey: nyanScaffoldMessengerKey,
          locale: languageManager.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: themeManager.lightTheme,
          darkTheme: themeManager.darkTheme,
          themeMode: themeManager.themeMode,
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class _BootstrapErrorApp extends StatefulWidget {
  const _BootstrapErrorApp({required this.error});

  final String error;

  @override
  State<_BootstrapErrorApp> createState() => _BootstrapErrorAppState();
}

class _BootstrapErrorAppState extends State<_BootstrapErrorApp> {
  late String _error = widget.error;
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      // A failed setup can leave partial registrations behind; reset before
      // re-running so registerSingletonAsync does not throw on duplicates.
      await getIt.reset();
      await _bootstrapServices();
      runApp(ProviderScope(child: const NyanApp()));
    } catch (e, stack) {
      debugPrint('DI retry failed: $e\n$stack');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _retrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pre-DI surface: no theme/l10n services exist yet, so plain Material
    // widgets and hardcoded English are acceptable here.
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('App bootstrap failed.\n$_error',
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                _retrying
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        onPressed: _retry,
                        child: const Text('Retry'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
