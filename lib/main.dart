import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/feature_manager.dart';
import 'core/services/database_service.dart';
import 'core/theme/theme_manager.dart';
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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: featureManager),
        ChangeNotifierProvider.value(value: themeManager),
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
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return MaterialApp(
          title: 'Nyan Read',
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