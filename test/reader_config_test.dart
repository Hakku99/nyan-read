/// ReaderSettingsManager skips engine pushes for equal configs, so every
/// ReaderConfig field must take part in == / hashCode.
library;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/services/reader_preferences_service.dart';
import 'package:nyan_read/modules/reader/reader_engine/reader_engine.dart';

ReaderConfig base({
  Color backgroundColor = const Color(0xFFF6F3EA),
  Color textColor = const Color(0xFF3F3A34),
  double fontSize = 18,
  double lineHeight = 1.5,
  PageTurnMode pageTurnMode = PageTurnMode.swipe,
  PageAnimation pageAnimation = PageAnimation.fade,
  bool useSerif = false,
}) =>
    ReaderConfig(
      backgroundColor: backgroundColor,
      textColor: textColor,
      fontSize: fontSize,
      lineHeight: lineHeight,
      pageTurnMode: pageTurnMode,
      pageAnimation: pageAnimation,
      useSerif: useSerif,
    );

void main() {
  test('equal field values are equal and share a hashCode', () {
    expect(base(), base());
    expect(base().hashCode, base().hashCode);
  });

  final variants = <String, ReaderConfig>{
    'backgroundColor': base(backgroundColor: const Color(0xFF121212)),
    'textColor': base(textColor: const Color(0xFFECECEC)),
    'fontSize': base(fontSize: 20),
    'lineHeight': base(lineHeight: 1.8),
    'pageTurnMode': base(pageTurnMode: PageTurnMode.tap),
    'pageAnimation': base(pageAnimation: PageAnimation.paper),
    'useSerif': base(useSerif: true),
  };
  for (final entry in variants.entries) {
    test('a different ${entry.key} breaks equality', () {
      expect(entry.value, isNot(base()));
    });
  }
}
