import 'package:flutter/foundation.dart';
import '../../../core/services/deepseek_service.dart';
import '../../wardrobe/domain/wardrobe_palette.dart';
import '../domain/outfit_intent_prompt.dart';
import '../domain/outfit_models.dart';

/// Fase 1: Analiza el prompt del usuario → [OutfitIntent] JSON estructurado.
///
/// Primario: DeepSeek vía Gateway Server-Side (`ai-router` Edge Function).
/// Fallback: Análisis heurístico determinista local si el gateway no responde o falla.
class OutfitIntentAnalyzer {
  final DeepSeekService _deepSeek;

  OutfitIntentAnalyzer({DeepSeekService? deepSeek})
    : _deepSeek = deepSeek ?? const DeepSeekService();

  Future<OutfitIntent> analyzeUserPrompt(String userPrompt) async {
    debugPrint('🔍 FASE 1 — Analyzing intent: "$userPrompt"');

    try {
      final jsonMap = await _analyzeWithDeepSeek(userPrompt);
      jsonMap['userPrompt'] = userPrompt;
      final explicitColors = explicitColorRequirements(userPrompt);
      if (explicitColors.isNotEmpty) {
        final modelColors = jsonMap['requiredColorsByCategory'];
        jsonMap['requiredColorsByCategory'] = {
          if (modelColors is Map) ...modelColors,
          ...explicitColors,
        };
      }
      debugPrint('🧠 DeepSeek reasoning: ${jsonMap['reasoning']}');
      debugPrint('✅ Intent (DeepSeek Gateway): $jsonMap');
      return OutfitIntent.fromJson(jsonMap);
    } catch (e) {
      debugPrint(
        '⚠️ DeepSeek Gateway failed ($e), running local heuristic analyzer...',
      );
      return _localFallbackAnalysis(userPrompt);
    }
  }

  Future<Map<String, dynamic>> _analyzeWithDeepSeek(String userPrompt) async {
    return _deepSeek.chatJson(
      systemPrompt: OutfitIntentPrompt.systemRole,
      userPrompt: OutfitIntentPrompt.userPrompt(userPrompt, DateTime.now()),
    );
  }

  OutfitIntent _localFallbackAnalysis(String prompt) {
    final lower = prompt.toLowerCase();
    String? occasion;
    final styleTags = <String>[];
    final preferredColors = <String>[];

    if (lower.contains('boda') ||
        lower.contains('wedding') ||
        lower.contains('formal')) {
      occasion = 'formal';
      styleTags.add('formal');
    } else if (lower.contains('gym') ||
        lower.contains('deporte') ||
        lower.contains('sport')) {
      occasion = 'sport';
      styleTags.add('sporty');
    } else if (lower.contains('trabajo') || lower.contains('work')) {
      occasion = 'work';
      styleTags.add('formal');
    } else {
      occasion = 'casual';
      styleTags.add('casual');
    }

    // Extracción de colores conocidos
    for (final color in WardrobePalette.standardColors) {
      if (lower.contains(color.toLowerCase())) {
        preferredColors.add(color);
      }
    }

    return OutfitIntent(
      userPrompt: prompt,
      occasion: occasion,
      styleTags: styleTags,
      preferredColors: preferredColors,
      requiredColorsByCategory: explicitColorRequirements(prompt),
      reasoning: 'Análisis heurístico local (fallback)',
    );
  }

  /// Captures unambiguous color commands locally so model wording cannot weaken them.
  static Map<String, List<String>> explicitColorRequirements(String prompt) {
    final text = prompt.toLowerCase();
    const colors = <String, String>{
      'black': 'black',
      'negro': 'black',
      'negra': 'black',
      'negros': 'black',
      'negras': 'black',
      'white': 'white',
      'blanco': 'white',
      'blanca': 'white',
      'blancos': 'white',
      'blancas': 'white',
      'beige': 'beige',
      'brown': 'brown',
      'café': 'brown',
      'cafe': 'brown',
      'blue': 'blue',
      'azul': 'blue',
      'red': 'red',
      'rojo': 'red',
      'roja': 'red',
      'green': 'green',
      'verde': 'green',
      'gray': 'gray',
      'grey': 'gray',
      'gris': 'gray',
    };
    final result = <String, List<String>>{};
    final allMatch = RegExp(
      r'\b(?:all|everything|todo|toda|todos|todas)\s+(?:in\s+)?(black|negro|negra|negros|negras|white|blanco|blanca|blancos|blancas|beige|brown|café|cafe|blue|azul|red|rojo|roja|green|verde|gray|grey|gris)\b',
    ).firstMatch(text);
    if (allMatch != null) result['*'] = [colors[allMatch.group(1)]!];

    final shoesException =
        RegExp(
          r'\b(?:except|excepto|salvo)\s+(?:for\s+)?(?:(?:the|el|la|los|las)\s+)?(?:shoes|shoe|zapatos|zapato|calzado)\s+(?:in\s+)?(white|blanco|blanca|blancos|blancas|black|negro|negra|negros|negras)\b',
        ).firstMatch(text) ??
        RegExp(
          r'\b(?:except|excepto|salvo)\s+(?:for\s+)?(?:(?:the|el|la|los|las)\s+)?(white|blanco|blanca|blancos|blancas|black|negro|negra|negros|negras)\s+(?:shoes|shoe|zapatos|zapato|calzado)\b',
        ).firstMatch(text);
    if (shoesException != null && result.containsKey('*')) {
      result['shoes'] = [colors[shoesException.group(1)]!];
    }

    final explicitRequirement = RegExp(
      r'\b(?:must|required|only|exactly|obligatorio|obligatoria|debe|deben|tiene que|exclusivamente)\b',
    ).hasMatch(text);
    final statedAsPreference = RegExp(
      r'\b(?:prefer|preferably|would like|like|me gusta|prefiero|idealmente|recomienda)\b',
    ).hasMatch(text);
    if (statedAsPreference && !explicitRequirement) return result;

    for (final category in <String, List<String>>{
      'top': ['top', 'shirt', 'camisa', 'arriba'],
      'bottom': ['bottom', 'pants', 'pantalones', 'pantalón', 'abajo'],
      'shoes': ['shoes', 'zapatos', 'calzado'],
    }.entries) {
      if (result.containsKey(category.key)) continue;
      for (final color in colors.keys) {
        final colorThenCategory = RegExp(
          '\\b${RegExp.escape(color)}\\b\\s+(?:(?:on|for|in|of|de|en|el|la|los|las)\\s+)?\\b(?:${category.value.map(RegExp.escape).join('|')})\\b',
        );
        final categoryThenColor = RegExp(
          '\\b(?:${category.value.map(RegExp.escape).join('|')})\\b\\s+(?:(?:in|of|de|en|color)\\s+)?\\b${RegExp.escape(color)}\\b',
        );
        if (colorThenCategory.hasMatch(text) ||
            categoryThenColor.hasMatch(text)) {
          result[category.key] = [colors[color]!];
          break;
        }
      }
    }
    return result;
  }
}
