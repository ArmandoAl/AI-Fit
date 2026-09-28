import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/platform/app_image.dart';
import '../../../core/services/onboarding_gate_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/supabase_client.dart';
import '../services/user_identity_analysis_service.dart';

class ProfileRepository {
  final StorageService _storageService = StorageService();
  final UserIdentityAnalysisService _identityAnalysisService =
      UserIdentityAnalysisService();

  SupabaseClient get _supabase {
    final client = AppSupabaseClient.client;
    if (client != null) return client;
    return Supabase.instance.client;
  }

  /// Get user profile data from Supabase
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final profileRes = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (profileRes == null) return null;

      final photosRes = await _supabase
          .from('user_photos')
          .select()
          .eq('user_id', userId);

      final photosList = (photosRes as List? ?? []);
      final bodyPhotos = photosList
          .where((p) => p['kind'] == 'body')
          .map((p) => p['storage_path'].toString())
          .toList();
      final facePhotos = photosList
          .where((p) => p['kind'] == 'face')
          .map((p) => p['storage_path'].toString())
          .toList();

      return {
        'id': profileRes['id'],
        'displayName': profileRes['display_name'],
        'avatarUrl': profileRes['avatar_path'],
        'preferences': profileRes['preferences'] ?? {},
        'onboardingCompleted': profileRes['onboarding_completed'] ?? false,
        'identityProfile': profileRes['identity_profile'],
        'identityVersion': profileRes['identity_version'],
        'identityCollageUrl': profileRes['identity_collage_path'],
        'baseImageUrl': profileRes['base_image_path'],
        'bodyPhotos': bodyPhotos,
        'facePhotos': facePhotos,
      };
    } catch (e) {
      debugPrint('❌ [ProfileRepository -> Supabase] Error getting profile: $e');
      return null;
    }
  }

  /// Garantiza defensivamente la existencia del registro en `public.profiles`.
  /// Evita que inserciones en `public.user_photos` fallen por restricción FK (code: 23503).
  Future<void> ensureProfileExists(String userId) async {
    try {
      final existing = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existing == null) {
        debugPrint(
          '⚠️ [ProfileRepository] Perfil no encontrado para $userId. Realizando upsert defensivo...',
        );
        await _supabase.from('profiles').upsert({
          'id': userId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'id');
        debugPrint(
          '✅ [ProfileRepository] Perfil defensivo confirmado para $userId',
        );
      }
    } catch (e) {
      debugPrint(
        '⚠️ [ProfileRepository] Error verificando perfil ($e), forzando upsert defensivo...',
      );
      try {
        await _supabase.from('profiles').upsert({
          'id': userId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'id');
        debugPrint(
          '✅ [ProfileRepository] Perfil forzado exitosamente para $userId',
        );
      } catch (upsertError) {
        debugPrint(
          '❌ [ProfileRepository] Fallo crítico al asegurar registro en profiles: $upsertError',
        );
        rethrow;
      }
    }
  }

  /// Upload body photos and update profile
  Future<void> uploadBodyPhotos({
    required String userId,
    required List<AppImage> photos,
  }) async {
    try {
      debugPrint('📸 Uploading ${photos.length} body photos...');

      // Salvaguarda FK: garantizar registro en public.profiles antes de subir fotos o insertar en user_photos
      await ensureProfileExists(userId);

      final urls = await _storageService.uploadMultiplePhotos(
        userId: userId,
        images: photos,
        photoType: 'body',
      );
      debugPrint('✅ Photos uploaded to Storage');

      for (final url in urls) {
        await _supabase.from('user_photos').upsert({
          'user_id': userId,
          'kind': 'body',
          'storage_path': url,
          'content_hash': 'hash_${url.hashCode}',
        }, onConflict: 'user_id, kind, content_hash');
      }
      debugPrint('✅ [ProfileRepository -> Supabase] Body photos saved');

      OnboardingGateService.invalidateCache();
      _refreshIdentityProfiles(userId);
    } catch (e) {
      debugPrint('❌ Error uploading body photos: $e');
      throw Exception('Failed to upload body photos: $e');
    }
  }

  /// Upload face photos and update profile
  Future<void> uploadFacePhotos({
    required String userId,
    required List<AppImage> photos,
  }) async {
    try {
      debugPrint('📸 Uploading ${photos.length} face photos...');

      // Salvaguarda FK: garantizar registro en public.profiles antes de subir fotos o insertar en user_photos
      await ensureProfileExists(userId);

      final urls = await _storageService.uploadMultiplePhotos(
        userId: userId,
        images: photos,
        photoType: 'face',
      );
      debugPrint('✅ Photos uploaded to Storage');

      for (final url in urls) {
        await _supabase.from('user_photos').upsert({
          'user_id': userId,
          'kind': 'face',
          'storage_path': url,
          'content_hash': 'hash_${url.hashCode}',
        }, onConflict: 'user_id, kind, content_hash');
      }
      debugPrint('✅ [ProfileRepository -> Supabase] Face photos saved');

      OnboardingGateService.invalidateCache();
      _refreshIdentityProfiles(userId);
    } catch (e) {
      debugPrint('❌ Error uploading face photos: $e');
      throw Exception('Failed to upload face photos: $e');
    }
  }

  /// Regenerates AI face/body text profiles from stored photo URLs (non-blocking).
  void _refreshIdentityProfiles(String userId) {
    Future(() async {
      try {
        final profile = await getUserProfile(userId);
        if (profile == null) return;
        final body =
            (profile['bodyPhotos'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .where((u) => u.isNotEmpty && !u.startsWith('mock://'))
                .toList() ??
            [];
        final face =
            (profile['facePhotos'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .where((u) => u.isNotEmpty && !u.startsWith('mock://'))
                .toList() ??
            [];
        await _identityAnalysisService.analyzeUserIdentity(
          userId: userId,
          bodyPhotoUrls: body,
          facePhotoUrls: face,
        );
      } catch (e) {
        debugPrint('⚠️ Identity profile refresh skipped: $e');
      }
    });
  }

  /// Remove a photo URL from database and delete from Storage
  Future<void> removePhoto({
    required String userId,
    required String photoUrl,
    required String photoType,
  }) async {
    try {
      await _storageService.deletePhoto(photoUrl);

      await _supabase
          .from('user_photos')
          .delete()
          .eq('user_id', userId)
          .eq('storage_path', photoUrl);
      debugPrint('✅ [ProfileRepository -> Supabase] Photo removed');
    } catch (e) {
      debugPrint('Error removing photo: $e');
      throw Exception('Failed to remove photo: $e');
    }
  }

  /// True si el usuario tiene al menos una foto válida (cara o cuerpo).
  Future<bool> hasUserIdentityPhotos(String userId) async {
    try {
      final profile = await getUserProfile(userId);
      if (profile == null) return false;

      final body = _validPhotoUrls(profile['bodyPhotos']);
      final face = _validPhotoUrls(profile['facePhotos']);

      return body.isNotEmpty || face.isNotEmpty;
    } catch (e) {
      debugPrint('⚠️ hasUserIdentityPhotos check failed: $e');
      return false;
    }
  }

  List<String> _validPhotoUrls(dynamic field) {
    if (field is! List) return [];
    return field
        .map((e) => e.toString())
        .where((u) => u.isNotEmpty && !u.startsWith('mock://'))
        .toList();
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding(String userId) async {
    try {
      await _supabase
          .from('profiles')
          .update({'onboarding_completed': true})
          .eq('id', userId);
      debugPrint('✅ [ProfileRepository -> Supabase] Onboarding completed');
    } catch (e) {
      debugPrint('⚠️ Onboarding completion skipped: $e');
    }
  }

  /// Update user preferences
  Future<void> updatePreferences({
    required String userId,
    required Map<String, dynamic> preferences,
  }) async {
    try {
      await _supabase
          .from('profiles')
          .update({'preferences': preferences})
          .eq('id', userId);
      debugPrint('✅ [ProfileRepository -> Supabase] Preferences updated');
    } catch (e) {
      debugPrint('Error updating preferences: $e');
      throw Exception('Failed to update preferences: $e');
    }
  }

  /// Delete user account and all associated data
  Future<void> deleteUserAccount(String userId) async {
    try {
      debugPrint('🗑️ Deleting user account: $userId');

      final profileData = await getUserProfile(userId);
      if (profileData != null) {
        final bodyPhotos = profileData['bodyPhotos'] as List<dynamic>? ?? [];
        final facePhotos = profileData['facePhotos'] as List<dynamic>? ?? [];

        final allPhotoUrls = [
          ...bodyPhotos.map((url) => url.toString()),
          ...facePhotos.map((url) => url.toString()),
        ].where((url) => url.isNotEmpty && !url.startsWith('mock://')).toList();

        for (final url in allPhotoUrls) {
          try {
            await _storageService.deletePhoto(url);
          } catch (e) {
            debugPrint('⚠️ Error deleting photo $url: $e');
          }
        }
      }

      await _supabase.from('wardrobe_items').delete().eq('user_id', userId);
      await _supabase.from('user_photos').delete().eq('user_id', userId);
      await _supabase.from('profiles').delete().eq('id', userId);

      debugPrint(
        '✅ [ProfileRepository -> Supabase] User account and data deleted',
      );
    } catch (e) {
      debugPrint('❌ Error deleting user account: $e');
      throw Exception('Failed to delete user account: $e');
    }
  }
}
