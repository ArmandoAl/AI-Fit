import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/services/deepseek_service.dart';
import '../../wardrobe/domain/wardrobe_palette.dart';
import '../domain/stylist_chat_response.dart';
import '../domain/stylist_intent_state.dart';

/// Servicio de chat del estilista personal — enrutado server-side vía `ai-router` (DeepSeek).
class StylistChatService {
  final DeepSeekService _gateway;

  StylistChatService({DeepSeekService? gatewayClient})
      : _gateway = gatewayClient ?? const DeepSeekService();

  static const _model = 'deepseek-chat';

  static String get _systemPrompt => '''
You are OutfitAI — a premium personal fashion stylist.

YOUR ROLE:
- Have a warm, concise, modern conversation.
- Ask ONE focused follow-up question when key details are missing.
- Never generate outfits or item lists yourself.
- Never mention APIs, JSON, or backend systems.

YOU MUST RETURN ONLY valid JSON with this exact shape:
{
  "assistantMessage": "string — what the user sees",
  "intentState": {
    "occasion": "string | null",
    "colors": ["string"],
    "styleTags": ["string"],
    "season": "spring|summer|fall|winter|null",
    "weather": "sunny|rainy|cold|warm|null",
    "formality": 0.0-1.0,
    "layeringPreference": "light|medium|heavy|null",
    "vibe": ["string"],
    "semanticTargets": {
      "formality": 0.0-1.0,
      "occasionSlugs": ["everyday","casual_outing","office","formal_event","beach_dinner","summer_date","vacation","active_wear","work_casual"],
      "climateKeys": ["hot_weather","humid_weather","cold_weather"],
      "aestheticSlugs": ["casual","formal","streetwear","luxury","minimalist","old_money","quiet_luxury","sporty","vintage"],
      "preferLowContrast": true|false|null,
      "preferMutedColors": true|false|null
    }
  },
  "readyToGenerate": true|false,
  "missingFields": ["occasion","colors","styleTags"]
}

RULES:
- Merge new info with CURRENT_INTENT — never drop known fields unless user changes them.
- readyToGenerate=true only when occasion is clear AND (colors OR styleTags OR vibe) exist.
- Keep assistantMessage under 3 short sentences.
- Be premium, confident, helpful — not salesy.

LANGUAGE (critical):
- assistantMessage: ALWAYS Spanish (neutral LATAM). Never English in what the user reads.
- User may write in Spanish or English; understand both.
- intentState.colors: ONLY English slugs from this list: ${WardrobePalette.colorsForPrompt}
- intentState.styleTags: ONLY English slugs from: ${WardrobePalette.styleTagsForPrompt}
- intentState.season: only spring|summer|fall|winter|null (never Spanish season names in JSON).
- intentState.occasion: use English slugs casual|formal|sport|party|work|date|everyday when possible.
- Map Spanish user words to English slugs in JSON (e.g. negro→black, deportivo→sporty, primavera→spring).
''';

  Future<StylistChatResponse> chat({
    required String userMessage,
    required StylistIntentState currentIntent,
    required List<MapEntry<String, String>> recentTurns,
  }) async {
    final historyText = recentTurns
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');

    final userPayload = '''
CURRENT_INTENT:
${jsonEncode(currentIntent.toJson())}

RECENT_CHAT:
${historyText.isEmpty ? '(new session)' : historyText}

USER_MESSAGE:
$userMessage
''';

    try {
      final json = await _gateway.chatJson(
        systemPrompt: _systemPrompt,
        userPrompt: userPayload,
        model: _model,
        temperature: 0.6,
      );

      debugPrint('✅ Stylist chat response received: ready=${json['readyToGenerate']}');
      return StylistChatResponse.fromJson(json);
    } catch (e) {
      debugPrint('⚠️ Stylist chat gateway error ($e), executing graceful fallback...');
      return StylistChatResponse(
        assistantMessage:
            '¡Excelente! Cuéntame más sobre la ocasión o el estilo que buscas para armar tu outfit ideal.',
        intentState: currentIntent,
        readyToGenerate: currentIntent.hasMinimumContext,
      );
    }
  }
}

