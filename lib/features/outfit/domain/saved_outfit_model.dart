/// Modelo de datos para outfits guardados
library;

import 'outfit_models.dart';

/// Outfit guardado con metadata y etiquetas para organización
class SavedOutfit {
  final String id; // ID único del outfit
  final String userId; // ID del usuario
  final String tryOnImageUrl; // URL de la imagen generada
  final GeneratedOutfit outfit; // Datos del outfit (IDs de prendas)
  final OutfitIntent intent; // Intent original (para contexto)

  // ETIQUETAS Y METADATA (extraídas del intent)
  final List<String> colors; // Colores principales del outfit
  final List<String> styleTags; // Estilos (casual, formal, etc.)
  final String? occasion; // Ocasión (casual, formal, etc.)
  final String? season; // Temporada
  final String? weather; // Clima

  // METADATA ADICIONAL
  final int matchPercentage; // Porcentaje de match
  final double compatibilityScore; // Score de compatibilidad
  final String userPrompt; // Prompt original del usuario
  final String? reasoning; // Razonamiento de la IA

  // FECHAS Y USO
  final DateTime createdAt;
  final DateTime? lastViewedAt;
  final int viewCount; // Cuántas veces se ha visto

  // FAVORITOS Y ORGANIZACIÓN
  final bool isFavorite;
  final List<String> customTags; // Tags personalizados del usuario
  final String? notes; // Notas del usuario sobre el outfit

  SavedOutfit({
    required this.id,
    required this.userId,
    required this.tryOnImageUrl,
    required this.outfit,
    required this.intent,
    required this.colors,
    required this.styleTags,
    this.occasion,
    this.season,
    this.weather,
    required this.matchPercentage,
    required this.compatibilityScore,
    required this.userPrompt,
    this.reasoning,
    required this.createdAt,
    this.lastViewedAt,
    this.viewCount = 0,
    this.isFavorite = false,
    this.customTags = const [],
    this.notes,
  });

  /// Try-on guardado solo en Storage (antes de DB o si falló el guardado).
  factory SavedOutfit.fromStorageTryOn({
    required String userId,
    required String tryOnImageUrl,
    required String storageFileName,
    required DateTime createdAt,
  }) {
    final storageId = storageFileName.replaceAll('.jpg', '');
    final emptyOutfit = GeneratedOutfit(
      id: storageId,
      matchPercentage: 0,
      explanation: 'Saved try-on look',
      explanationEs: 'Look guardado con try-on',
      compatibilityScore: 0,
    );
    return SavedOutfit(
      id: 'storage_$storageId',
      userId: userId,
      tryOnImageUrl: tryOnImageUrl,
      outfit: emptyOutfit,
      intent: OutfitIntent(userPrompt: ''),
      colors: const [],
      styleTags: const [],
      matchPercentage: 0,
      compatibilityScore: 0,
      userPrompt: '',
      createdAt: createdAt,
    );
  }

  /// Crea un SavedOutfit desde un GeneratedOutfit e Intent
  factory SavedOutfit.fromGeneratedOutfit({
    required GeneratedOutfit outfit,
    required OutfitIntent intent,
    required String userId,
    required String tryOnImageUrl,
  }) {
    return SavedOutfit(
      id: outfit.id,
      userId: userId,
      tryOnImageUrl: tryOnImageUrl,
      outfit: outfit,
      intent: intent,
      colors: intent.preferredColors.isNotEmpty
          ? intent.preferredColors
          : _extractColorsFromOutfit(outfit),
      styleTags: intent.styleTags,
      occasion: intent.occasion,
      season: intent.season,
      weather: intent.weather,
      matchPercentage: outfit.matchPercentage,
      compatibilityScore: outfit.compatibilityScore,
      userPrompt: intent.userPrompt ?? '',
      reasoning: intent.reasoning,
      createdAt: DateTime.now(),
    );
  }

  /// Extrae colores del outfit si no hay preferredColors
  static List<String> _extractColorsFromOutfit(GeneratedOutfit outfit) {
    return [];
  }

