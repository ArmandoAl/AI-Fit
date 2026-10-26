import 'stylist_intent_state.dart';

/// Respuesta estructurada del modelo de chat (solo conversación + intent).
class StylistChatResponse {
  final String assistantMessage;
  final StylistIntentState intentState;
  final bool readyToGenerate;
  final List<String> missingFields;

  const StylistChatResponse({
    required this.assistantMessage,
    required this.intentState,
    this.readyToGenerate = false,
    this.missingFields = const [],
  });

  factory StylistChatResponse.fromJson(Map<String, dynamic> json) {
    return StylistChatResponse(
      assistantMessage: json['assistantMessage']?.toString() ??
          json['message']?.toString() ??
          '',
      intentState: StylistIntentState.fromJson(
        json['intentState'] as Map<String, dynamic>?,
      ),
      readyToGenerate: json['readyToGenerate'] == true,
      missingFields: json['missingFields'] is List
          ? (json['missingFields'] as List).map((e) => e.toString()).toList()
          : [],
    );
  }
}
