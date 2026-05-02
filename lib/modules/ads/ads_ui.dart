import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/ui/components/nyan_inline_ad_card.dart';

class AdsUI {
  static const int bookshelfListInsertionIndex = 6;
  static const int bookshelfGridInsertionCount = 6;
  static const int minBooksForInlineShelfAd = bookshelfListInsertionIndex + 1;

  static const String _sponsoredLabelZh = '\u8d5e\u52a9\u63a8\u8350';
  static const String _titleZh = '\u53d1\u73b0\u66f4\u591a\u6545\u4e8b';
  static const String _descriptionZh =
      '\u8fd9\u91cc\u53ef\u4ee5\u653e\u4e00\u6761\u4e0d\u6253\u6270\u9605\u8bfb\u8282\u594f\u7684\u8d5e\u52a9\u63a8\u8350\u3002';

  static const String _sponsoredLabelEn = 'Sponsored';
  static const String _titleEn = 'Discover more stories';
  static const String _descriptionEn =
      'A quiet sponsored recommendation can live here without interrupting your shelf.';

  static void init() {
    debugPrint('AdsUI: Initialized');
  }

  static bool shouldShowBookshelfInlineAd({
    required bool adsEnabled,
    required bool isPrivateShelf,
    required bool isSelectionMode,
    required int bookCount,
  }) {
    final meetsPlacementRules = !isPrivateShelf &&
        !isSelectionMode &&
        bookCount >= minBooksForInlineShelfAd;
    final isVisible = meetsPlacementRules && (adsEnabled || kDebugMode);

    return isVisible;
  }

  static Widget buildBookshelfInlineAd(
    BuildContext context, {
    NyanInlineAdDensity density = NyanInlineAdDensity.regular,
  }) {
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';

    return NyanInlineAdCard(
      density: density,
      sponsoredLabel: isChinese ? _sponsoredLabelZh : _sponsoredLabelEn,
      title: isChinese ? _titleZh : _titleEn,
      description: isChinese ? _descriptionZh : _descriptionEn,
    );
  }

  static void hide() {
    debugPrint('AdsUI: Hidden');
  }
}
