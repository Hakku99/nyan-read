import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backup_recovery_service.dart';
import 'biometric_service.dart';
import 'feature_manager.dart';
import 'language_manager.dart';
import 'database_service.dart';
import 'bookshelf_preferences_service.dart';
import 'pin_service.dart';
import 'reader_preferences_service.dart';
import 'reading_reminder_service.dart';
import 'service_locator.dart';
import '../theme/theme_manager.dart';

/// Riverpod bridge layer for the current Provider/get_it stack.
///
/// Phase 4 P2-2 spike target:
/// - keep existing provider tree working
/// - allow new screens/modules to opt into Riverpod incrementally
final featureManagerRpProvider = Provider<FeatureManager>((ref) {
  return getIt<FeatureManager>();
});

final themeManagerRpProvider = Provider<ThemeManager>((ref) {
  return getIt<ThemeManager>();
});

final languageManagerRpProvider = Provider<LanguageManager>((ref) {
  return getIt<LanguageManager>();
});

final readerPreferencesRpProvider = Provider<ReaderPreferencesService>((ref) {
  return getIt<ReaderPreferencesService>();
});

final readingReminderRpProvider = Provider<ReadingReminderService>((ref) {
  return getIt<ReadingReminderService>();
});

final databaseServiceRpProvider = Provider<DatabaseService>((ref) {
  return getIt<DatabaseService>();
});

final bookshelfPreferencesRpProvider = Provider<BookshelfPreferencesService>((ref) {
  return getIt<BookshelfPreferencesService>();
});

final pinServiceRpProvider = Provider<PinService>((ref) {
  return getIt<PinService>();
});

final biometricServiceRpProvider = Provider<BiometricService>((ref) {
  return getIt<BiometricService>();
});

final backupRecoveryServiceRpProvider = Provider<BackupRecoveryService>((ref) {
  return getIt<BackupRecoveryService>();
});
