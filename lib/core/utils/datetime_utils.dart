import 'package:nyan_read/l10n/app_localizations.dart';

/// Utility functions for formatting dates and times
class DateTimeUtils {
  /// Formats a timestamp to relative time labels
  /// Returns localized string: Today, Yesterday, 3 days ago, etc.
  static String formatRelativeTime(
      DateTime dateTime, DateTime now, AppLocalizations loc) {
    final difference = now.difference(dateTime);
    final days = difference.inDays;

    if (days == 0) {
      return loc.timeToday;
    } else if (days == 1) {
      return loc.timeYesterday;
    } else if (days <= 3) {
      return loc.timeThreeDaysAgo;
    } else if (days <= 7) {
      return loc.timeSevenDaysAgo;
    } else {
      return loc.timeLongAgo;
    }
  }

  /// Formats a timestamp (milliseconds since epoch) to relative time
  static String formatRelativeTimeFromMillis(
      int millisecondsSinceEpoch, DateTime now, AppLocalizations loc) {
    final dateTime =
        DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
    return formatRelativeTime(dateTime, now, loc);
  }
}
