import 'package:flutter/material.dart';

class AdsUI {
  static bool _isVisible = false;

  static void init() {
    // Init Ads SDK stub
    debugPrint("AdsUI: Initialized");
  }

  static Widget showBanner(BuildContext context) {
    _isVisible = true;
    return Container(
      height: 60,
      width: double.infinity,
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: const Text(
        "ADVERTISEMENT BANNER (Stub)",
        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
      ),
    );
  }

  static void hide() {
    _isVisible = false;
    debugPrint("AdsUI: Hidden");
  }
}
