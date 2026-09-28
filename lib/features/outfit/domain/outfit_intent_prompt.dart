/// Prompt de configuración para Fase 1 — análisis de intención (JSON completo).
class OutfitIntentPrompt {
  OutfitIntentPrompt._();

  static const String systemRole = '''
You are a senior fashion stylist and outfit-planning AI.
Your only job is to read the user's outfit request and return ONE valid JSON object.
No markdown, no commentary outside JSON.
''';

  static const String fullExampleJson = '''
{
  "reasoning": "Weekend brunch implies relaxed casual dress, warm weather, light colors.",
  "occasion": "casual",
  "preferredColors": ["beige", "white"],
  "requiredColorsByCategory": {},
  "styleTags": ["casual", "minimalist"],
  "season": "summer",
  "weather": "warm",
  "constraints": {
    "mustInclude": null,
    "mustAvoid": "heavy outerwear",
    "budget": "medium"
  },
  "semanticTargets": {
    "formality": 0.25,
    "occasionSlugs": ["everyday", "casual_outing", "beach_dinner"],
    "climateKeys": ["hot_weather", "humid_weather"],
    "aestheticSlugs": ["casual", "minimalist"],
    "preferLowContrast": true,
    "preferMutedColors": true
  }
}
''';

  static String userPrompt(String userRequest, DateTime now) {
    return '''
### CURRENT CONTEXT
- Date: ${now.toIso8601String()}
- Inferred season if omitted: ${_seasonFromMonth(now.month)}

### COMPLETE OUTPUT EXAMPLE (follow this structure exactly)
$fullExampleJson

### JSON SCHEMA (return ALL keys; use null or [] when unknown)
{
  "reasoning": "string (required)",
  "occasion": "casual" | "formal" | "sport" | "party" | "work" | "date" | "everyday" | null,
  "preferredColors": ["string"],
  "requiredColorsByCategory": {"*": ["black"], "shoes": ["white"]},
  "styleTags": ["string"],
  "season": "spring" | "summer" | "fall" | "winter" | null,
  "weather": "sunny" | "rainy" | "cold" | "warm" | null,
  "constraints": {
    "mustInclude": "string" | null,
    "mustAvoid": "string" | null,
    "budget": "low" | "medium" | "high" | null
  },
  "semanticTargets": {
    "formality": number 0.0-1.0 (0=very casual, 1=very formal),
    "occasionSlugs": ["everyday", "casual_outing", "office", "formal_event", "beach_dinner", "summer_date", "vacation", "active_wear", "work_casual"],
    "climateKeys": ["hot_weather", "humid_weather", "cold_weather"],
    "aestheticSlugs": ["casual", "formal", "streetwear", "luxury", "minimalist", "old_money", "quiet_luxury", "sporty", "vintage"],
    "preferLowContrast": boolean | null,
    "preferMutedColors": boolean | null
  }
}

### RULES
- Output ONLY the JSON object.
- semanticTargets helps match wardrobe AI metadata (occasion_vectors, style_scores, climate_compatibility).
- Map user intent to occasionSlugs and climateKeys when implied.
- preferredColors: use standard ENGLISH names only (black, white, gray, navy, blue, red, green, brown, beige, pink, yellow, orange, purple) — even if the user wrote in Spanish (e.g. negro→black, azul→blue).
- requiredColorsByCategory contains ONLY explicit mandatory color instructions. Use "*" when every visible garment must have the color, or category keys (top, bottom, shoes, outerwear, one_piece, accessories) for scoped requirements and exceptions. Example: "all black except white shoes" → {"*": ["black"], "shoes": ["white"]}. Put suggestions and stylistic preferences in preferredColors, never in requiredColorsByCategory.
- Mandatory color means exact color identity. Do not treat navy, brown, beige, or dark as black; compatibility is not compliance. If color intent is not explicit, leave requiredColorsByCategory empty.
- styleTags and occasion: use English slugs (casual, formal, sporty, etc.).
- The user request may be in Spanish; interpret it correctly but keep all JSON enum/slug values in English.

### USER REQUEST
"$userRequest"
''';
  }

  static String _seasonFromMonth(int month) {
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'summer';
    if (month >= 9 && month <= 11) return 'fall';
    return 'winter';
  }
}
