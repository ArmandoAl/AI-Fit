import '../../wardrobe/domain/wardrobe_ai_metadata.dart';
import '../../wardrobe/domain/wardrobe_item_model.dart';
import '../domain/outfit_models.dart';
import '../domain/outfit_semantic_targets.dart';

/// Scores wardrobe items using WardrobeAiMetadata v2 + OutfitSemanticTargets.
class WardrobeMetadataScorer {
  WardrobeMetadataScorer._();

  static const _occasionFallback = {
    'casual': ['everyday', 'casual_outing'],
    'everyday': ['everyday', 'casual_outing'],
    'formal': ['formal_event', 'office'],
    'work': ['office', 'work_casual'],
    'party': ['formal_event', 'beach_dinner'],
    'date': ['summer_date', 'beach_dinner'],
    'sport': ['active_wear'],
  };

  /// Boost 0.0–0.35 based on hidden metadata (items without v2 metadata → 0).
  static double scoreMetadata(WardrobeItem item, OutfitIntent intent) {
    final meta = item.aiMetadata;
    if (meta == null || meta.isEmpty) return 0;

    final targets = intent.semanticTargets;
    double boost = 0;

    boost += _scoreOccasionVectors(meta, intent, targets);
    boost += _scoreStyleScores(meta, targets);
    boost += _scoreClimate(meta, intent, targets);
    boost += _scoreAesthetic(meta, intent, targets);
    boost += _scoreColorProfile(meta, targets);

    return boost.clamp(0.0, 0.35);
  }

  static double _scoreOccasionVectors(
    WardrobeAiMetadata meta,
    OutfitIntent intent,
    OutfitSemanticTargets targets,
  ) {
    final vectors = meta.occasionVectors;
    if (vectors == null || vectors.isEmpty) return 0;

    final slugs = targets.occasionSlugs.isNotEmpty
        ? targets.occasionSlugs
        : _occasionFallback[intent.occasion ?? ''] ?? [];

    if (slugs.isEmpty) return 0;

    var best = 0.0;
    for (final slug in slugs) {
      final v = vectors[slug] ?? vectors[_normalize(slug)];
      if (v != null && v > best) best = v;
    }
    return best * 0.12;
  }

  static double _scoreStyleScores(
    WardrobeAiMetadata meta,
    OutfitSemanticTargets targets,
  ) {
    final scores = meta.styleScores;
    if (scores == null || scores.isEmpty) return 0;

    var boost = 0.0;

    if (targets.formality != null && scores.containsKey('formality')) {
      final diff = (scores['formality']! - targets.formality!).abs();
      boost += (1.0 - diff.clamp(0.0, 1.0)) * 0.08;
    }

    for (final aesthetic in targets.aestheticSlugs) {
      final key = _styleKeyForAesthetic(aesthetic);
      if (key != null && scores.containsKey(key)) {
        boost += scores[key]! * 0.04;
      }
    }

    for (final tag in targets.aestheticSlugs) {
      if (scores.containsKey(tag)) {
        boost += scores[tag]! * 0.04;
      }
    }

    return boost.clamp(0.0, 0.12);
  }

  static String? _styleKeyForAesthetic(String slug) {
    const map = {
      'streetwear': 'streetwear',
      'luxury': 'luxury',
      'old_money': 'luxury',
      'quiet_luxury': 'luxury',
      'minimalist': 'minimalist',
      'sporty': 'sporty',
      'vintage': 'vintage',
      'casual': 'formality',
    };
    return map[slug];
  }

  static double _scoreClimate(
    WardrobeAiMetadata meta,
    OutfitIntent intent,
    OutfitSemanticTargets targets,
  ) {
    final climate = meta.climateCompatibility;
    if (climate == null || climate.isEmpty) return 0;

    final keys = targets.climateKeys.isNotEmpty
        ? targets.climateKeys
        : _climateFromIntent(intent);

    if (keys.isEmpty) return 0;

    var sum = 0.0;
    var count = 0;
    for (final key in keys) {
      final v = climate[key];
      if (v != null) {
        sum += v;
        count++;
      }
    }
    if (count == 0) return 0;
    return (sum / count) * 0.08;
  }

  static List<String> _climateFromIntent(OutfitIntent intent) {
    if (intent.weather == 'cold') return ['cold_weather'];
    if (intent.weather == 'warm' || intent.weather == 'sunny') {
      return ['hot_weather'];
    }
    if (intent.season == 'summer') return ['hot_weather', 'humid_weather'];
    if (intent.season == 'winter') return ['cold_weather'];
    return [];
  }

  static double _scoreAesthetic(
    WardrobeAiMetadata meta,
    OutfitIntent intent,
    OutfitSemanticTargets targets,
  ) {
    final aesthetic = meta.fashionAesthetic;
    if (aesthetic == null) return 0;

    final wanted = targets.aestheticSlugs.isNotEmpty
        ? targets.aestheticSlugs
        : intent.styleTags;

    if (wanted.isEmpty) return 0;

    var boost = 0.0;
    final primary = aesthetic.primary?.toLowerCase();
    if (primary != null && wanted.any((w) => _normalize(w) == _normalize(primary))) {
      boost += 0.06 * (aesthetic.confidence ?? 0.8);
    }

    for (final sec in aesthetic.secondary ?? []) {
      if (wanted.any((w) => _normalize(w) == _normalize(sec))) {
        boost += 0.03;
      }
    }

    return boost.clamp(0.0, 0.08);
  }

  static double _scoreColorProfile(
    WardrobeAiMetadata meta,
    OutfitSemanticTargets targets,
  ) {
    final profile = meta.colorProfile;
    if (profile == null) return 0;

    var boost = 0.0;
    if (targets.preferMutedColors == true &&
        profile.saturation?.contains('muted') == true) {
      boost += 0.03;
    }
    if (targets.preferLowContrast == true &&
        profile.contrast?.contains('low') == true) {
      boost += 0.02;
    }
    return boost;
  }

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
}
