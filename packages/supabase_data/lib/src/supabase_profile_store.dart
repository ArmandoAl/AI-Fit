import 'package:supabase/supabase.dart';

/// Lectura del perfil (`profiles` + `user_photos`) con la misma forma que usa la app móvil.
class SupabaseProfileStore {
  SupabaseProfileStore(this._client);

  final SupabaseClient _client;

  /// Null si la persona no tiene fila en `profiles`.
  Future<Map<String, dynamic>?> fetch(String userId) async {
    final profile = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (profile == null) return null;
    final photos = await _client.from('user_photos').select().eq('user_id', userId);
    List<String> paths(String kind) => [
          for (final photo in photos)
            if (photo['kind'] == kind) photo['storage_path'].toString(),
        ];
    return {
      'id': profile['id'],
      'displayName': profile['display_name'],
      'avatarUrl': profile['avatar_path'],
      'preferences': profile['preferences'] ?? {},
      'onboardingCompleted': profile['onboarding_completed'] ?? false,
      'identityProfile': profile['identity_profile'],
      'identityVersion': profile['identity_version'],
      'identityCollageUrl': profile['identity_collage_path'],
      'baseImageUrl': profile['base_image_path'],
      'bodyPhotos': paths('body'),
      'facePhotos': paths('face'),
    };
  }
}
