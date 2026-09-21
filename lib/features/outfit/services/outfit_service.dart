import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_client.dart';
import '../../wardrobe/data/wardrobe_repository_impl.dart';
import '../../wardrobe/domain/wardrobe_item_model.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_identity_profile.dart';
import '../domain/outfit_models.dart';
import '../domain/saved_outfit_model.dart';
import '../data/saved_outfits_repository.dart';
import 'outfit_intent_analyzer.dart';
import 'wardrobe_search_algorithm.dart';
import 'outfit_generator_service.dart';
import 'virtual_try_on_service.dart';

/// Servicio principal que orquesta todo el flujo de generación de outfits
///
/// Fases 1–3: intención → filtro → outfits (rápido, muestra UI).
/// Fase 4: try-on bajo demanda o solo el primer look (P1 progresivo).
class OutfitService {
  final WardrobeRepositoryImpl _wardrobeRepository = WardrobeRepositoryImpl();
  final ProfileRepository _profileRepository = ProfileRepository();
  final OutfitIntentAnalyzer _intentAnalyzer = OutfitIntentAnalyzer();
  final OutfitGeneratorService _outfitGenerator = OutfitGeneratorService();
  final VirtualTryOnService _tryOnService = VirtualTryOnService();
  final SavedOutfitsRepository _savedOutfitsRepository =
      SavedOutfitsRepository();

  _UserTryOnContext? _cachedTryOnContext;
  String? _cachedTryOnUserId;

  String? get _currentUserId =>
      AppSupabaseClient.client?.auth.currentUser?.id;

