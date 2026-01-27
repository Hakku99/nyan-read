import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/feature_manager.dart';

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final fm = context.watch<FeatureManager>();
    
    return Scaffold(
      appBar: AppBar(title: const Text("Admin / Manager Mode")),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Pro Mode Enabled"),
            subtitle: const Text("Unlocks Privacy Shelf, No Ads"),
            value: fm.currentMode == AppMode.pro,
            onChanged: (val) => fm.toggleMode(val ? AppMode.pro : AppMode.free),
          ),
          if (fm.isPro)
            SwitchListTile(
              title: const Text("Force Unlock Privacy Shelf"),
              subtitle: const Text("Bypass password check"),
              value: fm.isPrivateShelfUnlocked,
              onChanged: (val) {
                if (val) {
                  fm.unlockPrivateShelf();
                } else {
                  fm.lockPrivateShelf();
                }
              },
            ),
          const Divider(),
          ListTile(
            title: const Text("Feature Flags Status"),
            subtitle: Text(
              "Ads: ${fm.adsEnabled}\n"
              "Privacy: ${fm.privacyShelfEnabled}\n"
              "TTS: ${fm.ttsEnabled}"
            ),
          ),
        ],
      ),
    );
  }
}
