import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Looks up text the user selected and explicitly asked to search.
///
/// Android hands the query to the user's default search app
/// (`ACTION_WEB_SEARCH`) instead of a hard-coded engine; google.com is
/// unreachable in mainland China (audit N8).
class TextSearchLauncher {
  const TextSearchLauncher._();

  static const MethodChannel _channel =
      MethodChannel('com.example.nyan_read/system');

  /// Used where no system search intent exists (iOS, desktop) or none is
  /// installed. Bing resolves both inside and outside mainland China.
  static Uri fallbackUrl(String query) =>
      Uri.https('www.bing.com', '/search', {'q': query});

  /// Returns false when nothing could open the search. May throw from
  /// `launchUrl`; callers own the user-visible fallback.
  static Future<bool> search(String query) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final opened = await _channel
            .invokeMethod<bool>('webSearch', <String, Object>{'query': query});
        if (opened == true) return true;
      } on PlatformException catch (e) {
        // Never log the query: it is book text (§2.2.4).
        debugPrint('System web search failed: ${e.code}');
      } on MissingPluginException {
        debugPrint('System web search channel unavailable');
      }
    }
    return launchUrl(fallbackUrl(query), mode: LaunchMode.externalApplication);
  }
}
