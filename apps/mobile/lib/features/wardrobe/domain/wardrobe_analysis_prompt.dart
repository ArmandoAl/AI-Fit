import 'wardrobe_palette.dart';

/// Shared Gemini wardrobe analysis prompt (JSON-only, schema v2).
class WardrobeAnalysisPrompt {
  WardrobeAnalysisPrompt._();

  static String get fullAnalysis => '''
You are a professional fashion stylist, fabric/material analyst, silhouette expert, color theory expert, and luxury/streetwear aesthetic classifier.

Analyze this clothing item image carefully. Return ONLY valid JSON (no markdown, no commentary).

REQUIRED fields (always include):
- type: one of "top", "bottom", "shoes", "outerwear"
- subType: specific garment (e.g. "linen shirt", "slim jeans", "sneakers")
- colors: array of 1-3 dominant colors — USE ONLY these exact values: ${WardrobePalette.colorsForPrompt}
  (e.g. tan/khaki/camel → beige, grey/charcoal → gray, olive → green)
- styleTags: array of 1-4 styles — USE ONLY these exact values: ${WardrobePalette.styleTagsForPrompt}
- season: array of suitable seasons — only: spring, summer, fall, winter

OPTIONAL field:
- brand: string if a visible brand can be inferred, else omit

HIDDEN semantic metadata (include all; use snake_case keys; scores 0.0-1.0):
- ai_schema_version: 2
- visual_weight: "light" | "medium" | "heavy"
- texture: { primary, secondary[], surface_feel, structure }
- silhouette: { fit, length, shape }
- fashion_aesthetic: { primary, secondary[], confidence }
- color_profile: { temperature, saturation, contrast }
- style_scores: { formality, streetwear, luxury, minimalist, sporty, vintage } (0.0-1.0 each)
- gender_expression: { primary, confidence }
- layering_compatibility: { works_with[], avoid_with[] }
- occasion_vectors: object of occasion_slug -> score (e.g. beach_dinner, office, formal_event)
- climate_compatibility: { hot_weather, humid_weather, cold_weather } (0.0-1.0)
- visual_attributes: { cleanliness, sharpness, casualness, elegance } (0.0-1.0)

Rules:
- Be concise and deterministic.
- Use lowercase snake_case for enum-like slugs (e.g. old_money, quiet_luxury).
- Infer fabric, silhouette, aesthetic, and layering from visible cues only.
- Output must be a single JSON object.
''';

  static String get colorsAndStyleOnly => '''
Analyze this clothing item for colors and style only.
Return ONLY valid JSON with:
- colors: array of dominant colors — USE ONLY: ${WardrobePalette.colorsForPrompt}
- styleTags: array of styles — USE ONLY: ${WardrobePalette.styleTagsForPrompt}
''';
}
