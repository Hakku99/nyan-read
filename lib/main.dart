import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nyan_read/l10n/app_localizations.dart';

import 'package:provider/provider.dart';
import 'core/services/feature_manager.dart';
import 'core/services/database_service.dart';
import 'core/services/reader_preferences_service.dart';
import 'core/services/bookshelf_preferences_service.dart';
import 'core/theme/theme_manager.dart';
import 'core/services/language_manager.dart';

import 'modules/home/splash_page.dart';
import 'modules/admin/admin_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Services
  await DatabaseService().database; // warm up db
  final featureManager = FeatureManager();
  await featureManager.init();
  final themeManager = ThemeManager();
  await themeManager.init();
  final languageManager = LanguageManager();
  await languageManager.init();
  final readerPrefs = ReaderPreferencesService.instance;
  await readerPrefs.initialize();
  final bookshelfPrefs = BookshelfPreferencesService.instance;
  await bookshelfPrefs.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: featureManager),
        ChangeNotifierProvider.value(value: themeManager),
        ChangeNotifierProvider.value(value: languageManager),
        ChangeNotifierProvider.value(value: readerPrefs),
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
        return MaterialApp(
          title: 'Nyan Read',
          locale: languageManager.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: themeManager.lightTheme,
          darkTheme: themeManager.darkTheme,
          themeMode: themeManager.themeMode,
          home: const SplashPage(),
          routes: {
            '/admin': (context) => const AdminPanel(),
          },
        );
      },
    );
  }
}
