import 'package:flutter/foundation.dart';
import '../../features/profile/data/profile_repository.dart';
import 'onboarding_prefs.dart';

/// Decide si mostrar welcome / setup-photos o ir directo al app.
class OnboardingGateService {
  OnboardingGateService._();

  static final ProfileRepository _profileRepository = ProfileRepository();

  static String? _cachedUserId;
  static bool? _cachedHasPhotos;
  static bool? _cachedTipsSeen;

  static void invalidateCache() {
    _cachedUserId = null;
    _cachedHasPhotos = null;
    _cachedTipsSeen = null;
  }

  /// Al menos una foto real de cara o cuerpo en Firestore.
  static Future<bool> userHasIdentityPhotos(String userId) async {
    if (_cachedUserId == userId && _cachedHasPhotos != null) {
      return _cachedHasPhotos!;
    }

    final has = await _profileRepository.hasUserIdentityPhotos(userId);
    _cachedUserId = userId;
    _cachedHasPhotos = has;
    return has;
  }

  static Future<bool> shouldShowTips(String userId) async {
    if (await userHasIdentityPhotos(userId)) return false;

    if (_cachedUserId == userId && _cachedTipsSeen != null) {
      return !_cachedTipsSeen!;
    }

    final seen = await OnboardingPrefs.hasSeenTips();
    _cachedTipsSeen = seen;
    return !seen;
  }

  /// Ruta inicial tras login / splash para usuarios autenticados.
  static Future<String> initialRouteFor(String userId) async {
    if (await userHasIdentityPhotos(userId)) {
      debugPrint('🚪 Onboarding: user has photos → /wardrobe');
      return '/wardrobe';
    }

    if (await shouldShowTips(userId)) {
      debugPrint('🚪 Onboarding: show tips → /welcome');
      return '/welcome';
    }

    debugPrint('🚪 Onboarding: tips seen, no photos → /setup-photos');
    return '/setup-photos';
  }

  /// Evita mostrar onboarding si ya no aplica.
  static Future<String?> redirectIfOnboardingComplete(
    String userId,
    String location,
  ) async {
    if (await userHasIdentityPhotos(userId)) {
      if (location == '/welcome' || location == '/setup-photos') {
        return '/wardrobe';
      }
      return null;
    }

    if (location == '/welcome' && !await shouldShowTips(userId)) {
      return '/setup-photos';
    }

    return null;
  }
}
