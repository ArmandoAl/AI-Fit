import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias locales del onboarding (tips / carousel).
class OnboardingPrefs {
  OnboardingPrefs._();

  static const _keyTipsSeen = 'onboarding_tips_seen_v1';

  static Future<bool> hasSeenTips() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTipsSeen) ?? false;
  }

  static Future<void> markTipsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTipsSeen, true);
  }
}
