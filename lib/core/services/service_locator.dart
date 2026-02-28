import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'database_service.dart';
import 'feature_manager.dart';
import 'reader_preferences_service.dart';
import 'bookshelf_preferences_service.dart';
import '../theme/theme_manager.dart';
import 'language_manager.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // 1. Core Data & Infrastructure Layer
  debugPrint('--- [DI] 1. 开始注册 DatabaseService ---');
  getIt.registerSingletonAsync<DatabaseService>(() async {
    debugPrint('--- [DI] 1.1 正在初始化 DatabaseService 实例 ---');
    final service = DatabaseService();
    await service.database; // warm up db
    debugPrint('--- [DI] 1.2 DatabaseService 初始化完成 ---');
    return service;
  });

  // 2. Persistent Preferences/Cache Layer
  debugPrint('--- [DI] 2. 开始注册 ReaderPreferencesService ---');
  getIt.registerSingletonAsync<ReaderPreferencesService>(() async {
    debugPrint('--- [DI] 2.1 正在初始化 ReaderPreferencesService 实例 ---');
    final service = ReaderPreferencesService();
    await service.initialize();
    debugPrint('--- [DI] 2.2 ReaderPreferencesService 初始化完成 ---');
    return service;
  });

  debugPrint('--- [DI] 3. 开始注册 BookshelfPreferencesService ---');
  getIt.registerSingletonAsync<BookshelfPreferencesService>(() async {
    debugPrint('--- [DI] 3.1 正在初始化 BookshelfPreferencesService 实例 ---');
    final service = BookshelfPreferencesService();
    await service.initialize();
    debugPrint('--- [DI] 3.2 BookshelfPreferencesService 初始化完成 ---');
    return service;
  });

  // Wait for async services to be ready
  // Wait for async services to be ready
  debugPrint('--- [DI] 99. 开始等待 getIt.allReady() ---');
  await getIt.allReady();
  debugPrint('--- [DI] 100. 所有异步依赖装载完毕！ ---');

  // 3. Application State & Controllers Layer
  debugPrint('--- [DI] 101. 正在装载 FeatureManager ---');
  getIt.registerSingleton<FeatureManager>(FeatureManager()..init());

  debugPrint('--- [DI] 102. 正在装载 ThemeManager ---');
  getIt.registerSingleton<ThemeManager>(ThemeManager()..init());

  debugPrint('--- [DI] 103. 正在装载 LanguageManager ---');
  getIt.registerSingleton<LanguageManager>(LanguageManager()..init());

  debugPrint('--- [DI] 104. 同步服务装载完毕！ ---');
}
