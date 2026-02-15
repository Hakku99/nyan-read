import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';

void main() {
  group('Sepia Warm Theme Specs', () {
    final sepiaTheme = themePresets[ThemePreset.sepiaWarm]!;
    final themeData = sepiaTheme.themeData;

    test('Color Palette is correct', () {
      expect(sepiaTheme.background, const Color(0xFFEDE3C7));
      expect(sepiaTheme.surface, const Color(0xFFFDFBF7));
      expect(sepiaTheme.primary, const Color(0xFF795548));
    });

    test('Card Theme has custom border', () {
      final cardShape = themeData.cardTheme.shape as RoundedRectangleBorder;
      final side = cardShape.side;
      expect(side.color, const Color(0xFF795548).withOpacity(0.15));
      expect(side.width, 1.0);
    });

    test('FAB Theme matches vintage style', () {
      final fabTheme = themeData.floatingActionButtonTheme;
      expect(
          fabTheme.backgroundColor, const Color(0xFF795548).withOpacity(0.15));
      expect(fabTheme.foregroundColor, const Color(0xFF795548));

      final shape = fabTheme.shape as RoundedRectangleBorder;
      final side = shape.side;
      expect(side.color, const Color(0xFF795548));
      expect(side.width, 1.0);
    });

    test('Slider Theme matches sepia style', () {
      final sliderTheme = themeData.sliderTheme;
      expect(sliderTheme.activeTrackColor, const Color(0xFF795548));
      expect(sliderTheme.inactiveTrackColor,
          const Color(0xFFA1887F).withOpacity(0.5));
      expect(sliderTheme.thumbColor, const Color(0xFF795548));
    });
  });
}
