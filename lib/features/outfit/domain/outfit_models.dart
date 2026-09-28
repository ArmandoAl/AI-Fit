/// Modelos de datos para el sistema de generación de outfits
library;

import 'package:aifit/paths.dart';
import 'package:uuid/uuid.dart';
import '../../profile/domain/user_identity_profile.dart';
import '../../wardrobe/domain/wardrobe_palette.dart';
import 'outfit_semantic_targets.dart';

const defaultTryOnProvider = 'seedream';
const tryOnProvidersByPosition = [
  defaultTryOnProvider,
  defaultTryOnProvider,
  defaultTryOnProvider,
];

// Keep the positional API for existing flows; provider choice is not position-based.
String tryOnProviderForPosition(int _) => defaultTryOnProvider;

class OutfitIntent {
  final String?
  reasoning; // Explicación del razonamiento de la IA (Chain of Thought)
  final String? occasion; // 'casual', 'formal', 'sport', 'party', 'work', etc.
  final List<String> preferredColors;

  /// Hard color requirements by garment category; `*` applies to every visible item.
  final Map<String, List<String>> requiredColorsByCategory;
  final List<String> styleTags; // ['casual', 'formal', 'minimalist', etc.]
  final String? season; // 'spring', 'summer', 'fall', 'winter'
  final String? weather; // 'sunny', 'rainy', 'cold', 'warm'
  final Map<String, dynamic>? constraints; // Restricciones adicionales
  final String? userPrompt; // Prompt original del usuario
  final OutfitSemanticTargets semanticTargets;

  OutfitIntent({
    this.reasoning,
    this.occasion,
    this.preferredColors = const [],
    this.requiredColorsByCategory = const {},
    this.styleTags = const [],
    this.season,
    this.weather,
    this.constraints,
    this.userPrompt,
    OutfitSemanticTargets? semanticTargets,
  }) : semanticTargets = semanticTargets ?? const OutfitSemanticTargets();

  factory OutfitIntent.fromJson(Map<String, dynamic> json) {
    final rawColors = json['preferredColors'] != null
        ? List<String>.from(json['preferredColors'])
        : <String>[];
    final rawTags = json['styleTags'] != null
        ? List<String>.from(json['styleTags'])
        : <String>[];
    final rawRequiredColors = json['requiredColorsByCategory'];
    final requiredColors = <String, List<String>>{};
    if (rawRequiredColors is Map) {
      for (final entry in rawRequiredColors.entries) {
        if (entry.value is List) {
          requiredColors[entry.key.toString()] = List<String>.from(entry.value);
        }
      }
    }
    return OutfitIntent(
      reasoning: json['reasoning']?.toString(),
      occasion: WardrobePalette.normalizeOccasion(json['occasion']?.toString()),
      preferredColors: WardrobePalette.normalizeColors(rawColors),
      requiredColorsByCategory: requiredColors,
      styleTags: WardrobePalette.normalizeStyleTags(rawTags),
      season: json['season'] != null
          ? WardrobePalette.normalizeSeason(json['season'].toString())
          : null,
      weather: WardrobePalette.normalizeWeather(json['weather']?.toString()),
      constraints: json['constraints'] as Map<String, dynamic>?,
      userPrompt: json['userPrompt']?.toString(),
      semanticTargets: OutfitSemanticTargets.fromJson(
        json['semanticTargets'] as Map<String, dynamic>?,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (reasoning != null) 'reasoning': reasoning,
      if (occasion != null) 'occasion': occasion,
      'preferredColors': preferredColors,
      if (requiredColorsByCategory.isNotEmpty)
        'requiredColorsByCategory': requiredColorsByCategory,
      'styleTags': styleTags,
      if (season != null) 'season': season,
      if (weather != null) 'weather': weather,
      if (constraints != null) 'constraints': constraints,
      if (userPrompt != null) 'userPrompt': userPrompt,
      if (!semanticTargets.isEmpty) 'semanticTargets': semanticTargets.toJson(),
    };
  }
}

class FilteredWardrobe {
  final List<WardrobeItem> tops;
  final List<WardrobeItem> bottoms;
  final List<WardrobeItem> shoes;
  final List<WardrobeItem> outerwear;
  final List<WardrobeItem> onePieces;
  final List<WardrobeItem> accessories;

  FilteredWardrobe({
    required this.tops,
    required this.bottoms,
    required this.shoes,
    required this.outerwear,
    this.onePieces = const [],
    this.accessories = const [],
  });

