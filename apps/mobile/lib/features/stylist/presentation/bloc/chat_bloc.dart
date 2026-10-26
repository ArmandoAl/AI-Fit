import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/l10n/app_strings_es.dart';
import '../../data/stylist_repository.dart';
import '../../domain/chat_models.dart';
import '../../../outfit/domain/outfit_models.dart' as pipeline;
import '../../../outfit/domain/try_on_status.dart';
import '../../../outfit/services/outfit_service.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final StylistRepository repository;
  final OutfitService _outfitService;

  ChatBloc({required this.repository, OutfitService? outfitService})
    : _outfitService = outfitService ?? OutfitService(),
      super(const ChatInitial()) {
    on<ChatSessionStarted>(_onSessionStarted);
    on<ChatMessageSent>(_onMessageSent);
    on<ChatGenerateOutfitRequested>(_onGenerateOutfit);
    on<ChatTryOnForOutfitRequested>(_onTryOnForOutfit);
  }

  void _onSessionStarted(ChatSessionStarted event, Emitter<ChatState> emit) {
    final welcome = repository.welcomeMessage();
    emit(
      ChatLoaded(
        messages: [ChatMessage.assistantText(welcome.assistantMessage)],
        accumulatedIntent: welcome.intentState,
        readyToGenerate: welcome.readyToGenerate,
      ),
    );
  }

  Future<void> _onMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    if (event.text.trim().isEmpty && event.attachment == null) return;

    final current = state;
    if (current is! ChatLoaded) return;

    final userMsg = ChatMessage.userText(
      event.text.trim(),
      attachment: event.attachment,
    );
    var messages = [...current.messages, userMsg];
    messages = _withoutStaleCta(messages);

    emit(
      current.copyWith(
        messages: messages,
        isTyping: true,
        readyToGenerate: false,
      ),
    );

    try {
      final turn = await repository.sendMessage(
        userMessage: [
          event.text.trim(),
          if (event.attachment != null)
            'Contexto adjunto: ${event.attachment!.description}',
        ].where((part) => part.isNotEmpty).join('\n'),
        history: messages,
        currentIntent: current.accumulatedIntent,
      );

      final loaded = state as ChatLoaded;
      var updated = [
        ...loaded.messages,
        ChatMessage.assistantText(turn.assistantMessage),
      ];

      if (turn.readyToGenerate) {
        updated = [...updated, ChatMessage.cta()];
      }

      emit(
        loaded.copyWith(
          messages: updated,
          isTyping: false,
          accumulatedIntent: turn.intentState,
          readyToGenerate: turn.readyToGenerate,
        ),
      );
    } catch (e) {
      debugPrint('❌ Stylist chat error: $e');
      final loaded = state as ChatLoaded;
      emit(
        loaded.copyWith(
          messages: [
            ...loaded.messages,
            ChatMessage.assistantText(AppStringsEs.connectionError),
          ],
          isTyping: false,
        ),
      );
    }
  }

  Future<void> _onGenerateOutfit(
    ChatGenerateOutfitRequested event,
    Emitter<ChatState> emit,
  ) async {
    final current = state;
    if (current is! ChatLoaded || current.isGenerating) return;

    final prompt = current.accumulatedIntent.toUserPrompt();
    var messages = _withoutStaleCta(current.messages);
    messages = [
      ...messages,
      ChatMessage.assistantText(AppStringsEs.puttingLooksTogether),
      ChatMessage.loading('analyzing'),
    ];

    emit(
      current.copyWith(
        messages: messages,
        isGenerating: true,
        readyToGenerate: false,
      ),
    );

    try {
      _updateLoadingPhase(emit, 'filtering');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      _updateLoadingPhase(emit, 'generating');

      final chatIntent = current.accumulatedIntent;
      final result = await _outfitService.generateOutfitSuggestions(
        userPrompt: prompt,
        precomputedIntent: chatIntent.hasStructuredIntentForPipeline
            ? chatIntent.toOutfitIntent()
            : null,
      );

      final loaded = state as ChatLoaded;
      var resultMessages = _withoutLoading(loaded.messages);

      if (result.outfits.isEmpty) {
        resultMessages = [
          ...resultMessages,
          ChatMessage.error(AppStringsEs.couldNotBuildFullLook),
        ];
        emit(loaded.copyWith(messages: resultMessages, isGenerating: false));
        return;
      }

      resultMessages = [
        ...resultMessages,
        ChatMessage.assistantText(AppStringsEs.hereAreYourLooks),
      ];

      for (var i = 0; i < result.outfits.length; i++) {
        final outfit = result.outfits[i];
        TryOnStatus status = TryOnStatus.readyForTryOn;
        if (event.generateTryOn) {
          status = TryOnStatus.generating;
        }
        resultMessages = [
          ...resultMessages,
          ChatMessage.outfit(
            ChatOutfitPreview(
              outfit: outfit,
              explanation: outfit.displayExplanation,
              tryOnStatus: status,
              tryOnProvider: pipeline.tryOnProviderForPosition(i),
            ),
          ),
        ];
      }

      emit(
        loaded.copyWith(
          messages: resultMessages,
          isGenerating: false,
          lastOutfitIntent: result.intent,
          lastWardrobeImageUrls: result.wardrobeImageUrlsByItemId,
        ),
      );

      if (event.generateTryOn) {
        for (final outfit in result.outfits) {
          await _generateTryOnAndUpdateMessage(
            outfitId: outfit.id,
            intent: result.intent,
            wardrobeImageUrlsByItemId: result.wardrobeImageUrlsByItemId,
            emit: emit,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Outfit generation from chat: $e');
      final loaded = state as ChatLoaded;
      emit(
        loaded.copyWith(
          messages: [
            ..._withoutLoading(loaded.messages),
            ChatMessage.error(
              'Something went wrong while generating. Please try again.',
            ),
          ],
          isGenerating: false,
        ),
      );
    }
  }

  Future<void> _onTryOnForOutfit(
    ChatTryOnForOutfitRequested event,
    Emitter<ChatState> emit,
  ) async {
    final current = state;
    if (current is! ChatLoaded || current.lastOutfitIntent == null) return;

    _setOutfitTryOnStatus(emit, event.outfitId, TryOnStatus.generating);

    try {
      final outfit = _findOutfitInMessages(current.messages, event.outfitId);
      if (outfit == null) return;

      final provider = current.messages
          .firstWhere((m) => m.outfitPreview?.outfit.id == event.outfitId)
          .outfitPreview!
          .tryOnProvider;

      final url = await _outfitService.generateTryOnForOutfit(
        outfit: outfit,
        intent: current.lastOutfitIntent!,
        tryOnProvider: provider,
        wardrobeImageUrlsByItemId: current.lastWardrobeImageUrls,
      );

      _setOutfitTryOnStatus(
        emit,
        event.outfitId,
        url != null && url.isNotEmpty ? TryOnStatus.ready : TryOnStatus.failed,
        tryOnImageUrl: url,
      );
    } catch (e) {
      debugPrint('❌ Chat try-on error: $e');
      _setOutfitTryOnStatus(emit, event.outfitId, TryOnStatus.failed);
    }
  }

  Future<void> _generateTryOnAndUpdateMessage({
    required String outfitId,
    required pipeline.OutfitIntent intent,
    required Map<String, String> wardrobeImageUrlsByItemId,
    required Emitter<ChatState> emit,
  }) async {
    final current = state;
    if (current is! ChatLoaded) return;

    final outfit = _findOutfitInMessages(current.messages, outfitId);
    if (outfit == null) return;

    final provider = current.messages
        .firstWhere((m) => m.outfitPreview?.outfit.id == outfitId)
        .outfitPreview!
        .tryOnProvider;

    try {
      final url = await _outfitService.generateTryOnForOutfit(
        outfit: outfit,
        intent: intent,
        tryOnProvider: provider,
        wardrobeImageUrlsByItemId: wardrobeImageUrlsByItemId,
      );

      _setOutfitTryOnStatus(
        emit,
        outfitId,
        url != null && url.isNotEmpty ? TryOnStatus.ready : TryOnStatus.failed,
        tryOnImageUrl: url,
      );
    } catch (e) {
      debugPrint('❌ First try-on from chat: $e');
      _setOutfitTryOnStatus(emit, outfitId, TryOnStatus.failed);
    }
  }

  pipeline.GeneratedOutfit? _findOutfitInMessages(
    List<ChatMessage> messages,
    String outfitId,
  ) {
    for (final m in messages) {
      if (m.type == ChatMessageType.outfitPreview &&
          m.outfitPreview?.outfit.id == outfitId) {
        return m.outfitPreview!.outfit;
      }
    }
    return null;
  }

  void _setOutfitTryOnStatus(
    Emitter<ChatState> emit,
    String outfitId,
    TryOnStatus status, {
    String? tryOnImageUrl,
  }) {
    final current = state;
    if (current is! ChatLoaded) return;

    final updated = current.messages.map((m) {
      if (m.type != ChatMessageType.outfitPreview ||
          m.outfitPreview?.outfit.id != outfitId) {
        return m;
      }
      return ChatMessage.outfit(
        m.outfitPreview!.copyWith(
          tryOnStatus: status,
          tryOnImageUrl: tryOnImageUrl ?? m.outfitPreview!.tryOnImageUrl,
        ),
      );
    }).toList();

    emit(current.copyWith(messages: updated));
  }

  void _updateLoadingPhase(Emitter<ChatState> emit, String phase) {
    final current = state;
    if (current is! ChatLoaded) return;
    final without = _withoutLoading(current.messages);
    emit(current.copyWith(messages: [...without, ChatMessage.loading(phase)]));
  }

  List<ChatMessage> _withoutStaleCta(List<ChatMessage> messages) {
    return messages
        .where((m) => m.type != ChatMessageType.ctaGenerate)
        .toList();
  }

  List<ChatMessage> _withoutLoading(List<ChatMessage> messages) {
    return messages
        .where((m) => m.type != ChatMessageType.generationLoading)
        .toList();
  }
}
