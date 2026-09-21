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
      debugPrint('🧠 DeepSeek reasoning: ${jsonMap['reasoning']}');
      debugPrint('✅ Intent (DeepSeek Gateway): $jsonMap');
      return OutfitIntent.fromJson(jsonMap);
    } catch (e) {
      debugPrint('⚠️ DeepSeek Gateway failed ($e), running local heuristic analyzer...');
      return _localFallbackAnalysis(userPrompt);
    }
  }

  Future<Map<String, dynamic>> _analyzeWithDeepSeek(String userPrompt) async {
    return _deepSeek.chatJson(
      systemPrompt: OutfitIntentPrompt.systemRole,
      userPrompt: OutfitIntentPrompt.userPrompt(
        userPrompt,
        DateTime.now(),
      ),
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
      reasoning: 'Análisis heurístico local (fallback)',
    );
  }
}