  int get totalItems =>
      tops.length +
      bottoms.length +
      shoes.length +
      outerwear.length +
      onePieces.length +
      accessories.length;

  bool get isEmpty =>
      tops.isEmpty &&
      bottoms.isEmpty &&
      shoes.isEmpty &&
      outerwear.isEmpty &&
      onePieces.isEmpty &&
      accessories.isEmpty;
}

class GeneratedOutfit {
  final String id;
  final String? topId;
  final String? bottomId;
  final String? shoesId;
  final String? outerwearId; // Optional
  final String? onePieceId; // Optional (reemplaza par top + bottom)
  final List<String> accessoryIds; // Optional (0 a 2 accesorios)
  final int matchPercentage; // 0-100
  /// Inglés — archivo, debug, reutilización con IA.
  final String explanation;

  /// Español — texto que ve el usuario.
  final String explanationEs;
  final double compatibilityScore; // 0.0-1.0
  final Map<String, dynamic>? metadata; // Additional data

  GeneratedOutfit({
    required this.id,
    this.topId,
    this.bottomId,
    this.shoesId,
    this.outerwearId,
    this.onePieceId,
    this.accessoryIds = const [],
    required this.matchPercentage,
    required this.explanation,
    this.explanationEs = '',
    required this.compatibilityScore,
    this.metadata,
  });

  /// Texto para UI: prioriza español; si falta, inglés (outfits viejos).
  String get displayExplanation {
    final es = explanationEs.trim();
    if (es.isNotEmpty) return es;
    return explanation.trim();
  }

  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static String ensureUuid(String? id) {
    if (id != null) {
      final clean = id.trim();
      if (_uuidRegex.hasMatch(clean)) {
        return clean;
      }
    }
    return const Uuid().v4();
  }

  GeneratedOutfit copyWith({
    String? id,
    String? topId,
    String? bottomId,
    String? shoesId,
    String? outerwearId,
    String? onePieceId,
    List<String>? accessoryIds,
    int? matchPercentage,
    String? explanation,
    String? explanationEs,
    double? compatibilityScore,
    Map<String, dynamic>? metadata,
  }) {
    return GeneratedOutfit(
      id: id ?? this.id,
      topId: topId ?? this.topId,
      bottomId: bottomId ?? this.bottomId,
      shoesId: shoesId ?? this.shoesId,
      outerwearId: outerwearId ?? this.outerwearId,
      onePieceId: onePieceId ?? this.onePieceId,
      accessoryIds: accessoryIds ?? this.accessoryIds,
      matchPercentage: matchPercentage ?? this.matchPercentage,
      explanation: explanation ?? this.explanation,
      explanationEs: explanationEs ?? this.explanationEs,
      compatibilityScore: compatibilityScore ?? this.compatibilityScore,
      metadata: metadata ?? this.metadata,
    );
  }

