import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/feature_manager.dart';
import '../../core/services/riverpod_providers.dart';

class AdminPanel extends ConsumerWidget {
  const AdminPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fm = ref.read(featureManagerRpProvider);

    return ListenableBuilder(
      listenable: fm,
      builder: (context, _) {
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
                  "TTS: ${fm.ttsEnabled}",
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
