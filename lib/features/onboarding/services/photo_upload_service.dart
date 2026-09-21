import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/platform/app_image.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/utils/identity_photo_collage.dart';
import '../../outfit/services/user_base_image_service.dart';
import '../../profile/data/profile_repository.dart';

/// Servicio especializado en onboarding de fotos y composición del Identity Board.
/// Garantiza la eliminación total de placeholders de 1x1 píxel negro y valida
/// que toda imagen base resultante mida más de 50 KB antes de persistir en Storage.
class PhotoUploadService {
  final StorageService _storageService;
  final ProfileRepository _profileRepository;
  final UserBaseImageService _baseImageService;

  PhotoUploadService({
    StorageService? storageService,
    ProfileRepository? profileRepository,
    UserBaseImageService? baseImageService,
  })  : _storageService = storageService ?? StorageService(),
        _profileRepository = profileRepository ?? ProfileRepository(),
        _baseImageService = baseImageService ?? UserBaseImageService();

  SupabaseClient get _supabase {
    final client = AppSupabaseClient.client;
    if (client != null) return client;
    return Supabase.instance.client;
  }

  /// Sube las fotos de identidad de onboarding (rostro y cuerpo) a Supabase Storage
  /// y compone el Identity Board canónico (1024x1024, >= 50KB) sin placeholders 1x1.
  Future<String?> uploadOnboardingPhotosAndIdentityBoard({
    required String userId,
    required List<AppImage> facePhotos,
    required List<AppImage> bodyPhotos,
  }) async {
    if (facePhotos.isEmpty && bodyPhotos.isEmpty) {
      throw ArgumentError('At least one face or body photo is required.');
    }

    // 1. Salvaguarda FK: garantizar registro en profiles antes de insertar fotos
    await _profileRepository.ensureProfileExists(userId);

    // 2. Subir fotos de rostro a Storage y registrar en user_photos
    if (facePhotos.isNotEmpty) {
      await _profileRepository.uploadFacePhotos(
        userId: userId,
        photos: facePhotos,
      );
    }

    // 3. Subir fotos de cuerpo a Storage y registrar en user_photos
    if (bodyPhotos.isNotEmpty) {
      await _profileRepository.uploadBodyPhotos(
        userId: userId,
        photos: bodyPhotos,
      );
    }

    // 4. Componer y validar Identity Board canónico (1024x1024)
    String? baseImageUrl;
    try {
      final faceBytes = facePhotos.map((p) => p.bytes).toList();
      final bodyBytes = bodyPhotos.map((p) => p.bytes).toList();

      final Uint8List boardBytes = await IdentityPhotoCollage.buildIdentityBoard(
        facePhotos: faceBytes,
        bodyPhotos: bodyBytes,
      );

      // Verificación estricta de umbral: mínimo 50 KB
      if (boardBytes.lengthInBytes < StorageService.minGeneratedImageBytes) {
        throw ArgumentError(
          'Identity board composed bytes (${boardBytes.lengthInBytes} bytes) below 50KB threshold.',
        );
      }

      // Subida a Storage privado 'generated'
      baseImageUrl = await _storageService.uploadUserBaseImage(
        userId: userId,
        bytes: boardBytes,
      );

      // Actualizar registro en profiles
      await _supabase.from('profiles').update({
        'base_image_path': baseImageUrl,
        'base_image_content_hash': 'collage_fallback',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);

      debugPrint('✅ [PhotoUploadService] Canonical Identity Board composed and saved: $baseImageUrl');
    } catch (e) {
      debugPrint('⚠️ [PhotoUploadService] Error or fallback in identity board composition: $e');
      // No subir stubs ni archivos corruptos de 1x1; dejar que el flujo normal maneje la regeneración
    }

    await _profileRepository.completeOnboarding(userId);
    return baseImageUrl;
  }

  /// Verifica la integridad del Identity Board existente. Si está corrupto (< 1 KB o 149 bytes),
  /// lo purga y fuerza su regeneración limpia.
  Future<String?> checkAndRepairIdentityBoard({
    required String userId,
    required List<String> bodyPhotoUrls,
    required List<String> facePhotoUrls,
  }) async {
    final existing = await _baseImageService.getUserBaseImageUrl(userId);
    if (existing != null && existing.isNotEmpty) {
      final isCorrupt = await _baseImageService.isBaseImageCorrupt(existing);
      if (!isCorrupt) return existing;
    }

    // Si es corrupto o no existe, forzar regeneración limpia
    return await _baseImageService.regenerateUserBaseImage(
      userId: userId,
      bodyPhotoUrls: bodyPhotoUrls,
      facePhotoUrls: facePhotoUrls,
    );
  }
}
