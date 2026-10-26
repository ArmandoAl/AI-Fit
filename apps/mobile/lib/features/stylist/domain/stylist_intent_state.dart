import '../../outfit/domain/outfit_models.dart';
import '../../outfit/domain/outfit_semantic_targets.dart';
import '../../wardrobe/domain/wardrobe_palette.dart';

/// Intent acumulado en sesión de chat (compatible con OutfitIntent / DeepSeek).
class StylistIntentState {
  final String? occasion;
  final List<String> colors;
  final List<String> styleTags;
  final String? season;
  final String? weather;
  final double? formality;
  final String? layeringPreference;
  final List<String> vibe;
  final OutfitSemanticTargets? semanticTargets;

  const StylistIntentState({
    this.occasion,
    this.colors = const [],
    this.styleTags = const [],
    this.season,
    this.weather,
    this.formality,
    this.layeringPreference,
    this.vibe = const [],
    this.semanticTargets,
  });

  factory StylistIntentState.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const StylistIntentState();

    final semantic = json['semanticTargets'] is Map<String, dynamic>
        ? OutfitSemanticTargets.fromJson(
            json['semanticTargets'] as Map<String, dynamic>,
          )
        : null;

    return StylistIntentState(
      occasion: WardrobePalette.normalizeOccasion(json['occasion']?.toString()),
      colors: WardrobePalette.normalizeColors(_list(json['colors'])),
      styleTags: WardrobePalette.normalizeStyleTags(_list(json['styleTags'])),
      season: json['season'] != null
          ? WardrobePalette.normalizeSeason(json['season'].toString())
          : null,
      weather: WardrobePalette.normalizeWeather(json['weather']?.toString()),
      formality: _double(json['formality']),
      layeringPreference: json['layeringPreference']?.toString(),
      vibe: _list(json['vibe']),
      semanticTargets: semantic?.isEmpty == true ? null : semantic,
    );
  }

  static List<String> _list(dynamic v) {
    if (v is! List) return [];
    return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  static double? _double(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble().clamp(0.0, 1.0);
    return double.tryParse(v.toString());
  }

  StylistIntentState merge(StylistIntentState other) {
    return StylistIntentState(
      occasion: other.occasion ?? occasion,
      colors: other.colors.isNotEmpty ? other.colors : colors,
      styleTags: other.styleTags.isNotEmpty ? other.styleTags : styleTags,
      season: other.season ?? season,
      weather: other.weather ?? weather,
      formality: other.formality ?? formality,
      layeringPreference: other.layeringPreference ?? layeringPreference,
      vibe: other.vibe.isNotEmpty ? other.vibe : vibe,
      semanticTargets: other.semanticTargets ?? semanticTargets,
    );
  }

  Map<String, dynamic> toJson() => {
        if (occasion != null) 'occasion': occasion,
        'colors': colors,
        'styleTags': styleTags,
        if (season != null) 'season': season,
        if (weather != null) 'weather': weather,
        if (formality != null) 'formality': formality,
        if (layeringPreference != null) 'layeringPreference': layeringPreference,
        'vibe': vibe,
        if (semanticTargets != null && !semanticTargets!.isEmpty)
          'semanticTargets': semanticTargets!.toJson(),
      };

  bool get hasMinimumContext =>
      occasion != null &&
      occasion!.isNotEmpty &&
      (styleTags.isNotEmpty || colors.isNotEmpty || vibe.isNotEmpty);

  /// True when chat already captured enough structure to skip DeepSeek on generate.
  bool get hasStructuredIntentForPipeline =>
      hasMinimumContext ||
      colors.isNotEmpty ||
      styleTags.isNotEmpty ||
      (semanticTargets != null && !semanticTargets!.isEmpty);

  /// Maps stylist session intent → pipeline [OutfitIntent] (no DeepSeek round-trip).
  OutfitIntent toOutfitIntent() {
    final mergedStyleTags = <String>{
      ...styleTags,
      ...vibe,
    }.toList();

    return OutfitIntent(
      reasoning: 'Structured intent from stylist chat',
      occasion: occasion,
      preferredColors: colors,
      styleTags: mergedStyleTags,
      season: season,
      weather: weather,
      userPrompt: toUserPrompt(),
      semanticTargets: semanticTargets ?? const OutfitSemanticTargets(),
    );
  }

  /// Prompt natural para el pipeline existente (OutfitIntentAnalyzer refina después).
  String toUserPrompt() {
    final parts = <String>[];
    if (occasion != null && occasion!.isNotEmpty) {
      parts.add('outfit for $occasion');
    }
    if (styleTags.isNotEmpty) {
      parts.add('style: ${styleTags.join(", ")}');
    }
    if (colors.isNotEmpty) {
      parts.add('colors: ${colors.join(", ")}');
    }
    if (vibe.isNotEmpty) {
      parts.add('vibe: ${vibe.join(", ")}');
    }
    if (season != null) parts.add('season: $season');
    if (weather != null) parts.add('weather: $weather');
    if (formality != null) {
      parts.add(
        formality! >= 0.7
            ? 'formal elegant look'
            : formality! <= 0.35
                ? 'casual relaxed look'
                : 'smart casual look',
      );
    }
    if (layeringPreference != null) {
      parts.add('layering: $layeringPreference');
    }
    return parts.isEmpty ? 'stylish outfit from my wardrobe' : parts.join(', ');
  }
}
