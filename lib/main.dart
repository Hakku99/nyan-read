import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import 'core/services/backup_recovery_service.dart';
import 'core/services/riverpod_providers.dart';

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
    await setupServiceLocator().timeout(const Duration(seconds: 5));
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

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('App bootstrap failed.\n$error'),
          ),
        ),
      ),
    );
  }
}
