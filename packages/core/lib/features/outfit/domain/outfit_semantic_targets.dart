/// Targets derivados del prompt del usuario para matching con WardrobeAiMetadata v2.
class OutfitSemanticTargets {
  final double? formality;
  final List<String> occasionSlugs;
  final List<String> climateKeys;
  final List<String> aestheticSlugs;
  final bool? preferLowContrast;
  final bool? preferMutedColors;

  const OutfitSemanticTargets({
    this.formality,
    this.occasionSlugs = const [],
    this.climateKeys = const [],
    this.aestheticSlugs = const [],
    this.preferLowContrast,
    this.preferMutedColors,
  });

  factory OutfitSemanticTargets.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const OutfitSemanticTargets();

    final formality = json['formality'];
    return OutfitSemanticTargets(
      formality: formality is num
          ? formality.toDouble().clamp(0.0, 1.0)
          : double.tryParse(formality?.toString() ?? ''),
      occasionSlugs: _stringList(json['occasionSlugs']),
      climateKeys: _stringList(json['climateKeys']),
      aestheticSlugs: _stringList(json['aestheticSlugs']),
      preferLowContrast: json['preferLowContrast'] as bool?,
      preferMutedColors: json['preferMutedColors'] as bool?,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return [];
    return value.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  Map<String, dynamic> toJson() => {
        if (formality != null) 'formality': formality,
        'occasionSlugs': occasionSlugs,
        'climateKeys': climateKeys,
        'aestheticSlugs': aestheticSlugs,
        if (preferLowContrast != null) 'preferLowContrast': preferLowContrast,
        if (preferMutedColors != null) 'preferMutedColors': preferMutedColors,
      };

  bool get isEmpty =>
      formality == null &&
      occasionSlugs.isEmpty &&
      climateKeys.isEmpty &&
      aestheticSlugs.isEmpty;
}
