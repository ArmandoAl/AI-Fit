import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/services/deepseek_service.dart';
import '../../../core/utils/ai_telemetry_logger.dart';
import '../../wardrobe/domain/wardrobe_item_model.dart';
import '../domain/outfit_models.dart';
import 'wardrobe_search_algorithm.dart';

/// Genera outfits razonando sobre metadatos estructurados de texto vía DeepSeek (`ai-router`).
///
/// Fase 3: Selección y composición inteligente sin transferir bytes de imágenes,
/// logrando alta velocidad, cero consumo de ancho de banda y consistencia de IDs.
class OutfitGeneratorService {
  final DeepSeekService _gateway;

  OutfitGeneratorService({DeepSeekService? gateway})
    : _gateway = gateway ?? const DeepSeekService();

  /// Genera 3 propuestas de outfits balanceando tops, bottoms, shoes y outerwear.
  Future<List<GeneratedOutfit>> generateOutfits({
    required FilteredWardrobe filteredWardrobe,
    required OutfitIntent intent,
    String? idempotencyKey,
  }) async {
    final stopwatch = Stopwatch()..start();

    if (filteredWardrobe.isEmpty) {
      throw Exception('No items available to generate outfits');
    }

    // 1. Selección balanceada de candidatos (hasta 4 tops, 4 bottoms, 4 shoes, 3 outerwear, 3 one_pieces, 4 accessories)
    final candidateTops = filteredWardrobe.tops.take(4).toList();
    final candidateBottoms = filteredWardrobe.bottoms.take(4).toList();
    final candidateShoes = filteredWardrobe.shoes.take(4).toList();
    final candidateOuterwear = filteredWardrobe.outerwear.take(3).toList();
    final candidateOnePieces = filteredWardrobe.onePieces.take(3).toList();
    final candidateAccessories = filteredWardrobe.accessories.take(4).toList();

    final allCandidates = [
      ...candidateTops,
      ...candidateBottoms,
      ...candidateShoes,
      ...candidateOuterwear,
      ...candidateOnePieces,
      ...candidateAccessories,
    ];

    final structuredCandidates = allCandidates
        .map(_mapItemToCandidate)
        .toList();

    debugPrint(
      '🎨 Composing outfits via DeepSeek with ${allCandidates.length} structured candidates '
      '(${candidateTops.length} tops, ${candidateBottoms.length} bottoms, ${candidateShoes.length} shoes, '
      '${candidateOuterwear.length} outerwear, ${candidateOnePieces.length} one_pieces, ${candidateAccessories.length} accessories)',
    );

    try {
      // 2. Invocación al Gateway Server-Side ai-router
      final rawOutfits = await _gateway.composeOutfits(
        intent: intent.toJson(),
        candidates: structuredCandidates,
        idempotencyKey: idempotencyKey,
      );

      final parsedOutfits = _parseOutfits(rawOutfits);
      final requiredColors = intent.requiredColorsByCategory.isNotEmpty;
      final candidateItemsById = {
        for (final item in allCandidates) item.id: item,
      };
      final outfits = requiredColors
          ? parsedOutfits
                .where(
                  (outfit) =>
                      WardrobeSearchAlgorithm.outfitSatisfiesRequiredColors(
                        outfit,
                        candidateItemsById,
                        intent,
                      ),
                )
                .toList()
          : parsedOutfits;
      if (requiredColors && outfits.isEmpty) {
        throw StateError(
          'Composer returned no outfit that satisfies required colors',
        );
      }

      stopwatch.stop();

      AiTelemetryLogger.logEvent(
        operation: 'generate_outfits',
        model: 'deepseek-chat',
        inputCount: allCandidates.length,
        inputBytesTotal: jsonEncode(structuredCandidates).length,
        latencyMs: stopwatch.elapsedMilliseconds,
        status: 'success',
      );

      debugPrint(
        '✅ DeepSeek gateway generated ${outfits.length} valid outfits',
      );
      return outfits;
    } catch (e) {
      stopwatch.stop();
      debugPrint(
        '⚠️ DeepSeek outfit composition failed ($e). Falling back to rule-based composer...',
      );

      AiTelemetryLogger.logEvent(
        operation: 'generate_outfits',
        model: 'deepseek-chat',
        inputCount: allCandidates.length,
        inputBytesTotal: jsonEncode(structuredCandidates).length,
        latencyMs: stopwatch.elapsedMilliseconds,
        status: 'failed',
        errorCode: e.runtimeType.toString(),
      );

      // 3. Fallback determinista local basado en reglas de compatibilidad
      final fallbackOutfits = WardrobeSearchAlgorithm.generateRuleBasedOutfits(
        wardrobe: filteredWardrobe,
        intent: intent,
      );

      if (fallbackOutfits.isNotEmpty) {
        debugPrint(
          '🛡️ Rule-based fallback created ${fallbackOutfits.length} outfits successfully',
        );
        return fallbackOutfits;
      }

      throw Exception('Failed to generate outfits: $e');
    }
  }

  static Map<String, dynamic> _mapItemToCandidate(WardrobeItem item) {
    return {
      'id': item.id,
      'name': item.name,
      'category': item.type,
      'subtype': item.subType,
      'colors': item.colors,
      'styleTags': item.styleTags,
      'seasons': item.season,
      if (item.aiMetadata?.styleScores?['formality'] != null)
        'formalityScore': item.aiMetadata!.styleScores!['formality'],
      if (item.aiMetadata?.climateCompatibility != null)
        'weatherCompatibility': item.aiMetadata!.climateCompatibility,
    };
  }

  List<GeneratedOutfit> _parseOutfits(List<Map<String, dynamic>> rawList) {
    return rawList.map((map) {
      List<String> accessoryIds = [];
      if (map['accessoryIds'] is List) {
        accessoryIds = (map['accessoryIds'] as List)
            .map((e) => e?.toString().trim())
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .toList();
      } else if (map['accessory_ids'] is List) {
        accessoryIds = (map['accessory_ids'] as List)
            .map((e) => e?.toString().trim())
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .toList();
      }

      return GeneratedOutfit(
        id: GeneratedOutfit.ensureUuid(map['id']?.toString()),
        topId: map['topId']?.toString() ?? map['top_id']?.toString(),
        bottomId: map['bottomId']?.toString() ?? map['bottom_id']?.toString(),
        shoesId: map['shoesId']?.toString() ?? map['shoes_id']?.toString(),
        outerwearId:
            map['outerwearId']?.toString() ?? map['outerwear_id']?.toString(),
        onePieceId:
            map['onePieceId']?.toString() ?? map['one_piece_id']?.toString(),
        accessoryIds: accessoryIds,
        matchPercentage: (map['matchPercentage'] as num?)?.toInt() ?? 90,
        compatibilityScore:
            (map['compatibilityScore'] as num?)?.toDouble() ?? 0.88,
        explanation:
            map['explanation']?.toString() ??
            'Harmonious look curated for you.',
        explanationEs:
            map['explanationEs']?.toString() ??
            map['explanation_es']?.toString() ??
            'Look armónico y equilibrado seleccionado especialmente para ti.',
        metadata: map['metadata'] as Map<String, dynamic>?,
      );
    }).toList();
  }
}
