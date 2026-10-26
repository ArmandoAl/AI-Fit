import '../domain/chat_models.dart';
import '../domain/stylist_intent_state.dart';

class StylistChatTurn {
  final String assistantMessage;
  final StylistIntentState intentState;
  final bool readyToGenerate;

  const StylistChatTurn({
    required this.assistantMessage,
    required this.intentState,
    this.readyToGenerate = false,
  });
}

abstract class StylistRepository {
  Future<StylistChatTurn> sendMessage({
    required String userMessage,
    required List<ChatMessage> history,
    required StylistIntentState currentIntent,
  });

  StylistChatTurn welcomeMessage();
}
