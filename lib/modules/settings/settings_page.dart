import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_manager.dart';
import '../../core/services/feature_manager.dart';
import '../../core/services/reader_preferences_service.dart';
import '../../modules/tts/tts_ui.dart';
// import '../../modules/ads/ads_ui.dart';
import '../../core/theme/theme_presets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = context.watch<ThemeManager>();
    final featureManager = context.watch<FeatureManager>();
    final readerPrefs = ReaderPreferencesService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          // Theme Section
          ListTile(
            title: const Text("Theme Preset"),
            trailing: DropdownButton<ThemePreset>(
              value: themeManager.currentPreset,
              onChanged: (ThemePreset? val) {
                if (val != null) themeManager.setPreset(val);
              },
              items: themePresets.values.map((theme) {
                return DropdownMenuItem<ThemePreset>(
                  value: theme.preset,
                  child: Text(theme.name),
                );
              }).toList(),
            ),
          ),

          const Divider(),

          // Reading Settings Section
          const ListTile(
            leading: Icon(Icons.menu_book),
            title: Text("Reading Settings",
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),

          ListenableBuilder(
            listenable: readerPrefs,
            builder: (context, child) {
              return Column(
                children: [
                  ListTile(
                    title: const Text("Page Turn Mode"),
                    subtitle:
                        Text(_getPageTurnModeLabel(readerPrefs.pageTurnMode)),
                    trailing: DropdownButton<PageTurnMode>(
                      value: readerPrefs.pageTurnMode,
                      onChanged: (PageTurnMode? val) {
                        if (val != null) readerPrefs.setPageTurnMode(val);
                      },
                      items: const [
                        DropdownMenuItem(
                            value: PageTurnMode.tap, child: Text("Tap")),
                        DropdownMenuItem(
                            value: PageTurnMode.swipe, child: Text("Swipe")),
                        DropdownMenuItem(
                            value: PageTurnMode.disabled,
                            child: Text("Disabled")),
                      ],
                    ),
                  ),
                  ListTile(
                    title: const Text("Page Animation"),
                    subtitle:
                        Text(_getPageAnimationLabel(readerPrefs.pageAnimation)),
                    trailing: DropdownButton<PageAnimation>(
                      value: readerPrefs.pageAnimation,
                      onChanged: (PageAnimation? val) {
                        if (val != null) readerPrefs.setPageAnimation(val);
                      },
                      items: const [
                        DropdownMenuItem(
                            value: PageAnimation.fade, child: Text("Fade")),
                        DropdownMenuItem(
                            value: PageAnimation.paper, child: Text("Paper")),
                        DropdownMenuItem(
                            value: PageAnimation.none, child: Text("None")),
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
            title: const Text("Reading Reminder"),
            subtitle: const Text("Remind me to take a break"),
            value: true, // Stub state
            onChanged: (val) {
              // TODO: Implement preference persistence
            },
          ),
          ListTile(
            title: const Text("Reminder Interval"),
            trailing: DropdownButton<int>(
              value: 60,
              items: const [
                DropdownMenuItem(value: 30, child: Text("30 min")),
                DropdownMenuItem(value: 60, child: Text("60 min")),
                DropdownMenuItem(value: 90, child: Text("90 min")),
              ],
              onChanged: (val) {},
            ),
          ),

          const Divider(),

          // Pro / Privacy
          if (featureManager.isPro) ...[
            SwitchListTile(
              title: const Text("Lock Privacy Shelf"),
              value: true,
              onChanged: (val) {},
            ),
            ListTile(
              title: const Text("TTS (Text-to-Speech)"),
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
          ] else ...[
            ListTile(
              title: const Text("Ads"),
              subtitle: const Text("Show Ads (Free Version)"),
              trailing: Switch(
                value: featureManager.adsEnabled,
                onChanged: (val) {
                  // Stub
                },
              ),
            ),
            const ListTile(
              title: Text("Upgrade to Pro"),
              leading: Icon(Icons.star, color: Colors.amber),
            ),
          ],

          const Divider(),

          // Admin
          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text("Admin Panel"),
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

  String _getPageTurnModeLabel(PageTurnMode mode) {
    switch (mode) {
      case PageTurnMode.tap:
        return 'Tap to turn pages';
      case PageTurnMode.swipe:
        return 'Swipe to turn pages';
      case PageTurnMode.disabled:
        return 'Page turning disabled';
    }
  }

  String _getPageAnimationLabel(PageAnimation animation) {
    switch (animation) {
      case PageAnimation.fade:
        return 'Smooth fade transition';
      case PageAnimation.paper:
        return 'Subtle paper effect';
      case PageAnimation.none:
        return 'No animation';
    }
  }
}
