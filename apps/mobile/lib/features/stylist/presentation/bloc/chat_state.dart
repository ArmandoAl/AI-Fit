import 'package:equatable/equatable.dart';
import '../../domain/chat_models.dart';
import '../../domain/stylist_intent_state.dart';
import '../../../outfit/domain/outfit_models.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {
  const ChatInitial();
}

class ChatLoaded extends ChatState {
  final List<ChatMessage> messages;
  final bool isTyping;
  final bool isGenerating;
  final StylistIntentState accumulatedIntent;
  final bool readyToGenerate;
  final OutfitIntent? lastOutfitIntent;
  final Map<String, String> lastWardrobeImageUrls;

  const ChatLoaded({
    required this.messages,
    this.isTyping = false,
    this.isGenerating = false,
    this.accumulatedIntent = const StylistIntentState(),
    this.readyToGenerate = false,
    this.lastOutfitIntent,
    this.lastWardrobeImageUrls = const {},
  });

  ChatLoaded copyWith({
    List<ChatMessage>? messages,
    bool? isTyping,
    bool? isGenerating,
    StylistIntentState? accumulatedIntent,
    bool? readyToGenerate,
    OutfitIntent? lastOutfitIntent,
    Map<String, String>? lastWardrobeImageUrls,
  }) {
    return ChatLoaded(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      isGenerating: isGenerating ?? this.isGenerating,
      accumulatedIntent: accumulatedIntent ?? this.accumulatedIntent,
      readyToGenerate: readyToGenerate ?? this.readyToGenerate,
      lastOutfitIntent: lastOutfitIntent ?? this.lastOutfitIntent,
      lastWardrobeImageUrls:
          lastWardrobeImageUrls ?? this.lastWardrobeImageUrls,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        isTyping,
        isGenerating,
        accumulatedIntent,
        readyToGenerate,
        lastOutfitIntent,
        lastWardrobeImageUrls,
      ];
}
