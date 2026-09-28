import '../../outfit/domain/outfit_models.dart' as pipeline;
import '../../outfit/domain/try_on_status.dart';

enum ChatRole { user, ai }

enum ChatMessageType {
  text,
  typing,
  ctaGenerate,
  outfitPreview,
  generationLoading,
  generationError,
}

class ChatAttachment {
  final String title;
  final String description;
  final String imageUrl;

  const ChatAttachment({
    required this.title,
    required this.description,
    required this.imageUrl,
  });
}

/// Preview de outfit generado por el pipeline existente (inline en chat).
class ChatOutfitPreview {
  final pipeline.GeneratedOutfit outfit;
  final String? tryOnImageUrl;
  final String explanation;
  final TryOnStatus tryOnStatus;
  final String tryOnProvider;

  const ChatOutfitPreview({
    required this.outfit,
    this.tryOnImageUrl,
    this.explanation = '',
    this.tryOnStatus = TryOnStatus.none,
    this.tryOnProvider = pipeline.defaultTryOnProvider,
  });

  ChatOutfitPreview copyWith({
    pipeline.GeneratedOutfit? outfit,
    String? tryOnImageUrl,
    String? explanation,
    TryOnStatus? tryOnStatus,
    String? tryOnProvider,
  }) {
    return ChatOutfitPreview(
      outfit: outfit ?? this.outfit,
      tryOnImageUrl: tryOnImageUrl ?? this.tryOnImageUrl,
      explanation: explanation ?? this.explanation,
      tryOnStatus: tryOnStatus ?? this.tryOnStatus,
      tryOnProvider: tryOnProvider ?? this.tryOnProvider,
    );
  }
}

class ChatMessage {
  final String id;
  final ChatRole role;
  final ChatMessageType type;
  final String? text;
  final ChatAttachment? attachment;
  final ChatOutfitPreview? outfitPreview;
  final String? generationPhase;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    this.type = ChatMessageType.text,
    this.text,
    this.attachment,
    this.outfitPreview,
    this.generationPhase,
    required this.timestamp,
  });

  factory ChatMessage.userText(String text, {ChatAttachment? attachment}) =>
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: ChatRole.user,
        type: ChatMessageType.text,
        text: text,
        attachment: attachment,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.assistantText(String text) => ChatMessage(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    role: ChatRole.ai,
    type: ChatMessageType.text,
    text: text,
    timestamp: DateTime.now(),
  );

  factory ChatMessage.cta() => ChatMessage(
    id: 'cta_${DateTime.now().millisecondsSinceEpoch}',
    role: ChatRole.ai,
    type: ChatMessageType.ctaGenerate,
    timestamp: DateTime.now(),
  );

  factory ChatMessage.loading(String phase) => ChatMessage(
    id: 'loading_${DateTime.now().millisecondsSinceEpoch}',
    role: ChatRole.ai,
    type: ChatMessageType.generationLoading,
    generationPhase: phase,
    timestamp: DateTime.now(),
  );

  factory ChatMessage.outfit(ChatOutfitPreview preview) => ChatMessage(
    id: 'outfit_${preview.outfit.id}',
    role: ChatRole.ai,
    type: ChatMessageType.outfitPreview,
    outfitPreview: preview,
    timestamp: DateTime.now(),
  );

  factory ChatMessage.error(String message) => ChatMessage(
    id: 'err_${DateTime.now().millisecondsSinceEpoch}',
    role: ChatRole.ai,
    type: ChatMessageType.generationError,
    text: message,
    timestamp: DateTime.now(),
  );
}

/// DTO legacy para rutas `/outfit-result` (no confundir con outfit_models).
class GeneratedOutfit {
  final String id;
  final String imageUrl;
  final int matchPercentage;
  final List<String> itemIds;

  GeneratedOutfit({
    required this.id,
    required this.imageUrl,
    required this.matchPercentage,
    required this.itemIds,
  });

  factory GeneratedOutfit.fromJson(Map<String, dynamic> json) {
    return GeneratedOutfit(
      id: json['outfitId']?.toString() ?? json['id']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      matchPercentage: json['matchPercentage'] is int
          ? json['matchPercentage'] as int
          : int.tryParse(json['matchPercentage']?.toString() ?? '') ?? 0,
      itemIds: json['items'] is List
          ? List<String>.from(json['items'])
          : json['itemIds'] is List
          ? List<String>.from(json['itemIds'])
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'imageUrl': imageUrl,
    'matchPercentage': matchPercentage,
    'itemIds': itemIds,
  };
}
