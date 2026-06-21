import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/ui/components/nyan_inline_ad_card.dart';
import 'nyan_shelf_pro_nudge.dart';

class AdsUI {
  // ponytail: insertion counts kept for grid split logic (after all books)
  static const int minBooksForInlineShelfAd = 7;

  static const _sponsoredTitleZh = '为你发现更多好书';
  static const _sponsoredTitleEn = 'More stories you may like';
  static const _providerName = 'BookBuzz';

  // Placeholder suggestions — replace with real feed data when available.
  static const _suggestionsZh = [
    NyanMiniSuggest(title: '星海征途：舰娘纪元', author: '林深'),
    NyanMiniSuggest(title: '我在末世种田的日子', author: '苏晚'),
    NyanMiniSuggest(title: '长安十二时辰外传', author: '马伯庸'),
  ];
  static const _suggestionsEn = [
    NyanMiniSuggest(title: 'Star Ocean: Fleet Chronicles', author: 'Lin Shen'),
    NyanMiniSuggest(title: 'Farming at the End of Days', author: 'Su Wan'),
    NyanMiniSuggest(title: "Chang'an: Twelve Hours Beyond", author: 'Ma Boyong'),
  ];

  static void init() {
    debugPrint('AdsUI: Initialized');
  }

  static bool shouldShowBookshelfInlineAd({
    required bool adsEnabled,
    required bool isPrivateShelf,
    required bool isSelectionMode,
    required bool isProUser,
    required int bookCount,
  }) {
    if (isProUser) return false;
    final meetsPlacementRules = !isPrivateShelf &&
        !isSelectionMode &&
        bookCount >= minBooksForInlineShelfAd;
    return meetsPlacementRules && (adsEnabled || kDebugMode);
  }

  /// Whether to show the Pro nudge in the sponsored slot (no ad available).
  /// [forceProNudge] overrides the debug-mode suppression for testing.
  static bool shouldShowProNudge({
    required bool adsEnabled,
    required bool isPrivateShelf,
    required bool isSelectionMode,
    required bool isProUser,
    required int bookCount,
    bool forceProNudge = false,
  }) {
    if (isProUser || isPrivateShelf || isSelectionMode) return false;
    if (bookCount < minBooksForInlineShelfAd) return false;
    if (forceProNudge) return true;
    return !adsEnabled && !kDebugMode;
  }

  static Widget buildBookshelfInlineAd(
    BuildContext context, {
    VoidCallback? onDismiss,
  }) {
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';
    return NyanShelfDiscoverBlock(
      title: isChinese ? _sponsoredTitleZh : _sponsoredTitleEn,
      providerName: _providerName,
      suggestions: isChinese ? _suggestionsZh : _suggestionsEn,
      onDismiss: onDismiss,
    );
  }

  static Widget buildProNudge(
    BuildContext context, {
    VoidCallback? onUpgrade,
  }) {
    return NyanShelfProNudge(onUpgrade: onUpgrade);
  }

  static void hide() {
    debugPrint('AdsUI: Hidden');
  }
}
