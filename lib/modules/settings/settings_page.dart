import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_manager.dart';
import '../../core/services/feature_manager.dart';
import '../../core/services/reader_preferences_service.dart';
import '../../core/services/bookshelf_preferences_service.dart';
import '../../core/services/language_manager.dart';
import 'package:nyan_read/l10n/app_localizations.dart';
import '../../modules/tts/tts_ui.dart';
// import '../../modules/ads/ads_ui.dart';
import '../../core/theme/theme_presets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = context.watch<ThemeManager>();
    final featureManager = context.watch<FeatureManager>();
    final languageManager = context.watch<LanguageManager>();
    final readerPrefs = ReaderPreferencesService.instance;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.settingsTitle),
      ),
      body: ListView(
        children: [
          // Theme Section
          ListTile(
            title: Text(loc.themePreset),
            trailing: DropdownButton<ThemePreset>(
              value: themeManager.currentPreset,
              onChanged: (ThemePreset? val) {
                if (val != null) themeManager.setPreset(val);
              },
              items: themePresets.values.map((theme) {
                return DropdownMenuItem<ThemePreset>(
                  value: theme.preset,
                  child: Text(_getThemeName(theme.preset, loc)),
                );
              }).toList(),
            ),
          ),

          const Divider(),

          // Language Section
          ListTile(
            title: Text(loc.language),
            trailing: DropdownButton<Locale>(
              value: languageManager.locale,
              onChanged: (Locale? val) {
                if (val != null) languageManager.setLocale(val);
              },
              items: const [
                DropdownMenuItem(
                  value: Locale('en'),
                  child: Text('English'),
                ),
                DropdownMenuItem(
                  value: Locale('zh'),
                  child: Text('中文'),
                ),
              ],
            ),
          ),

          const Divider(),

          // Reading Settings Section
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: Text(loc.readingSettings,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),

          ListenableBuilder(
            listenable: readerPrefs,
            builder: (context, child) {
              return Column(
                children: [
                  ListTile(
                    title: Text(loc.pageTurnMode),
                    subtitle: Text(
                        _getPageTurnModeLabel(readerPrefs.pageTurnMode, loc)),
                    trailing: DropdownButton<PageTurnMode>(
                      value: readerPrefs.pageTurnMode,
                      onChanged: (PageTurnMode? val) {
                        if (val != null) readerPrefs.setPageTurnMode(val);
                      },
                      items: [
                        DropdownMenuItem(
                            value: PageTurnMode.tap,
                            child: Text(loc.pageTurnTap)),
                        DropdownMenuItem(
                            value: PageTurnMode.swipe,
                            child: Text(loc.pageTurnSwipe)),
                        DropdownMenuItem(
                            value: PageTurnMode.disabled,
                            child: Text(loc.pageTurnDisabled)),
                      ],
                    ),
                  ),
                  ListTile(
                    title: Text(loc.pageAnimation),
                    subtitle: Text(
                        _getPageAnimationLabel(readerPrefs.pageAnimation, loc)),
                    trailing: DropdownButton<PageAnimation>(
                      value: readerPrefs.pageAnimation,
                      onChanged: (PageAnimation? val) {
                        if (val != null) readerPrefs.setPageAnimation(val);
                      },
                      items: [
                        DropdownMenuItem(
                            value: PageAnimation.fade,
                            child: Text(loc.pageAnimFade)),
                        DropdownMenuItem(
                            value: PageAnimation.paper,
                            child: Text(loc.pageAnimPaper)),
                        DropdownMenuItem(
                            value: PageAnimation.none,
                            child: Text(loc.pageAnimNone)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const Divider(),

          // Reading Reminder
          SwitchListTile(
            title: Text(loc.readingReminder),
            subtitle: Text(loc.readingReminderSubtitle),
            value: true, // Stub state
            onChanged: (val) {
              // TODO: Implement preference persistence
            },
          ),
          ListTile(
            title: Text(loc.reminderInterval),
            trailing: DropdownButton<int>(
              value: 60,
              items: [
                DropdownMenuItem(
                    value: 30, child: Text(loc.reminderMinutes(30))),
                DropdownMenuItem(
                    value: 60, child: Text(loc.reminderMinutes(60))),
                DropdownMenuItem(
                    value: 90, child: Text(loc.reminderMinutes(90))),
              ],
              onChanged: (val) {},
            ),
          ),

          const Divider(),

          // Data Management
          ListTile(
            title: Text(
              loc.dataManagement,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          StatefulBuilder(
            builder: (context, setState) {
              final bookshelfPrefs = BookshelfPreferencesService.instance;
              return SwitchListTile(
                title: Text(loc.deleteFilesOnRemove),
                subtitle: Text(loc.deleteFilesOnRemoveSubtitle),
                value: bookshelfPrefs.deleteFilesOnRemove,
                onChanged: (val) async {
                  await bookshelfPrefs.setDeleteFilesOnRemove(val);
                  setState(() {});
                },
              );
            },
          ),

          const Divider(),

          // Pro / Privacy
          if (featureManager.isPro) ...[
            SwitchListTile(
              title: Text(loc.lockPrivateShelf),
              value: true,
              onChanged: (val) {},
            ),
            ListTile(
              title: Text(loc.tts),
              trailing: Switch(
                value: featureManager.ttsEnabled,
                onChanged: (val) {
                  // This usually is controlled by FeatureManager but here it might be a user setting for the feature
                  if (val)
                    TTSUI.showControls(context);
                  else
                    TTSUI.hideControls();
                },
              ),
            ),
          ],
          if (!featureManager.isPro) ...[
            ListTile(
              title: Text(loc.ads),
              subtitle: Text(loc.adsSubtitle),
              trailing: Switch(
                value: featureManager.adsEnabled,
                onChanged: (val) {
                  // Stub
                },
              ),
            ),
            ListTile(
              title: Text(loc.upgradeToPro),
              leading: const Icon(Icons.star, color: Colors.amber),
            ),
          ],

          const Divider(),

          // Admin
          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: Text(loc.adminPanel),
            onTap: () {
              // We need to navigate to AdminPanel.
              // Since it's in main.dart, we might have issue importing if it's private.
              // We will assume it's moved or accessible via route.
              // For now, I'll use a named route '/admin' which I will add to main.dart.
              Navigator.pushNamed(context, '/admin');
            },
          ),
        ],
      ),
    );
  }

  String _getPageTurnModeLabel(PageTurnMode mode, AppLocalizations loc) {
    switch (mode) {
      case PageTurnMode.tap:
        return loc.pageTurnModeTap;
      case PageTurnMode.swipe:
        return loc.pageTurnModeSwipe;
      case PageTurnMode.disabled:
        return loc.pageTurnModeDisabled;
    }
  }

  String _getPageAnimationLabel(PageAnimation animation, AppLocalizations loc) {
    switch (animation) {
      case PageAnimation.fade:
        return loc.pageAnimationFade;
      case PageAnimation.paper:
        return loc.pageAnimationPaper;
      case PageAnimation.none:
        return loc.pageAnimationNone;
    }
  }

  String _getThemeName(ThemePreset preset, AppLocalizations loc) {
    switch (preset) {
      case ThemePreset.creamLight:
        return loc.themeCreamLight;
      case ThemePreset.sumiDark:
        return loc.themeSumiDark;
      case ThemePreset.sepiaWarm:
        return loc.themeSepiaWarm;
    }
  }
}
