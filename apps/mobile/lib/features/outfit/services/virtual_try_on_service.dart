import 'package:flutter/foundation.dart';

import '../../../core/constants/identity_consistency_prompt.dart';
import '../../../core/services/deepseek_service.dart';
import '../../../core/services/supabase_client.dart';
import '../../profile/domain/user_identity_profile.dart';
import '../domain/outfit_models.dart';

class VirtualTryOnService {
  final DeepSeekService _gateway;

  VirtualTryOnService({DeepSeekService? gatewayClient})
    : _gateway = gatewayClient ?? const DeepSeekService();

  Future<VirtualTryOnResult> generateTryOnImage({
    required VirtualTryOnRequest request,
    required String userId,
    String tryOnProvider = defaultTryOnProvider,
  }) async {
    if (!AppSupabaseClient.isInitialized || AppSupabaseClient.client == null) {
      throw Exception('Supabase client is not initialized');
    }

    try {
      debugPrint(
        '🌐 [VirtualTryOnService] Routing try-on to server-side ai-router for outfit: ${request.outfit.id}',
      );
      final isOnePiece =
          request.outfit.onePieceId != null &&
          request.outfit.onePieceId!.isNotEmpty;

      // Garantizar que la descripción de rasgos del Identity Board esté presente
      IdentityProfile? effectiveProfile = request.identityProfile;
      if (effectiveProfile == null || effectiveProfile.isEmpty) {
        try {
          final profileRes = await AppSupabaseClient.client!
              .from('profiles')
              .select('identity_profile')
              .eq('id', userId)
              .maybeSingle();
          if (profileRes != null && profileRes['identity_profile'] != null) {
            effectiveProfile = IdentityProfile.fromJson(
              Map<String, dynamic>.from(profileRes['identity_profile'] as Map),
            );
            debugPrint(
              '✅ [VirtualTryOnService] Loaded identity profile from Supabase for try-on prompt',
            );
          }
        } catch (e) {
          debugPrint(
            '⚠️ [VirtualTryOnService] Could not load identity profile: $e',
          );
        }
      }

      final prompt = IdentityConsistencyPrompt.buildTryOnPrompt(
        profile: effectiveProfile,
        isOnePiece: isOnePiece,
      );

      // Heurística: control de errores / expectativa correcta del sistema — una clave estable por
      // outfit+usuario hacía que el ai-router devolviera para siempre el primer resultado cacheado
      // (bueno o malo) en cada intento posterior, sin generar nunca una imagen nueva. Cada llamada
      // explícita a generar/regenerar debe producir una clave nueva; los reintentos internos por
      // fallos transitorios de red (dentro de invokeGateway) siguen reutilizando esta misma clave.
      final idempotencyKey =
          'tryon_${userId}_${request.outfit.id}_${DateTime.now().millisecondsSinceEpoch}';

      final res = await _gateway.generateTryOn(
        wardrobeItemIds: request.outfit.itemIds,
        tryOnProvider: tryOnProvider,
        scenePrompt: request.scenePrompt,
        prompt: prompt,
        outfitId: request.outfit.id,
        idempotencyKey: idempotencyKey,
      );

      final imageUrl = res['imageUrl']?.toString();
      if (imageUrl != null && imageUrl.isNotEmpty) {
        // Heurística: visibilidad del estado del sistema — permite diagnosticar en logs de cliente
        // si el resultado vino de caché o de una generación nueva, y con qué proveedor/modelo.
        debugPrint(
          '✅ [VirtualTryOnService] Server-side try-on successful: $imageUrl '
          '(isCacheHit=${res['isCacheHit']}, provider=${res['imageProvider']}, model=${res['imageModel']})',
        );
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
