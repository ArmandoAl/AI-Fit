import 'package:flutter/foundation.dart';

import '../../../core/constants/identity_consistency_prompt.dart';
import '../../../core/services/deepseek_service.dart';
import '../../../core/services/supabase_client.dart';
import '../domain/outfit_models.dart';
import 'user_base_image_service.dart';

class VirtualTryOnService {
  final UserBaseImageService _baseImageService;
  final DeepSeekService _gateway;

  VirtualTryOnService({
    UserBaseImageService? baseImageService,
    DeepSeekService? gatewayClient,
  })  : _baseImageService = baseImageService ?? UserBaseImageService(),
        _gateway = gatewayClient ?? const DeepSeekService();

  Future<VirtualTryOnResult> generateTryOnImage({
    required VirtualTryOnRequest request,
    required String userId,
  }) async {
    if (!AppSupabaseClient.isInitialized || AppSupabaseClient.client == null) {
      throw Exception('Supabase client is not initialized');
    }

    try {
      debugPrint(
        '🌐 [VirtualTryOnService] Routing try-on to server-side ai-router for outfit: ${request.outfit.id}',
      );
      final baseImageUrl = await _baseImageService.getUserBaseImageUrl(userId);
      final effectiveIdentityUrl = baseImageUrl ??
          request.userBodyPhotoUrl ??
          request.userFacePhotoUrl ??
          '';

      // Tarea 3.4 & Accesorios-2: Resolver cutouts para el pipeline de 2 imágenes (Identity + Flat-Lay)
      List<Map<String, String>>? outfitItemsWithCutouts = request.items;
      final accessoryDescriptions = <String>[];
      final isOnePiece = request.outfit.onePieceId != null &&
          request.outfit.onePieceId!.isNotEmpty;

      if (request.outfit.itemIds.isNotEmpty) {
        try {
          final rows = await AppSupabaseClient.client!
              .from('wardrobe_items')
              .select('id, category, subtype, name, cutout_path')
              .inFilter('id', request.outfit.itemIds);
          if (rows.isNotEmpty) {
            final list = <Map<String, String>>[];
            for (final r in rows) {
              final cutout = r['cutout_path'] as String?;
              final cat = r['category'] as String?;
              final name = r['name'] as String? ?? '';
              final subtype = r['subtype'] as String? ?? '';
              if (cutout != null && cutout.isNotEmpty && cat != null) {
                list.add({
                  'category': cat,
                  'cutoutPath': cutout,
                  if (subtype.isNotEmpty) 'subtype': subtype,
                  if (name.isNotEmpty) 'name': name,
                });
              }
              if (cat == 'accessories' ||
                  cat == 'accessory' ||
                  cat == 'scarf' ||
                  cat == 'bag') {
                accessoryDescriptions.add(name.isNotEmpty ? name : subtype);
              }
            }
            if (list.isNotEmpty && outfitItemsWithCutouts == null) {
              outfitItemsWithCutouts = list;
              debugPrint(
                '✅ [VirtualTryOnService] Resolved ${list.length} cutouts for flat-lay generation',
              );
            }
          }
        } catch (cutoutErr) {
          debugPrint('⚠️ [VirtualTryOnService] Could not resolve cutouts: $cutoutErr');
        }
      }

      final prompt = IdentityConsistencyPrompt.buildTryOnPrompt(
        profile: request.identityProfile,
        hasBaseImage: baseImageUrl != null,
        hasFaceAnchor: request.userFacePhotoUrl != null,
        garmentCount: request.itemImageUrls.length,
        hasFlatlay: request.garmentFlatlayUrl != null ||
            (outfitItemsWithCutouts != null && outfitItemsWithCutouts.isNotEmpty),
        isOnePiece: isOnePiece,
        accessoryDescriptions: accessoryDescriptions,
      );

      final idempotencyKey = 'tryon_${userId}_${request.outfit.id}';

      final res = await _gateway.generateTryOn(
        identityImageUrl: effectiveIdentityUrl,
        garmentImageUrls: request.itemImageUrls,
        garmentFlatlayUrl: request.garmentFlatlayUrl,
        items: outfitItemsWithCutouts,
        prompt: prompt,
        outfitId: request.outfit.id,
        idempotencyKey: idempotencyKey,
      );

      final imageUrl = res['imageUrl']?.toString();
      if (imageUrl != null && imageUrl.isNotEmpty) {
        debugPrint('✅ [VirtualTryOnService] Server-side try-on successful: $imageUrl');
        return VirtualTryOnResult(
          outfitId: request.outfit.id,
          generatedImageUrl: imageUrl,
          generatedAt: DateTime.now(),
        );
      }

      throw Exception('Gateway response did not contain an image URL');
    } catch (e) {
      debugPrint('❌ [VirtualTryOnService] Try-on generation failed: $e');
      throw Exception('Failed to generate try-on image: $e');
    }
  }
}
