import 'package:shared_preferences/shared_preferences.dart';

class AppOnboardingService {
  AppOnboardingService._();

  static const notificationOnboardingSeenKey =
      'notification_onboarding_seen_v1';
  static const alertExperienceInitializedKey =
      'alert_experience_initialized_v1';
  static const _alertCacheKey = 'cached_alerts';
  static const _bgSeenArticleIdsKey = 'bg_seen_article_ids';
  static const _seenNewsKey = 'seen_news_ids_v1';
  static const _seenIndexKey = 'seen_index_keys_v1';

  static Future<bool> isNotificationOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(notificationOnboardingSeenKey) ?? false;
  }

  static Future<void> markNotificationOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationOnboardingSeenKey, true);
  }

  static Future<void> initializeAlertExperienceIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final initialized = prefs.getBool(alertExperienceInitializedKey) ?? false;
    if (initialized) {
      return;
    }

    await prefs.remove(_alertCacheKey);
    await prefs.remove(_bgSeenArticleIdsKey);
    await prefs.remove(_seenNewsKey);
    await prefs.remove(_seenIndexKey);
    await prefs.setBool(alertExperienceInitializedKey, true);
  }
}
