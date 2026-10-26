import 'wardrobe_palette.dart';

/// Hidden AI-only semantic metadata for wardrobe items (schema v2).
/// All fields optional for backward compatibility with older Firestore docs.

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

Map<String, double>? _parseScoreMap(dynamic value) {
  if (value is! Map) return null;
  final result = <String, double>{};
  for (final entry in value.entries) {
    final score = _parseDouble(entry.value);
    if (score != null) result[entry.key.toString()] = score;
  }
  return result.isEmpty ? null : result;
}

List<String>? _parseStringList(dynamic value) {
  if (value is! List) return null;
  final list = value
      .map((e) => e.toString())
      .where((s) => s.isNotEmpty)
      .toList();
  return list.isEmpty ? null : list;
}

class WardrobeTexture {
  final String? primary;
  final List<String>? secondary;
  final String? surfaceFeel;
  final String? structure;

  const WardrobeTexture({
    this.primary,
    this.secondary,
    this.surfaceFeel,
    this.structure,
  });

  factory WardrobeTexture.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WardrobeTexture();
    return WardrobeTexture(
      primary: json['primary']?.toString(),
      secondary: _parseStringList(json['secondary']),
      surfaceFeel: json['surface_feel']?.toString(),
      structure: json['structure']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (primary != null) 'primary': primary,
      if (secondary != null && secondary!.isNotEmpty) 'secondary': secondary,
      if (surfaceFeel != null) 'surface_feel': surfaceFeel,
      if (structure != null) 'structure': structure,
    };
  }

  bool get isEmpty =>
      primary == null &&
      (secondary == null || secondary!.isEmpty) &&
      surfaceFeel == null &&
      structure == null;
}

class WardrobeSilhouette {
  final String? fit;
  final String? length;
  final String? shape;

  const WardrobeSilhouette({this.fit, this.length, this.shape});

  factory WardrobeSilhouette.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WardrobeSilhouette();
    return WardrobeSilhouette(
      fit: json['fit']?.toString(),
      length: json['length']?.toString(),
      shape: json['shape']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (fit != null) 'fit': fit,
      if (length != null) 'length': length,
      if (shape != null) 'shape': shape,
    };
  }

  bool get isEmpty => fit == null && length == null && shape == null;
}

class WardrobeFashionAesthetic {
  final String? primary;
  final List<String>? secondary;
  final double? confidence;

  const WardrobeFashionAesthetic({
    this.primary,
    this.secondary,
    this.confidence,
  });

  factory WardrobeFashionAesthetic.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WardrobeFashionAesthetic();
    return WardrobeFashionAesthetic(
      primary: json['primary']?.toString(),
      secondary: _parseStringList(json['secondary']),
      confidence: _parseDouble(json['confidence']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (primary != null) 'primary': primary,
      if (secondary != null && secondary!.isNotEmpty) 'secondary': secondary,
      if (confidence != null) 'confidence': confidence,
    };
  }

  bool get isEmpty =>
      primary == null &&
      (secondary == null || secondary!.isEmpty) &&
      confidence == null;
}

class WardrobeColorProfile {
  final String? temperature;
  final String? saturation;
  final String? contrast;

  const WardrobeColorProfile({
    this.temperature,
    this.saturation,
    this.contrast,
  });

  factory WardrobeColorProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WardrobeColorProfile();
    return WardrobeColorProfile(
      temperature: json['temperature']?.toString(),
      saturation: json['saturation']?.toString(),
      contrast: json['contrast']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (temperature != null) 'temperature': temperature,
      if (saturation != null) 'saturation': saturation,
      if (contrast != null) 'contrast': contrast,
    };
  }

  bool get isEmpty =>
      temperature == null && saturation == null && contrast == null;
}

class WardrobeGenderExpression {
  final String? primary;
  final double? confidence;

  const WardrobeGenderExpression({this.primary, this.confidence});

  factory WardrobeGenderExpression.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WardrobeGenderExpression();
    return WardrobeGenderExpression(
      primary: json['primary']?.toString(),
      confidence: _parseDouble(json['confidence']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (primary != null) 'primary': primary,
      if (confidence != null) 'confidence': confidence,
    };
  }

  bool get isEmpty => primary == null && confidence == null;
}

class WardrobeLayeringCompatibility {
  final List<String>? worksWith;
  final List<String>? avoidWith;

  const WardrobeLayeringCompatibility({this.worksWith, this.avoidWith});

  factory WardrobeLayeringCompatibility.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WardrobeLayeringCompatibility();
    return WardrobeLayeringCompatibility(
      worksWith: _parseStringList(json['works_with']),
      avoidWith: _parseStringList(json['avoid_with']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (worksWith != null && worksWith!.isNotEmpty) 'works_with': worksWith,
      if (avoidWith != null && avoidWith!.isNotEmpty) 'avoid_with': avoidWith,
    };
  }

  bool get isEmpty =>
      (worksWith == null || worksWith!.isEmpty) &&
      (avoidWith == null || avoidWith!.isEmpty);
}

class WardrobeAiMetadata {
  final int? aiSchemaVersion;
  final String? visualWeight;
  final WardrobeTexture? texture;
  final WardrobeSilhouette? silhouette;
  final WardrobeFashionAesthetic? fashionAesthetic;
  final WardrobeColorProfile? colorProfile;
  final Map<String, double>? styleScores;
  final WardrobeGenderExpression? genderExpression;
  final WardrobeLayeringCompatibility? layeringCompatibility;
  final Map<String, double>? occasionVectors;
  final Map<String, double>? climateCompatibility;
  final Map<String, double>? visualAttributes;

