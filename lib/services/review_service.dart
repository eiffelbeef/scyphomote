import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewService {
  static const String _launchCountKey = 'app_launch_count';
  static const String _lastPromptDateKey = 'review_last_prompt_date';

  static const int minLaunchCount = 20;
  static const int cooldownDays = 30;

  static Future<void> recordLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_launchCountKey) ?? 0) + 1;
      await prefs.setInt(_launchCountKey, count);
    } catch (_) {}
  }

  static Future<int> getLaunchCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_launchCountKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> requestReviewIfEligible() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_launchCountKey) ?? 0;
      if (count < minLaunchCount) return;

      final lastPromptMillis = prefs.getInt(_lastPromptDateKey);
      if (lastPromptMillis != null) {
        final lastPrompt = DateTime.fromMillisecondsSinceEpoch(lastPromptMillis);
        if (DateTime.now().difference(lastPrompt).inDays < cooldownDays) {
          return;
        }
      }

      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await prefs.setInt(
          _lastPromptDateKey,
          DateTime.now().millisecondsSinceEpoch,
        );
        await inAppReview.requestReview();
      }
    } catch (_) {}
  }
}
