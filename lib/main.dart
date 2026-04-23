import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import 'package:provider/provider.dart';
import 'core/services/feature_manager.dart';
import 'core/services/reader_preferences_service.dart';
import 'core/services/reading_reminder_service.dart';
import 'core/services/backup_recovery_service.dart';
import 'core/theme/theme_manager.dart';
import 'core/services/language_manager.dart';

import 'core/services/service_locator.dart';
import 'core/router/app_router.dart';

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
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: getIt<FeatureManager>()),
        ChangeNotifierProvider.value(value: getIt<ThemeManager>()),
        ChangeNotifierProvider.value(value: getIt<LanguageManager>()),
        ChangeNotifierProvider.value(value: getIt<ReaderPreferencesService>()),
        ChangeNotifierProvider.value(value: getIt<ReadingReminderService>()),
      ],
      child: const NyanApp(),
    ),
  );
}

class NyanApp extends StatefulWidget {
  const NyanApp({super.key});

  @override
  State<NyanApp> createState() => _NyanAppState();
}

class _NyanAppState extends State<NyanApp> with WidgetsBindingObserver {
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
          final fm = Provider.of<FeatureManager>(context, listen: false);
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
    return Consumer2<ThemeManager, LanguageManager>(
      builder: (context, themeManager, languageManager, child) {
        return MaterialApp.router(
          title: 'Nyan Read',
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