  factory GeneratedOutfit.fromJson(Map<String, dynamic> json) {
    String? pickId(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    // Gemini occasionally returns snake_case or alternate keys.
    final topId =
        pickId(json['topId']) ??
        pickId(json['top_id']) ??
        pickId(json['top']) ??
        pickId(json['topItemId']);
    final bottomId =
        pickId(json['bottomId']) ??
        pickId(json['bottom_id']) ??
        pickId(json['bottom']) ??
        pickId(json['bottomItemId']);
    final shoesId =
        pickId(json['shoesId']) ??
        pickId(json['shoes_id']) ??
        pickId(json['shoes']) ??
        pickId(json['shoe_id']) ??
        pickId(json['shoesItemId']);
    final outerwearId =
        pickId(json['outerwearId']) ??
        pickId(json['outerwear_id']) ??
        pickId(json['outerwear']);
    final onePieceId =
        pickId(json['onePieceId']) ??
        pickId(json['one_piece_id']) ??
        pickId(json['onePiece']) ??
        pickId(json['one_piece']) ??
        pickId(json['dressId']) ??
        pickId(json['dress']);

    List<String> accessoryIds = [];
    if (json['accessoryIds'] is List) {
      accessoryIds = (json['accessoryIds'] as List)
          .map((e) => pickId(e))
          .whereType<String>()
          .toList();
    } else if (json['accessory_ids'] is List) {
      accessoryIds = (json['accessory_ids'] as List)
          .map((e) => pickId(e))
          .whereType<String>()
          .toList();
    } else if (json['accessories'] is List) {
      accessoryIds = (json['accessories'] as List)
          .map((e) => pickId(e))
          .whereType<String>()
          .toList();
    } else {
      final singleAcc =
          pickId(json['accessoryId']) ??
          pickId(json['accessory_id']) ??
          pickId(json['accessory']);
      if (singleAcc != null) accessoryIds.add(singleAcc);
    }

    final rawId = json['id']?.toString() ?? json['outfitId']?.toString();

    return GeneratedOutfit(
      id: ensureUuid(rawId),
      topId: topId,
      bottomId: bottomId,
      shoesId: shoesId,
      outerwearId: outerwearId,
      onePieceId: onePieceId,
      accessoryIds: accessoryIds,
      matchPercentage: json['matchPercentage'] is num
          ? (json['matchPercentage'] as num).round()
          : int.tryParse(
                  json['matchPercentage']?.toString() ??
                      json['match_percentage']?.toString() ??
                      '',
                ) ??
                0,
      explanation:
          json['explanation']?.toString() ?? json['text']?.toString() ?? '',
      explanationEs:
          json['explanationEs']?.toString() ??
          json['explanation_es']?.toString() ??
          '',
      compatibilityScore: _parseCompat(
        json['compatibilityScore'] ?? json['compatibility_score'],
      ),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  static double _parseCompat(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  /// Look completo: Requiere calzado + (pieza única O par superior e inferior)
  bool get hasCompleteLook {
    final hasShoes = shoesId != null && shoesId!.isNotEmpty;
    final hasOnePiece = onePieceId != null && onePieceId!.isNotEmpty;
    final hasTopAndBottom =
        (topId != null && topId!.isNotEmpty) &&
        (bottomId != null && bottomId!.isNotEmpty);
    return hasShoes && (hasOnePiece || hasTopAndBottom);
  }

  /// For debug / user-visible errors when [hasCompleteLook] is false.
  String get missingFieldsSummary {
    final miss = <String>[];
    final hasOnePiece = onePieceId != null && onePieceId!.isNotEmpty;
    if (!hasOnePiece) {
      if (topId == null || topId!.isEmpty) miss.add('top');
      if (bottomId == null || bottomId!.isEmpty) miss.add('bottom');
    }
    if (shoesId == null || shoesId!.isEmpty) miss.add('shoes');
    return miss.join(', ');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (onePieceId != null) 'onePieceId': onePieceId,
      if (topId != null) 'topId': topId,
      if (bottomId != null) 'bottomId': bottomId,
      if (shoesId != null) 'shoesId': shoesId,
      if (outerwearId != null) 'outerwearId': outerwearId,
      if (accessoryIds.isNotEmpty) 'accessoryIds': accessoryIds,
      'matchPercentage': matchPercentage,
      'explanation': explanation,
      if (explanationEs.isNotEmpty) 'explanationEs': explanationEs,
      'compatibilityScore': compatibilityScore,
      if (metadata != null) 'metadata': metadata,
    };
  }

  List<String> get itemIds {
    final ids = <String>[];
    if (onePieceId != null && onePieceId!.isNotEmpty) ids.add(onePieceId!);
    if (topId != null && topId!.isNotEmpty) ids.add(topId!);
    if (bottomId != null && bottomId!.isNotEmpty) ids.add(bottomId!);
    if (shoesId != null && shoesId!.isNotEmpty) ids.add(shoesId!);
    if (outerwearId != null && outerwearId!.isNotEmpty) ids.add(outerwearId!);
    for (final accId in accessoryIds) {
      if (accId.isNotEmpty && !ids.contains(accId)) ids.add(accId);
    }
    return ids;
  }
}

class VirtualTryOnRequest {
  final GeneratedOutfit outfit;
  final IdentityProfile? identityProfile;
  final String? scenePrompt;

  VirtualTryOnRequest({
    required this.outfit,
    this.identityProfile,
    this.scenePrompt,
  });
}

class VirtualTryOnResult {
  final String outfitId;
  final String generatedImageUrl; // URL de la imagen generada
  final DateTime generatedAt;
  final Map<String, dynamic>? metadata;

  VirtualTryOnResult({
    required this.outfitId,
    required this.generatedImageUrl,
    required this.generatedAt,
    this.metadata,
  });

  factory VirtualTryOnResult.fromJson(Map<String, dynamic> json) {
    return VirtualTryOnResult(
      outfitId: json['outfitId'],
      generatedImageUrl: json['generatedImageUrl'] ?? json['imageUrl'],
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'])
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'outfitId': outfitId,
      'generatedImageUrl': generatedImageUrl,
      'generatedAt': generatedAt.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}
