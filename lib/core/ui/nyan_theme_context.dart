import 'package:flutter/material.dart';

import '../theme/theme_presets.dart';

extension NyanThemeContext on BuildContext {
  NyanTheme get nyanTheme {
    final extension = Theme.of(this).extension<NyanTheme>();
    assert(extension != null, 'NyanTheme ThemeExtension is not configured.');
    return extension!;
  }

  Color get selectionSurface {
    return Theme.of(this).colorScheme.primaryContainer.withValues(alpha: 0.2);
  }
}
