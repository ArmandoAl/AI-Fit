import 'package:equatable/equatable.dart';
import '../../domain/chat_models.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class ChatSessionStarted extends ChatEvent {
  const ChatSessionStarted();
}

class ChatMessageSent extends ChatEvent {
  final String text;
  final ChatAttachment? attachment;

  const ChatMessageSent(this.text, {this.attachment});

  @override
  List<Object?> get props => [text, attachment];
}

class ChatGenerateOutfitRequested extends ChatEvent {
  final bool generateTryOn;

  const ChatGenerateOutfitRequested({this.generateTryOn = true});

  @override
  List<Object?> get props => [generateTryOn];
}

/// Genera try-on bajo demanda para un look del chat (P1).
class ChatTryOnForOutfitRequested extends ChatEvent {
  final String outfitId;

  const ChatTryOnForOutfitRequested(this.outfitId);

  @override
  List<Object?> get props => [outfitId];
}
