import 'package:flutter/material.dart';

class TTSUI {
  static bool _isVisible = false;

  static void showControls(BuildContext context) {
    _isVisible = true;
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
                IconButton(onPressed: () {}, icon: const Icon(Icons.skip_previous)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.play_arrow)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.skip_next)),
              ],
            ),
            const LinearProgressIndicator(value: 0.3),
          ],
        ),
      ),
    );
  }

  static void hideControls() {
    _isVisible = false;
    debugPrint("TTSUI: Controls Hidden");
  }

  static void setProgress(double value) {
    debugPrint("TTSUI: Progress set to $value");
  }
}
