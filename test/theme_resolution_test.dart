import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyan_read/core/theme/theme_presets.dart';

void main() {
  group('Theme Resolution Logic', () {
    test('Should find Correct Theme based on Background Color', () {
      // Must match themePresets backgrounds (not reader canvas defaults).
      final creamBg = themePresets[ThemePreset.creamLight]!.background;
      final sumiBg = themePresets[ThemePreset.sumiDark]!.background;

      // Logic to test (mimicking what we will implement in ReaderMenu)
      NyanTheme? findTheme(Color bg) {
        try {
          return themePresets.values.firstWhere(
            (theme) => theme.background == bg,
          );
        } catch (e) {
          return null;
        }
      }

      // Assertions
      expect(findTheme(creamBg)?.name, 'Cream Light');
      expect(findTheme(sumiBg)?.name, 'Sumi Dark');
    });

    test('Should fallback to default if color matches no preset', () {
      const oddColor = Color(0xFF123456);

      NyanTheme resolveTheme(Color bg) {
        try {
          return themePresets.values.firstWhere(
            (theme) => theme.background == bg,
          );
        } catch (e) {
          return themePresets[ThemePreset.creamLight]!;
        }
      }

      expect(resolveTheme(oddColor).name, 'Cream Light');
    });
  });
}
