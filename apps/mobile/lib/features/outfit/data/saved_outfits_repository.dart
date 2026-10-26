import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/supabase_client.dart';
import '../domain/outfit_models.dart';
import '../domain/saved_outfit_model.dart';

/// Repositorio de outfits guardados 100% sobre Supabase Postgres
/// con modelo relacional (`outfit_generations`, `outfits`, `outfit_items`).
class SavedOutfitsRepository {
  SupabaseClient get _supabase {
    final client = AppSupabaseClient.client;
    if (client != null) return client;
    return Supabase.instance.client;
  }

  String? _getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }

  static String _ensureUuid(String id) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (uuidRegex.hasMatch(id)) {
      return id;
    }
    return const Uuid().v4();
  }

  /// Guarda un outfit relacionalmente en Supabase Postgres y retorna el UUID persistido.
  Future<String> saveOutfit(SavedOutfit savedOutfit) async {
    final userId = _getCurrentUserId();
    if (userId == null) throw Exception('No user logged in');

    try {
      final outfitId = _ensureUuid(savedOutfit.id);
      final generationId = const Uuid().v4();

      debugPrint('💾 [SavedOutfitsRepository -> Supabase] Saving outfit $outfitId');

      await _supabase.from('outfit_generations').upsert({
        'id': generationId,
        'user_id': userId,
        'idempotency_key': 'gen_$outfitId',
        'user_prompt': savedOutfit.userPrompt.isNotEmpty
            ? savedOutfit.userPrompt
            : 'Saved Outfit',
        'intent': savedOutfit.intent.toJson(),
        'status': 'completed',
        'text_provider': 'deepseek',
        'text_model': 'deepseek-chat',
        'created_at': savedOutfit.createdAt.toUtc().toIso8601String(),
      }, onConflict: 'user_id, idempotency_key');

      await _supabase.from('outfits').upsert({
        'id': outfitId,
        'generation_id': generationId,
        'user_id': userId,
        'rank': 1,
        'match_percentage': savedOutfit.matchPercentage,
        'compatibility_score': savedOutfit.compatibilityScore,
        'explanation': savedOutfit.outfit.explanation,
        'explanation_es': savedOutfit.outfit.explanationEs,
        'try_on_path': savedOutfit.tryOnImageUrl,
        'is_favorite': savedOutfit.isFavorite,
        'custom_tags': savedOutfit.customTags,
        'notes': savedOutfit.notes,
        'view_count': savedOutfit.viewCount,
        'created_at': savedOutfit.createdAt.toUtc().toIso8601String(),
      }, onConflict: 'id');

      final roles = [
        if (savedOutfit.outfit.onePieceId != null &&
            savedOutfit.outfit.onePieceId!.isNotEmpty)
          ('one_piece', savedOutfit.outfit.onePieceId!),
        if (savedOutfit.outfit.topId != null &&
            savedOutfit.outfit.topId!.isNotEmpty)
          ('top', savedOutfit.outfit.topId!),
        if (savedOutfit.outfit.bottomId != null &&
            savedOutfit.outfit.bottomId!.isNotEmpty)
          ('bottom', savedOutfit.outfit.bottomId!),
        if (savedOutfit.outfit.shoesId != null &&
            savedOutfit.outfit.shoesId!.isNotEmpty)
          ('shoes', savedOutfit.outfit.shoesId!),
        if (savedOutfit.outfit.outerwearId != null &&
            savedOutfit.outfit.outerwearId!.isNotEmpty)
          ('outerwear', savedOutfit.outfit.outerwearId!),
        for (final accId in savedOutfit.outfit.accessoryIds)
          if (accId.isNotEmpty) ('accessory', accId),
      ];

      for (final item in roles) {
        try {
          await _supabase.from('outfit_items').upsert({
            'outfit_id': outfitId,
            'wardrobe_item_id': item.$2,
            'role': item.$1,
          }, onConflict: 'outfit_id, wardrobe_item_id');
        } catch (itemErr) {
          debugPrint('⚠️ Non-critical error saving outfit_item: $itemErr');
        }
      }

      debugPrint('✅ [SavedOutfitsRepository -> Supabase] Outfit $outfitId saved');
      return outfitId;
    } catch (e) {
      debugPrint('❌ [SavedOutfitsRepository -> Supabase] Error saving outfit: $e');
      throw Exception('Failed to save outfit: $e');
    }
  }

  Future<List<String>> saveOutfits(List<SavedOutfit> outfits) async {
    final savedIds = <String>[];
    for (final outfit in outfits) {
      try {
        final id = await saveOutfit(outfit);
        savedIds.add(id);
      } catch (e) {
        debugPrint('⚠️ Failed to save outfit ${outfit.id}: $e');
      }
    }
    return savedIds;
  }

  Future<List<SavedOutfit>> getSavedOutfits({
    String? filterByOccasion,
    String? filterBySeason,
    List<String>? filterByColors,
    List<String>? filterByStyleTags,
    bool? onlyFavorites,
  }) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      debugPrint('⚠️ No user logged in');
      return [];
    }

    try {
      debugPrint('📦 [SavedOutfitsRepository -> Supabase] Loading lookbook for user: $userId');

      var query = _supabase.from('outfits').select('''
        id,
        generation_id,
        user_id,
        rank,
        match_percentage,
        compatibility_score,
        explanation,
        explanation_es,
        try_on_path,
        is_favorite,
        custom_tags,
        notes,
        view_count,
        created_at,
        last_viewed_at,
        outfit_generations (
          user_prompt,
          intent
        ),
        outfit_items (
          role,
          wardrobe_item_id
        )
      ''').eq('user_id', userId);

      if (onlyFavorites == true) {
        query = query.eq('is_favorite', true);
      }

      final response = await query.order('created_at', ascending: false);
      final list = response as List;

      final outfits = list.map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final gen = map['outfit_generations'] is Map
            ? Map<String, dynamic>.from(map['outfit_generations'] as Map)
            : <String, dynamic>{};
        final intentMap = gen['intent'] is Map
            ? Map<String, dynamic>.from(gen['intent'] as Map)
            : <String, dynamic>{};
        final intent = OutfitIntent.fromJson(intentMap);

        final items = (map['outfit_items'] as List? ?? []);
        String? onePieceId;
        String? topId;
        String? bottomId;
        String? shoesId;
        String? outerwearId;
        final accessoryIds = <String>[];

        for (final item in items) {
          final role = item['role']?.toString().toLowerCase();
          final itemId = item['wardrobe_item_id']?.toString();
          if (itemId == null || itemId.isEmpty) continue;
          if (role == 'one_piece' || role == 'one-piece' || role == 'dress') {
            onePieceId = itemId;
          } else if (role == 'top') {
            topId = itemId;
          } else if (role == 'bottom') {
            bottomId = itemId;
          } else if (role == 'shoes') {
            shoesId = itemId;
          } else if (role == 'outerwear') {
            outerwearId = itemId;
          } else if (role == 'accessory' || role == 'accessories') {
            accessoryIds.add(itemId);
          }
        }

        final generatedOutfit = GeneratedOutfit(
          id: map['id'].toString(),
          onePieceId: onePieceId,
          topId: topId,
          bottomId: bottomId,
          shoesId: shoesId,
          outerwearId: outerwearId,
          accessoryIds: accessoryIds,
          matchPercentage: (map['match_percentage'] as num? ?? 0).toInt(),
          explanation: map['explanation']?.toString() ?? '',
          explanationEs: map['explanation_es']?.toString() ?? '',
          compatibilityScore: (map['compatibility_score'] as num? ?? 0.0).toDouble(),
        );

        return SavedOutfit(
          id: map['id'].toString(),
          userId: map['user_id'].toString(),
          tryOnImageUrl: map['try_on_path']?.toString() ?? '',
          outfit: generatedOutfit,
          intent: intent,
          colors: intent.preferredColors,
          styleTags: intent.styleTags,
          occasion: intent.occasion,
          season: intent.season,
          weather: intent.weather,
          matchPercentage: (map['match_percentage'] as num? ?? 0).toInt(),
          compatibilityScore: (map['compatibility_score'] as num? ?? 0.0).toDouble(),
          userPrompt: gen['user_prompt']?.toString() ?? '',
          reasoning: intent.reasoning,
          createdAt: DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now(),
          lastViewedAt: map['last_viewed_at'] != null
              ? DateTime.tryParse(map['last_viewed_at'].toString())
              : null,
          viewCount: (map['view_count'] as num? ?? 0).toInt(),
          isFavorite: map['is_favorite'] == true,
          customTags: map['custom_tags'] != null
              ? List<String>.from(map['custom_tags'] as List)
              : [],
          notes: map['notes']?.toString(),
        );
      }).toList();

      var filtered = outfits;
      if (filterByOccasion != null) {
        filtered = filtered.where((o) => o.occasion == filterByOccasion).toList();
      }
      if (filterBySeason != null) {
        filtered = filtered.where((o) => o.season == filterBySeason).toList();
      }
      filtered = _applyClientFilters(
        filtered,
        filterByColors: filterByColors,
        filterByStyleTags: filterByStyleTags,
      );

      debugPrint('✅ [SavedOutfitsRepository -> Supabase] Loaded ${filtered.length} saved outfits');
      return filtered;
    } catch (e) {
      debugPrint('❌ [SavedOutfitsRepository -> Supabase] Error loading outfits: $e');
      return [];
    }
  }

  Future<SavedOutfit?> getOutfitById(String outfitId) async {
    final userId = _getCurrentUserId();
    if (userId == null) return null;

    try {
      final res = await _supabase
          .from('outfits')
          .select('''
            id,
            generation_id,
            user_id,
            rank,
            match_percentage,
            compatibility_score,
            explanation,
            explanation_es,
            try_on_path,
            is_favorite,
            custom_tags,
            notes,
            view_count,
            created_at,
            last_viewed_at,
            outfit_generations (
              user_prompt,
              intent
            ),
            outfit_items (
              role,
              wardrobe_item_id
            )
          ''')
          .eq('id', outfitId)
          .maybeSingle();

      if (res == null) return null;

      final map = Map<String, dynamic>.from(res);
      final gen = map['outfit_generations'] is Map
          ? Map<String, dynamic>.from(map['outfit_generations'] as Map)
          : <String, dynamic>{};
      final intentMap = gen['intent'] is Map
          ? Map<String, dynamic>.from(gen['intent'] as Map)
          : <String, dynamic>{};
      final intent = OutfitIntent.fromJson(intentMap);

      final items = (map['outfit_items'] as List? ?? []);
      String? topId;
      String? bottomId;
      String? shoesId;
      String? outerwearId;

      for (final item in items) {
        final role = item['role'];
        final itemId = item['wardrobe_item_id']?.toString();
        if (role == 'top') topId = itemId;
        if (role == 'bottom') bottomId = itemId;
        if (role == 'shoes') shoesId = itemId;
        if (role == 'outerwear') outerwearId = itemId;
      }

      final generatedOutfit = GeneratedOutfit(
        id: map['id'].toString(),
        topId: topId,
        bottomId: bottomId,
        shoesId: shoesId,
        outerwearId: outerwearId,
        matchPercentage: (map['match_percentage'] as num? ?? 0).toInt(),
        explanation: map['explanation']?.toString() ?? '',
        explanationEs: map['explanation_es']?.toString() ?? '',
        compatibilityScore: (map['compatibility_score'] as num? ?? 0.0).toDouble(),
      );

      return SavedOutfit(
        id: map['id'].toString(),
        userId: map['user_id'].toString(),
        tryOnImageUrl: map['try_on_path']?.toString() ?? '',
        outfit: generatedOutfit,
        intent: intent,
        colors: intent.preferredColors,
        styleTags: intent.styleTags,
        occasion: intent.occasion,
        season: intent.season,
        weather: intent.weather,
        matchPercentage: (map['match_percentage'] as num? ?? 0).toInt(),
        compatibilityScore: (map['compatibility_score'] as num? ?? 0.0).toDouble(),
        userPrompt: gen['user_prompt']?.toString() ?? '',
        reasoning: intent.reasoning,
        createdAt: DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now(),
        lastViewedAt: map['last_viewed_at'] != null
            ? DateTime.tryParse(map['last_viewed_at'].toString())
            : null,
        viewCount: (map['view_count'] as num? ?? 0).toInt(),
        isFavorite: map['is_favorite'] == true,
        customTags: map['custom_tags'] != null
            ? List<String>.from(map['custom_tags'] as List)
            : [],
        notes: map['notes']?.toString(),
      );
    } catch (e) {
      debugPrint('❌ [SavedOutfitsRepository -> Supabase] Error getting outfit: $e');
      return null;
    }
  }

  Future<void> updateTryOnImageUrl(String outfitId, String tryOnImageUrl) async {
    try {
      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      if (!uuidRegex.hasMatch(outfitId.trim())) {
        debugPrint(
          '⚠️ [SavedOutfitsRepository] updateTryOnImageUrl skipped: "$outfitId" is not a valid UUID (prevents 22P02)',
        );
        return;
      }
      await _supabase
          .from('outfits')
          .update({'try_on_path': tryOnImageUrl})
          .eq('id', outfitId.trim());
      debugPrint('✅ [SavedOutfitsRepository -> Supabase] Try-on URL updated for $outfitId');
    } catch (e) {
      debugPrint('❌ [SavedOutfitsRepository -> Supabase] Error updating try-on URL: $e');
    }
  }

  Future<void> updateOutfit(SavedOutfit outfit) async {
    try {
      await _supabase.from('outfits').update({
        'is_favorite': outfit.isFavorite,
        'custom_tags': outfit.customTags,
        'notes': outfit.notes,
        'try_on_path': outfit.tryOnImageUrl,
      }).eq('id', outfit.id);
      debugPrint('✅ [SavedOutfitsRepository -> Supabase] Outfit updated');
    } catch (e) {
      debugPrint('❌ [SavedOutfitsRepository -> Supabase] Error updating outfit: $e');
      throw Exception('Failed to update outfit: $e');
    }
  }

  Future<void> toggleFavorite(String outfitId, bool isFavorite) async {
    try {
      await _supabase
          .from('outfits')
          .update({'is_favorite': isFavorite})
          .eq('id', outfitId);
      debugPrint('✅ [SavedOutfitsRepository -> Supabase] Favorite toggled');
    } catch (e) {
      debugPrint('❌ [SavedOutfitsRepository -> Supabase] Error toggling favorite: $e');
      throw Exception('Failed to toggle favorite: $e');
    }
  }

  Future<void> incrementViewCount(String outfitId) async {
    try {
      final res = await _supabase
          .from('outfits')
          .select('view_count')
          .eq('id', outfitId)
          .maybeSingle();
      final current = (res?['view_count'] as num? ?? 0).toInt();
      await _supabase.from('outfits').update({
        'view_count': current + 1,
        'last_viewed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', outfitId);
    } catch (e) {
      debugPrint('⚠️ [SavedOutfitsRepository -> Supabase] Error incrementing view count: $e');
    }
  }

  Future<void> addCustomTags(String outfitId, List<String> tags) async {
    try {
      final res = await _supabase
          .from('outfits')
          .select('custom_tags')
          .eq('id', outfitId)
          .maybeSingle();
      final existing = (res?['custom_tags'] as List? ?? [])
          .map((e) => e.toString())
          .toSet();
      existing.addAll(tags);
      await _supabase
          .from('outfits')
          .update({'custom_tags': existing.toList()})
          .eq('id', outfitId);
    } catch (e) {
      debugPrint('❌ [SavedOutfitsRepository -> Supabase] Error adding custom tags: $e');
      throw Exception('Failed to add custom tags: $e');
    }
  }

  Future<void> updateNotes(String outfitId, String? notes) async {
    try {
      await _supabase
          .from('outfits')
          .update({'notes': notes})
          .eq('id', outfitId);
    } catch (e) {
      debugPrint('❌ [SavedOutfitsRepository -> Supabase] Error updating notes: $e');
      throw Exception('Failed to update notes: $e');
    }
  }

  Future<void> deleteOutfit(String outfitId) async {
    try {
      await _supabase.from('outfits').delete().eq('id', outfitId);
      debugPrint('✅ [SavedOutfitsRepository -> Supabase] Outfit deleted: $outfitId');
    } catch (e) {
      debugPrint('❌ [SavedOutfitsRepository -> Supabase] Error deleting outfit: $e');
      throw Exception('Failed to delete outfit: $e');
    }
  }

  List<SavedOutfit> _applyClientFilters(
    List<SavedOutfit> outfits, {
    List<String>? filterByColors,
    List<String>? filterByStyleTags,
  }) {
    var result = outfits;

    if (filterByColors != null && filterByColors.isNotEmpty) {
      result = result.where((outfit) {
        final outfitColors = outfit.colors.map((c) => c.toLowerCase()).toSet();
        final searchColors = filterByColors.map((c) => c.toLowerCase()).toSet();
        return outfitColors.intersection(searchColors).isNotEmpty;
      }).toList();
    }

    if (filterByStyleTags != null && filterByStyleTags.isNotEmpty) {
      result = result.where((outfit) {
        final outfitTags = outfit.styleTags.map((t) => t.toLowerCase()).toSet();
        final searchTags = filterByStyleTags.map((t) => t.toLowerCase()).toSet();
        return outfitTags.intersection(searchTags).isNotEmpty;
      }).toList();
    }

    return result;
  }
}
