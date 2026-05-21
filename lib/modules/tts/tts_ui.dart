import 'package:flutter/material.dart';
import 'package:nyan_read/core/ui/nyan_icons.dart';

class TTSUI {
  static void showControls(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        height: 150,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Text To Speech (Stub)"),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                    onPressed: () {}, icon: const Icon(NyanIcons.skipPrevious)),
                IconButton(
                    onPressed: () {}, icon: const Icon(NyanIcons.play)),
                IconButton(onPressed: () {}, icon: const Icon(NyanIcons.skipNext)),
              ],
            ),
            const LinearProgressIndicator(value: 0.3),
          ],
        ),
      ),
    );
  }

  static void hideControls() {
    debugPrint("TTSUI: Controls Hidden");
  }

  static void setProgress(double value) {
    debugPrint("TTSUI: Progress set to $value");
  }
}