  const WardrobeAiMetadata({
    this.aiSchemaVersion,
    this.visualWeight,
    this.texture,
    this.silhouette,
    this.fashionAesthetic,
    this.colorProfile,
    this.styleScores,
    this.genderExpression,
    this.layeringCompatibility,
    this.occasionVectors,
    this.climateCompatibility,
    this.visualAttributes,
  });

  factory WardrobeAiMetadata.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const WardrobeAiMetadata();

    final texture = WardrobeTexture.fromJson(
      json['texture'] is Map<String, dynamic>
          ? json['texture'] as Map<String, dynamic>
          : null,
    );
    final silhouette = WardrobeSilhouette.fromJson(
      json['silhouette'] is Map<String, dynamic>
          ? json['silhouette'] as Map<String, dynamic>
          : null,
    );
    final fashionAesthetic = WardrobeFashionAesthetic.fromJson(
      json['fashion_aesthetic'] is Map<String, dynamic>
          ? json['fashion_aesthetic'] as Map<String, dynamic>
          : null,
    );
    final colorProfile = WardrobeColorProfile.fromJson(
      json['color_profile'] is Map<String, dynamic>
          ? json['color_profile'] as Map<String, dynamic>
          : null,
    );
    final genderExpression = WardrobeGenderExpression.fromJson(
      json['gender_expression'] is Map<String, dynamic>
          ? json['gender_expression'] as Map<String, dynamic>
          : null,
    );
    final layeringCompatibility = WardrobeLayeringCompatibility.fromJson(
      json['layering_compatibility'] is Map<String, dynamic>
          ? json['layering_compatibility'] as Map<String, dynamic>
          : null,
    );

    return WardrobeAiMetadata(
      aiSchemaVersion: json['ai_schema_version'] is int
          ? json['ai_schema_version'] as int
          : int.tryParse(json['ai_schema_version']?.toString() ?? ''),
      visualWeight: json['visual_weight']?.toString(),
      texture: texture.isEmpty ? null : texture,
      silhouette: silhouette.isEmpty ? null : silhouette,
      fashionAesthetic: fashionAesthetic.isEmpty ? null : fashionAesthetic,
      colorProfile: colorProfile.isEmpty ? null : colorProfile,
      styleScores: _parseScoreMap(json['style_scores']),
      genderExpression: genderExpression.isEmpty ? null : genderExpression,
      layeringCompatibility: layeringCompatibility.isEmpty
          ? null
          : layeringCompatibility,
      occasionVectors: _parseScoreMap(json['occasion_vectors']),
      climateCompatibility: _parseScoreMap(json['climate_compatibility']),
      visualAttributes: _parseScoreMap(json['visual_attributes']),
    );
  }

  /// Parses hidden metadata from a full AI wardrobe analysis response.
  factory WardrobeAiMetadata.fromAnalysisJson(Map<String, dynamic> json) {
    return WardrobeAiMetadata.fromJson(json);
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (aiSchemaVersion != null) map['ai_schema_version'] = aiSchemaVersion;
    if (visualWeight != null) map['visual_weight'] = visualWeight;
    if (texture != null && !texture!.isEmpty) {
      map['texture'] = texture!.toJson();
    }
    if (silhouette != null && !silhouette!.isEmpty) {
      map['silhouette'] = silhouette!.toJson();
    }
    if (fashionAesthetic != null && !fashionAesthetic!.isEmpty) {
      map['fashion_aesthetic'] = fashionAesthetic!.toJson();
    }
    if (colorProfile != null && !colorProfile!.isEmpty) {
      map['color_profile'] = colorProfile!.toJson();
    }
    if (styleScores != null && styleScores!.isNotEmpty) {
      map['style_scores'] = styleScores;
    }
    if (genderExpression != null && !genderExpression!.isEmpty) {
      map['gender_expression'] = genderExpression!.toJson();
    }
    if (layeringCompatibility != null && !layeringCompatibility!.isEmpty) {
      map['layering_compatibility'] = layeringCompatibility!.toJson();
    }
    if (occasionVectors != null && occasionVectors!.isNotEmpty) {
      map['occasion_vectors'] = occasionVectors;
    }
    if (climateCompatibility != null && climateCompatibility!.isNotEmpty) {
      map['climate_compatibility'] = climateCompatibility;
    }
    if (visualAttributes != null && visualAttributes!.isNotEmpty) {
      map['visual_attributes'] = visualAttributes;
    }
    return map;
  }

  bool get isEmpty => toJson().isEmpty;
}

/// Merges visible + hidden fields from AI JSON into a Firestore-ready map.
Map<String, dynamic> wardrobeFieldsFromAiJson(Map<String, dynamic> aiData) {
  final metadata = WardrobeAiMetadata.fromAnalysisJson(aiData);
  return {
    'name': aiData['subType'] ?? 'Unknown',
    'type': aiData['type'] ?? 'unknown',
    'subType': aiData['subType'] ?? 'unknown',
    'colors': WardrobePalette.normalizeColors(
      (aiData['colors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
    ),
    'styleTags': WardrobePalette.normalizeStyleTags(
      (aiData['styleTags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    ),
    'season': WardrobePalette.normalizeSeasons(
      (aiData['season'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
    ),
    if (aiData['brand'] != null) 'brand': aiData['brand'],
    if (!metadata.isEmpty) ...metadata.toJson(),
  };
}