  /// Fases 1–3: genera outfits; persistencia Supabase en segundo plano.
  ///
  /// Si [precomputedIntent] viene del chat, se omite DeepSeek.
  Future<OutfitGenerationResult> generateOutfitSuggestions({
    required String userPrompt,
    OutfitIntent? precomputedIntent,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('User not logged in');

    try {
      debugPrint('🚀 Outfit suggestions (phases 1–3)');
      debugPrint('   Prompt: "$userPrompt"');

      final intent =
          precomputedIntent ??
          await _intentAnalyzer.analyzeUserPrompt(userPrompt);

      if (precomputedIntent != null) {
        debugPrint(
          '✅ Using precomputed intent from stylist chat (DeepSeek skipped)',
        );
      }

      final allItems = await _wardrobeRepository.getWardrobeItems();

      if (allItems.isEmpty) {
        throw Exception('Your wardrobe is empty. Please add some items first.');
      }

      final wardrobeImageUrlsByItemId = _imageUrlsByItemId(allItems);

      final filteredWardrobe =
          await WardrobeSearchAlgorithm.filterWardrobeSemantic(
            allItems: allItems,
            intent: intent,
            userPrompt: userPrompt,
          );

      if (filteredWardrobe.isEmpty) {
        throw Exception('No items match your request. Try different criteria.');
      }

      final hasTwoPiece =
          filteredWardrobe.tops.isNotEmpty && filteredWardrobe.bottoms.isNotEmpty;
      final hasOnePiece = filteredWardrobe.onePieces.isNotEmpty;
      final hasShoes = filteredWardrobe.shoes.isNotEmpty;

      if ((!hasTwoPiece && !hasOnePiece) || !hasShoes) {
        final missing = <String>[
          if (!hasTwoPiece && !hasOnePiece)
            'prenda completa (superior e inferior, o pieza única/vestido)',
          if (!hasShoes) 'calzado',
        ];
        throw Exception(
          'Con este pedido no hay suficientes prendas en el armario filtrado. '
          'Falta: ${missing.join(', ')}. Por ejemplo pediste negro pero quizá '
          'no tienes esa combinación etiquetada, o el filtro lo excluyó. '
          'Prueba otros colores, quita algún matiz o sube más prendas.',
        );
      }

      final outfits = await _outfitGenerator.generateOutfits(
        filteredWardrobe: filteredWardrobe,
        intent: intent,
      );

      final validOutfits = outfits
          .where((outfit) => outfit.hasCompleteLook)
          .toList();

      if (validOutfits.isEmpty) {
        if (outfits.isEmpty) {
          throw Exception(
            'La IA no devolvió ningún outfit. Intenta de nuevo o reformula '
            'el pedido.',
          );
        }
        final perOutfit = outfits
            .map(
              (o) =>
                  '[${o.id.isEmpty ? "sin_id" : o.id}] falta(n): '
                  '${o.missingFieldsSummary} '
                  '(onePiece="${o.onePieceId ?? "—"}", top="${o.topId ?? "—"}", '
                  'bottom="${o.bottomId ?? "—"}", shoes="${o.shoesId ?? "—"}")',
            )
            .join(' | ');
        debugPrint(
          '❌ Ningún outfit con look completo válido (pieza única + calzado o top + bottom + calzado). $perOutfit',
        );
        throw Exception(
          'La IA armó propuestas pero sin IDs válidos para armar el look '
          '(hacen falta calzado y pieza única, o calzado y par superior/inferior). '
          'Detalle: $perOutfit '
          'Suele pasar cuando el modelo envía otros nombres de campo; si persiste, intenta con menos filtros (colores).',
        );
      }

      unawaited(_saveOutfitsToDatabase(uid, validOutfits, intent, {}));

      return OutfitGenerationResult(
        outfits: validOutfits,
        intent: intent,
        wardrobeImageUrlsByItemId: wardrobeImageUrlsByItemId,
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to generate outfits: $e');
    }
  }

  /// Try-on de un solo outfit (fase 4 bajo demanda).
  Future<String?> generateTryOnForOutfit({
    required GeneratedOutfit outfit,
    required OutfitIntent intent,
    Map<String, String>? wardrobeImageUrlsByItemId,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('User not logged in');

    try {
      debugPrint('🖼️ Try-on for outfit ${outfit.id}');

      final itemImageUrls = wardrobeImageUrlsByItemId != null
          ? _resolveItemImageUrls(outfit, wardrobeImageUrlsByItemId)
          : await _getItemImageUrls(outfit);

      if (itemImageUrls.isEmpty) {
        debugPrint('⚠️ No garment images for outfit ${outfit.id}');
        return null;
      }

      final userContext = await _getUserTryOnContext(uid);

      final tryOnResult = await _tryOnService.generateTryOnImage(
        request: VirtualTryOnRequest(
          outfit: outfit,
          itemImageUrls: itemImageUrls,
          userBodyPhotoUrl: userContext.bodyPhotoUrl,
          userFacePhotoUrl: userContext.facePhotoUrl,
          identityProfile: userContext.identityProfile,
        ),
        userId: uid,
      );

      final url = tryOnResult.generatedImageUrl;
      if (url.isEmpty) return null;

      unawaited(_savedOutfitsRepository.updateTryOnImageUrl(outfit.id, url));
      debugPrint('✅ Try-on ready for ${outfit.id}');

      return url;
    } catch (e) {
      debugPrint('❌ Try-on failed for ${outfit.id}: $e');
      rethrow;
    }
  }

  /// Compatibilidad: sugerencias + try-on solo del primer look si [generateImage].
  Future<OutfitGenerationResult> generateCompleteOutfit({
    required String userPrompt,
    bool generateImage = false,
    OutfitIntent? precomputedIntent,
  }) async {
    final base = await generateOutfitSuggestions(
      userPrompt: userPrompt,
      precomputedIntent: precomputedIntent,
    );

    if (!generateImage || base.outfits.isEmpty) {
      return base;
    }

    final first = base.outfits.first;
    try {
      final url = await generateTryOnForOutfit(
        outfit: first,
        intent: base.intent,
        wardrobeImageUrlsByItemId: base.wardrobeImageUrlsByItemId,
      );
      if (url == null || url.isEmpty) return base;

      return OutfitGenerationResult(
        outfits: base.outfits,
        intent: base.intent,
        tryOnImageUrl: url,
        tryOnImageUrls: {first.id: url},
        wardrobeImageUrlsByItemId: base.wardrobeImageUrlsByItemId,
      );
    } catch (e) {
      debugPrint('⚠️ First try-on failed, returning outfits without image: $e');
      return base;
    }
  }

  static Map<String, String> _imageUrlsByItemId(List<WardrobeItem> items) {
    return {
      for (final item in items)
        if (item.id.isNotEmpty && item.imageUrl.isNotEmpty)
          item.id: item.imageUrl,
    };
  }

  static List<String> _resolveItemImageUrls(
    GeneratedOutfit outfit,
    Map<String, String> wardrobeImageUrlsByItemId,
  ) {
    final urls = <String>[];
    for (final itemId in outfit.itemIds) {
      final url = wardrobeImageUrlsByItemId[itemId];
      if (url != null && url.isNotEmpty) {
        urls.add(url);
      }
    }
    return urls;
  }

  Future<List<String>> _getItemImageUrls(GeneratedOutfit outfit) async {
    final urls = <String>[];

    if (!AppSupabaseClient.isInitialized || AppSupabaseClient.client == null) {
      return urls;
    }

    try {
      final rows = await AppSupabaseClient.client!
          .from('wardrobe_items')
          .select('source_path')
          .inFilter('id', outfit.itemIds);

      for (final r in rows) {
        final path = r['source_path'] as String?;
        if (path != null && path.isNotEmpty) {
          urls.add(path);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to get garment image URLs from Supabase: $e');
    }

    return urls;
  }

  Future<_UserTryOnContext> _getUserTryOnContext(String userId) async {
    if (_cachedTryOnUserId == userId && _cachedTryOnContext != null) {
      return _cachedTryOnContext!;
    }

    try {
      final profileData = await _profileRepository.getUserProfile(userId);
      if (profileData == null) {
        _cachedTryOnContext = const _UserTryOnContext();
        _cachedTryOnUserId = userId;
        return _cachedTryOnContext!;
      }

      final identityProfile = IdentityProfile.fromFirestoreUser(profileData);

      final bodyPhoto = profileData['bodyPhotos'] != null
          ? (profileData['bodyPhotos'] as List<dynamic>).firstOrNull?.toString()
          : null;

      final facePhoto = profileData['facePhotos'] != null
          ? (profileData['facePhotos'] as List<dynamic>).firstOrNull?.toString()
          : null;

      _cachedTryOnContext = _UserTryOnContext(
        bodyPhotoUrl: bodyPhoto,
        facePhotoUrl: facePhoto,
        identityProfile: identityProfile.isEmpty ? null : identityProfile,
      );
      _cachedTryOnUserId = userId;
      return _cachedTryOnContext!;
    } catch (e) {
      debugPrint('⚠️ Failed to get user try-on context: $e');
      return const _UserTryOnContext();
    }
  }

  Future<void> _saveOutfitsToDatabase(
    String userId,
    List<GeneratedOutfit> outfits,
    OutfitIntent intent,
    Map<String, String> tryOnImageUrls,
  ) async {
    try {
      final savedOutfits = outfits
          .map(
            (outfit) => SavedOutfit.fromGeneratedOutfit(
              outfit: outfit,
              intent: intent,
              userId: userId,
              tryOnImageUrl: tryOnImageUrls[outfit.id] ?? '',
            ),
          )
          .toList();

      await _savedOutfitsRepository.saveOutfits(savedOutfits);
      debugPrint('✅ Saved ${savedOutfits.length} outfits to Supabase');
    } catch (e) {
      debugPrint('⚠️ Failed to save outfits to Supabase: $e');
    }
  }
}

class _UserTryOnContext {
  final String? bodyPhotoUrl;
  final String? facePhotoUrl;
  final IdentityProfile? identityProfile;

  const _UserTryOnContext({
    this.bodyPhotoUrl,
    this.facePhotoUrl,
    this.identityProfile,
  });
}

/// Resultado de la generación de outfits
class OutfitGenerationResult {
  final List<GeneratedOutfit> outfits;
  final OutfitIntent intent;
  final String? tryOnImageUrl;
  final Map<String, String> tryOnImageUrls;
  final Map<String, String> wardrobeImageUrlsByItemId;

  OutfitGenerationResult({
    required this.outfits,
    required this.intent,
    this.tryOnImageUrl,
    Map<String, String>? tryOnImageUrls,
    Map<String, String>? wardrobeImageUrlsByItemId,
  }) : tryOnImageUrls = tryOnImageUrls ?? {},
       wardrobeImageUrlsByItemId = wardrobeImageUrlsByItemId ?? {};

  String? getImageUrlForOutfit(String outfitId) {
    return tryOnImageUrls[outfitId] ?? tryOnImageUrl;
  }
}
