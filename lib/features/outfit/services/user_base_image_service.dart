import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/identity_consistency_prompt.dart';
import '../../../core/platform/network_image_loader.dart';
import '../../../core/services/deepseek_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/supabase_client.dart';
import '../../../core/utils/identity_photo_collage.dart';
import '../../profile/domain/user_identity_profile.dart';
import '../../profile/services/user_identity_analysis_service.dart';

class UserBaseImageService {
  final StorageService _storageService;
  final UserIdentityAnalysisService _identityService;
  final DeepSeekService _gateway;
  final Dio _dio;

  UserBaseImageService({
    StorageService? storageService,
    UserIdentityAnalysisService? identityService,
    DeepSeekService? gatewayClient,
    Dio? dio,
  })  : _storageService = storageService ?? StorageService(),
        _identityService = identityService ?? UserIdentityAnalysisService(),
        _gateway = gatewayClient ?? const DeepSeekService(),
        _dio = dio ?? Dio();

  /// Comprueba si la URL apunta a una imagen corrupta (< 1 KB) o placeholder stub (149 bytes o 1x1).
  Future<bool> isBaseImageCorrupt(String url) async {
    if (url.isEmpty || url.startsWith('mock://')) return true;
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Range': 'bytes=0-2048'},
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      final data = response.data;
      if (data == null || data.isEmpty) return true;

      // Si la carga útil recibida tiene menos de 1024 bytes (1 KB)
      if (data.length < 1024) {
        debugPrint('⚠️ [UserBaseImageService] Image size is ${data.length} bytes (< 1 KB). Flagged as corrupt.');
        return true;
      }

      // Comprobar Content-Length si está disponible
      final contentLengthStr = response.headers.value('content-length');
      if (contentLengthStr != null) {
        final totalLength = int.tryParse(contentLengthStr);
        if (totalLength != null && totalLength < 1024) {
          debugPrint('⚠️ [UserBaseImageService] Content-Length is $totalLength bytes (< 1 KB). Flagged as corrupt.');
          return true;
        }
      }

      // Comprobar Content-Range si está disponible (ej. "bytes 0-148/149")
      final contentRange = response.headers.value('content-range');
      if (contentRange != null && contentRange.contains('/')) {
        final totalStr = contentRange.split('/').last.trim();
        final totalLength = int.tryParse(totalStr);
        if (totalLength != null && totalLength < 1024) {
          debugPrint('⚠️ [UserBaseImageService] Content-Range total is $totalLength bytes (< 1 KB). Flagged as corrupt.');
          return true;
        }
      }

      // Si es un stub de 149 bytes (1x1 JPEG)
      if (data.length <= 149) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('⚠️ [UserBaseImageService] Error checking image integrity ($url): $e');
      return false;
    }
  }

  Future<String> generateUserBaseImage({
    required String userId,
    required List<String> bodyPhotoUrls,
    required List<String> facePhotoUrls,
  }) async {
    if (!AppSupabaseClient.isInitialized || AppSupabaseClient.client == null) {
      throw Exception('Supabase client is not initialized');
    }

    try {
      debugPrint(
        '🌐 [UserBaseImageService] Routing base image generation...',
      );
      final existingBaseImage = await _getExistingBaseImage(userId);
      if (existingBaseImage != null && existingBaseImage.isNotEmpty) {
        debugPrint('✅ User base image already exists: $existingBaseImage');
        return existingBaseImage;
      }

      var identityProfile = await _loadIdentityProfile(userId);
      String? collageUrl = await _getIdentityCollageUrl(userId);

      if (identityProfile == null || identityProfile.isEmpty) {
        identityProfile = await _identityService.analyzeUserIdentity(
          userId: userId,
          bodyPhotoUrls: bodyPhotoUrls,
          facePhotoUrls: facePhotoUrls,
        );
        collageUrl = await _getIdentityCollageUrl(userId);
      }

      final effectiveIdentityUrl = collageUrl ??
          facePhotoUrls.firstOrNull ??
          bodyPhotoUrls.firstOrNull ??
          '';

      final prompt = _buildBaseImagePrompt(identityProfile);
      final idempotencyKey = 'base_image_$userId';

      // 1. Intentar generación server-side por IA si hay gateway
      try {
        debugPrint('🌐 [UserBaseImageService] Attempting server-side base image generation via ai-router...');
        final res = await _gateway.generateBaseImage(
          identityImageUrl: effectiveIdentityUrl,
          prompt: prompt,
          idempotencyKey: idempotencyKey,
        );

        final imageUrl = res['imageUrl']?.toString();
        if (imageUrl != null && imageUrl.isNotEmpty) {
          final isCorrupt = await isBaseImageCorrupt(imageUrl);
          if (!isCorrupt) {
            await _saveBaseImageUrl(userId, imageUrl, isAiMannequin: true);
            debugPrint('✅ [UserBaseImageService] Server-side base image created: $imageUrl');
            return imageUrl;
          } else {
            debugPrint('⚠️ [UserBaseImageService] Gateway returned corrupt image (< 1KB). Falling back to local identity board...');
          }
        }
      } catch (aiErr) {
        debugPrint('⚠️ [UserBaseImageService] Server AI generation failed: $aiErr. Falling back to robust local identity board composition...');
      }

      // 2. Fallback Robusto: Composición Local de Identity Board (1024x1024, >50KB)
      debugPrint('🎨 [UserBaseImageService] Composing robust local Identity Board (1024x1024)...');
      final composedUrl = await _composeAndUploadLocalIdentityBoard(
        userId: userId,
        bodyPhotoUrls: bodyPhotoUrls,
        facePhotoUrls: facePhotoUrls,
      );

      await _saveBaseImageUrl(userId, composedUrl, isAiMannequin: false);
      debugPrint('✅ [UserBaseImageService] Robust local identity board created and saved: $composedUrl');
      return composedUrl;
    } catch (e) {
      debugPrint('❌ [UserBaseImageService] Base image generation failed: $e');
      throw Exception('Failed to generate base image: $e');
    }
  }

  Future<String> _composeAndUploadLocalIdentityBoard({
    required String userId,
    required List<String> bodyPhotoUrls,
    required List<String> facePhotoUrls,
  }) async {
    final validFaceUrls = facePhotoUrls.where((u) => u.isNotEmpty && !u.startsWith('mock://')).toList();
    final validBodyUrls = bodyPhotoUrls.where((u) => u.isNotEmpty && !u.startsWith('mock://')).toList();

    final faceBytes = await _downloadPhotoBytes(validFaceUrls);
    final bodyBytes = await _downloadPhotoBytes(validBodyUrls);

    if (faceBytes.isEmpty && bodyBytes.isEmpty) {
      throw Exception('Cannot compose identity board: No valid face or body photos could be loaded.');
    }

    final boardBytes = await IdentityPhotoCollage.buildIdentityBoard(
      facePhotos: faceBytes,
      bodyPhotos: bodyBytes,
    );

    if (boardBytes.lengthInBytes < StorageService.minGeneratedImageBytes) {
      throw Exception(
        'Composed identity board is below 50KB (${boardBytes.lengthInBytes} bytes). Composition failed.',
      );
    }

    return await _storageService.uploadUserBaseImage(
      userId: userId,
      bytes: boardBytes,
    );
  }

  Future<List<Uint8List>> _downloadPhotoBytes(List<String> urls) async {
    final list = <Uint8List>[];
    for (var i = 0; i < urls.length && i < 4; i++) {
      try {
        list.add(await NetworkImageLoader.downloadBytes(_dio, urls[i]));
      } catch (e) {
        debugPrint('⚠️ Failed to download photo for identity board: $e');
      }
    }
    return list;
  }

  Future<String?> _getExistingBaseImage(String userId) async {
    try {
      if (!AppSupabaseClient.isInitialized || AppSupabaseClient.client == null) return null;
      final res = await AppSupabaseClient.client!
          .from('profiles')
          .select('base_image_path')
          .eq('id', userId)
          .maybeSingle();
      final url = res?['base_image_path'] as String?;
      if (url == null || url.isEmpty) return null;

      // Validar si la imagen existente es corrupta (< 1 KB)
      final isCorrupt = await isBaseImageCorrupt(url);
      if (isCorrupt) {
        debugPrint('⚠️ [UserBaseImageService] Found corrupt base image ($url). Purging from profiles.');
        await AppSupabaseClient.client!
            .from('profiles')
            .update({
              'base_image_path': null,
              'base_image_content_hash': null,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);
        return null;
      }

      return url;
    } catch (e) {
      debugPrint('⚠️ [UserBaseImageService] Error fetching existing base image: $e');
      return null;
    }
  }

  Future<String?> _getIdentityCollageUrl(String userId) async {
    try {
      if (!AppSupabaseClient.isInitialized || AppSupabaseClient.client == null) return null;
      final res = await AppSupabaseClient.client!
          .from('profiles')
          .select('identity_collage_path')
          .eq('id', userId)
          .maybeSingle();
      return res?['identity_collage_path'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<IdentityProfile?> _loadIdentityProfile(String userId) async {
    try {
      if (!AppSupabaseClient.isInitialized || AppSupabaseClient.client == null) return null;
      final res = await AppSupabaseClient.client!
          .from('profiles')
          .select('identity_profile')
          .eq('id', userId)
          .maybeSingle();
      final data = res?['identity_profile'];
      if (data != null && data is Map) {
        return IdentityProfile.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Could not load identity profile: $e');
      return null;
    }
  }

  String _buildBaseImagePrompt(IdentityProfile? profile) {
    final identityBlock = IdentityConsistencyPrompt.buildBaseImageBlock(
      profile,
    );

    return """
[OUTPUT_SPECIFICATIONS]
MODE: IMAGE_GENERATION
FORMAT: image/jpeg
ASPECT_RATIO: 3:4
RESOLUTION: 1024x1365
QUALITY: PREMIUM_ECOMMERCE

[REFERENCE_IMAGE]
The attached image is a vertical identity collage with 4 rows:
1) front face  2) 3/4 face  3) full body front  4) full body side.
Reconstruct ONE consistent real person from all rows.

$identityBlock

[INSTRUCTION]
Generate a single full-body ecommerce model reference photograph of the SAME person.

[REQUIREMENTS]
- Exact identity match: facial structure, skin tone, ethnicity, hairstyle, body proportions
- Full-body or 3/4 shot, neutral standing pose (A-pose), front-facing
- Clean white or light gray studio background, even soft lighting
- Natural skin texture, neutral expression, no beauty filters
- Simple neutral base-layer clothing (fitted tank + leggings) that shows silhouette

[AVOID]
- Cinematic lighting, editorial fashion, dramatic shadows, stylization, retouching

[FINAL_OBJECTIVE]
Premium virtual try-on base template. Realistic, neutral, identity-accurate.
""";
  }

  Future<void> _saveBaseImageUrl(
    String userId,
    String imageUrl, {
    bool isAiMannequin = true,
  }) async {
    if (!AppSupabaseClient.isInitialized || AppSupabaseClient.client == null) return;
    await AppSupabaseClient.client!
        .from('profiles')
        .update({
          'base_image_path': imageUrl,
          'base_image_content_hash': isAiMannequin ? 'ai_mannequin' : 'collage_fallback',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  Future<bool> isBaseImageCollageFallback(String userId) async {
    try {
      if (!AppSupabaseClient.isInitialized || AppSupabaseClient.client == null) return false;
      final res = await AppSupabaseClient.client!
          .from('profiles')
          .select('base_image_content_hash, base_image_path')
          .eq('id', userId)
          .maybeSingle();

      final hash = res?['base_image_content_hash'] as String?;
      if (hash != null) {
        return hash == 'collage_fallback';
      }

      // Heurística defensiva por path si el hash no estuviera asignado previamente
      final path = res?['base_image_path'] as String? ?? '';
      return path.contains('base_image_') && !path.contains('/identity/base_');
    } catch (_) {
      return false;
    }
  }

  Future<String?> getUserBaseImageUrl(String userId) async {
    return _getExistingBaseImage(userId);
  }

  Future<void> deleteUserBaseImage(String userId) async {
    try {
      if (AppSupabaseClient.isInitialized && AppSupabaseClient.client != null) {
        final res = await AppSupabaseClient.client!
            .from('profiles')
            .select('base_image_path')
            .eq('id', userId)
            .maybeSingle();
        final existingUrl = res?['base_image_path'] as String?;

        if (existingUrl != null && existingUrl.isNotEmpty) {
          try {
            await _storageService.deletePhoto(existingUrl);
          } catch (e) {
            debugPrint('⚠️ Could not delete base image from Storage: $e');
          }
        }

        await AppSupabaseClient.client!
            .from('profiles')
            .update({
              'base_image_path': null,
              'base_image_content_hash': null,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);
      }

      debugPrint('✅ Base image deleted for user $userId');
    } catch (e) {
      debugPrint('❌ Error deleting base image: $e');
      throw Exception('Failed to delete base image: $e');
    }
  }

  Future<String> regenerateUserBaseImage({
    required String userId,
    required List<String> bodyPhotoUrls,
    required List<String> facePhotoUrls,
    bool refreshIdentityProfile = true,
  }) async {
    await deleteUserBaseImage(userId);

    if (refreshIdentityProfile &&
        (bodyPhotoUrls.isNotEmpty || facePhotoUrls.isNotEmpty)) {
      await _identityService.analyzeUserIdentity(
        userId: userId,
        bodyPhotoUrls: bodyPhotoUrls,
        facePhotoUrls: facePhotoUrls,
      );
    }

    return generateUserBaseImage(
      userId: userId,
      bodyPhotoUrls: bodyPhotoUrls,
      facePhotoUrls: facePhotoUrls,
    );
  }
}