  /// Crea desde JSON
  factory SavedOutfit.fromJson(Map<String, dynamic> json) {
    return SavedOutfit(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      tryOnImageUrl: json['tryOnImageUrl'] ?? '',
      outfit: GeneratedOutfit.fromJson(
        json['outfit'] as Map<String, dynamic>,
      ),
      intent: OutfitIntent.fromJson(
        json['intent'] as Map<String, dynamic>,
      ),
      colors: json['colors'] != null
          ? List<String>.from(json['colors'])
          : [],
      styleTags: json['styleTags'] != null
          ? List<String>.from(json['styleTags'])
          : [],
      occasion: json['occasion'],
      season: json['season'],
      weather: json['weather'],
      matchPercentage: json['matchPercentage'] ?? 0,
      compatibilityScore: (json['compatibilityScore'] ?? 0.0).toDouble(),
      userPrompt: json['userPrompt'] ?? '',
      reasoning: json['reasoning'],
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is DateTime
              ? json['createdAt'] as DateTime
              : (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()))
          : DateTime.now(),
      lastViewedAt: json['lastViewedAt'] != null
          ? (json['lastViewedAt'] is DateTime
              ? json['lastViewedAt'] as DateTime
              : DateTime.tryParse(json['lastViewedAt'].toString()))
          : null,
      viewCount: json['viewCount'] ?? 0,
      isFavorite: json['isFavorite'] ?? false,
      customTags: json['customTags'] != null
          ? List<String>.from(json['customTags'])
          : [],
      notes: json['notes'],
    );
  }

  /// Convierte a JSON estándar
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'tryOnImageUrl': tryOnImageUrl,
      'outfit': outfit.toJson(),
      'intent': intent.toJson(),
      'colors': colors,
      'styleTags': styleTags,
      if (occasion != null) 'occasion': occasion,
      if (season != null) 'season': season,
      if (weather != null) 'weather': weather,
      'matchPercentage': matchPercentage,
      'compatibilityScore': compatibilityScore,
      'userPrompt': userPrompt,
      if (reasoning != null) 'reasoning': reasoning,
      'createdAt': createdAt.toIso8601String(),
      if (lastViewedAt != null)
        'lastViewedAt': lastViewedAt!.toIso8601String(),
      'viewCount': viewCount,
      'isFavorite': isFavorite,
      'customTags': customTags,
      if (notes != null) 'notes': notes,
    };
  }

  /// Crea una copia con campos actualizados
  SavedOutfit copyWith({
    String? id,
    String? userId,
    String? tryOnImageUrl,
    GeneratedOutfit? outfit,
    OutfitIntent? intent,
    List<String>? colors,
    List<String>? styleTags,
    String? occasion,
    String? season,
    String? weather,
    int? matchPercentage,
    double? compatibilityScore,
    String? userPrompt,
    String? reasoning,
    DateTime? createdAt,
    DateTime? lastViewedAt,
    int? viewCount,
    bool? isFavorite,
    List<String>? customTags,
    String? notes,
  }) {
    return SavedOutfit(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tryOnImageUrl: tryOnImageUrl ?? this.tryOnImageUrl,
      outfit: outfit ?? this.outfit,
      intent: intent ?? this.intent,
      colors: colors ?? this.colors,
      styleTags: styleTags ?? this.styleTags,
      occasion: occasion ?? this.occasion,
      season: season ?? this.season,
      weather: weather ?? this.weather,
      matchPercentage: matchPercentage ?? this.matchPercentage,
      compatibilityScore: compatibilityScore ?? this.compatibilityScore,
      userPrompt: userPrompt ?? this.userPrompt,
      reasoning: reasoning ?? this.reasoning,
      createdAt: createdAt ?? this.createdAt,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      viewCount: viewCount ?? this.viewCount,
      isFavorite: isFavorite ?? this.isFavorite,
      customTags: customTags ?? this.customTags,
      notes: notes ?? this.notes,
    );
  }
}
