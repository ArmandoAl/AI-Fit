import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/l10n/app_strings_es.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/utils/keyboard_utils.dart';
import '../../../../core/widgets/app_page_app_bar.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/shell_bottom_insets.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../../domain/chat_models.dart';
import '../../../outfit/presentation/bloc/saved_outfits_bloc.dart';
import '../../../outfit/presentation/bloc/saved_outfits_event.dart';
import '../../../outfit/presentation/bloc/saved_outfits_state.dart';
import '../widgets/stylist_chat_bubble.dart';
import '../widgets/stylist_generate_cta_card.dart';
import '../widgets/stylist_generation_loading_card.dart';
import '../widgets/stylist_outfit_carousel.dart';
import '../widgets/stylist_outfit_preview_card.dart';
import '../widgets/stylist_typing_indicator.dart';
import '../../../wardrobe/presentation/bloc/wardrobe_bloc.dart';
import '../../../wardrobe/presentation/pages/wardrobe_item_detail_page.dart';

/// Ítem normalizado para el ListView del chat (agrupa outfits en carrusel).
sealed class _ChatListEntry {}

class _ChatMessageEntry extends _ChatListEntry {
  final ChatMessage message;
  _ChatMessageEntry(this.message);
}

class _ChatOutfitCarouselEntry extends _ChatListEntry {
  final List<ChatOutfitPreview> previews;
  _ChatOutfitCarouselEntry(this.previews);
}

class StylistPage extends StatefulWidget {
  const StylistPage({super.key});

  @override
  State<StylistPage> createState() => _StylistPageState();
}

class _StylistPageState extends State<StylistPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ChatAttachment? _attachment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<ChatBloc>();
      if (bloc.state is ChatInitial) {
        bloc.add(const ChatSessionStarted());
      }
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    hideKeyboard();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatBloc, ChatState>(
      listenWhen: (prev, curr) =>
          curr is ChatLoaded &&
          (prev is! ChatLoaded ||
              prev.messages.length != curr.messages.length ||
              prev.isTyping != curr.isTyping),
      listener: (_, __) => _scrollToBottom(),
      child: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          if (state is! ChatLoaded) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildScaffold(context, state);
        },
      ),
    );
  }

  List<_ChatListEntry> _normalizeMessages(List<ChatMessage> messages) {
    final entries = <_ChatListEntry>[];
    var i = 0;
    while (i < messages.length) {
      final msg = messages[i];
      if (msg.type == ChatMessageType.outfitPreview &&
          msg.outfitPreview != null) {
        final group = <ChatOutfitPreview>[];
        while (i < messages.length &&
            messages[i].type == ChatMessageType.outfitPreview &&
            messages[i].outfitPreview != null) {
          group.add(messages[i].outfitPreview!);
          i++;
        }
        entries.add(_ChatOutfitCarouselEntry(group));
      } else {
        entries.add(_ChatMessageEntry(msg));
        i++;
      }
    }
    return entries;
  }

  Widget _buildScaffold(BuildContext context, ChatLoaded state) {
    final entries = _normalizeMessages(state.messages);
    final itemCount = entries.length + (state.isTyping ? 1 : 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppPageAppBar(
        title: AppStringsEs.aiStylist,
        subtitle: AppStringsEs.premiumStyling,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => context.push('/generate-outfit'),
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Quick generate (prompt)',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            tooltip: 'More options',
            onSelected: (value) {
              switch (value) {
                case 'saved':
                  context.push('/saved-outfits');
                  break;
                case 'quick':
                  context.push('/generate-outfit');
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'saved',
                child: Row(
                  children: [
                    Icon(Icons.checkroom_outlined, size: 22),
                    SizedBox(width: 12),
                    Text(AppStringsEs.savedOutfits),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'quick',
                child: Row(
                  children: [
                    Icon(Icons.edit_note_outlined, size: 22),
                    SizedBox(width: 12),
                    Text(AppStringsEs.quickGenerate),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(
                top: 12,
                bottom: ShellBottomInsets.scrollPadding(context),
              ),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (state.isTyping && index == entries.length) {
                  return const StylistTypingIndicator();
                }
                final entry = entries[index];
                return _AnimatedMessage(
                  key: ValueKey(_entryKey(entry, index)),
                  index: index,
                  child: _buildEntry(context, entry, state),
                );
              },
            ),
          ),
          _buildInput(context, state),
        ],
      ),
    );
  }

  String _entryKey(_ChatListEntry entry, int index) {
    return switch (entry) {
      _ChatMessageEntry(:final message) => message.id,
      _ChatOutfitCarouselEntry(:final previews) =>
        'carousel_${previews.map((p) => p.outfit.id).join('_')}_$index',
    };
  }

  Widget _buildEntry(
    BuildContext context,
    _ChatListEntry entry,
    ChatLoaded state,
  ) {
    return switch (entry) {
      _ChatOutfitCarouselEntry(:final previews) => StylistOutfitCarousel(
        previews: previews,
        onPreviewTap: (p) => _showOutfitSheet(context, p, previews),
      ),
      _ChatMessageEntry(:final message) => _buildMessage(
        context,
        message,
        state,
      ),
    };
  }

  Widget _buildMessage(
    BuildContext context,
    ChatMessage msg,
    ChatLoaded state,
  ) {
    switch (msg.type) {
      case ChatMessageType.text:
      case ChatMessageType.generationError:
        return Column(
          children: [
            if (msg.attachment != null)
              _AttachmentPreview(attachment: msg.attachment!),
            StylistChatBubble(message: msg),
          ],
        );
      case ChatMessageType.ctaGenerate:
        return StylistGenerateCtaCard(
          isLoading: state.isGenerating,
          onGenerate: () => context.read<ChatBloc>().add(
            const ChatGenerateOutfitRequested(generateTryOn: false),
          ),
        );
      case ChatMessageType.generationLoading:
        return StylistGenerationLoadingCard(phase: msg.generationPhase);
      case ChatMessageType.outfitPreview:
        if (msg.outfitPreview == null) return const SizedBox.shrink();
        return StylistOutfitCarousel(
          previews: [msg.outfitPreview!],
          onPreviewTap: (p) => _showOutfitSheet(context, p, [p]),
        );
      case ChatMessageType.typing:
        return const StylistTypingIndicator();
    }
  }

  void _requestTryOn(BuildContext context, ChatOutfitPreview preview) {
    context.read<ChatBloc>().add(
      ChatTryOnForOutfitRequested(preview.outfit.id),
    );
  }

  void _showOutfitSheet(
    BuildContext context,
    ChatOutfitPreview preview,
    List<ChatOutfitPreview> previews,
  ) {
    var selected = previews.indexOf(preview);
    AppBottomSheet.showDraggable(
      context: context,
      title: AppStringsEs.lookDetails,
      subtitle: 'Seleccionado para tu armario',
      builder: (scrollController) => StatefulBuilder(
        builder: (context, setSheetState) {
          final selectedPreview = previews[selected];
          final chatState = context.watch<ChatBloc>().state;
          final current = chatState is ChatLoaded
              ? chatState.messages
                        .where(
                          (message) =>
                              message.outfitPreview?.outfit.id ==
                              selectedPreview.outfit.id,
                        )
                        .map((message) => message.outfitPreview!)
                        .firstOrNull ??
                    selectedPreview
              : selectedPreview;
          return GestureDetector(
            onHorizontalDragEnd: previews.length < 2
                ? null
                : (details) {
                    final next =
                        selected + (details.primaryVelocity! < 0 ? 1 : -1);
                    if (next >= 0 && next < previews.length) {
                      setSheetState(() => selected = next);
                    }
                  },
            child: ListView(
              key: ValueKey(current.outfit.id),
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
              children: [
                if (previews.length > 1)
                  Center(
                    child: Text(
                      '${selected + 1} / ${previews.length} · desliza para cambiar',
                    ),
                  ),
                _OutfitGarments(preview: current),
                StylistOutfitPreviewCard(
                  preview: current,
                  compact: false,
                  onTryOnRequest: () => _requestTryOn(context, current),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInput(BuildContext context, ChatLoaded state) {
    final disabled = state.isTyping || state.isGenerating;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Adjuntar prenda o look',
              onPressed: disabled ? null : _chooseAttachment,
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_attachment != null)
                    _AttachmentPreview(
                      attachment: _attachment!,
                      onRemove: () => setState(() => _attachment = null),
                    ),
                  TextField(
                    controller: _controller,
                    enabled: !disabled,
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: AppStringsEs.describeOccasionHint,
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: AppColors.gold),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: disabled ? null : (_) => _sendMessage(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                onTap: disabled ? null : _sendMessage,
                borderRadius: BorderRadius.circular(28),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.arrow_upward, color: AppColors.onPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachment == null) return;
    context.read<ChatBloc>().add(
      ChatMessageSent(text, attachment: _attachment),
    );
    _controller.clear();
    setState(() => _attachment = null);
  }

  Future<void> _chooseAttachment() async {
    final wardrobe = context.read<WardrobeBloc>().state.allItems;
    final savedBloc = context.read<SavedOutfitsBloc>();
    if (savedBloc.state is! SavedOutfitsLoaded) {
      savedBloc.add(LoadSavedOutfits());
    }
    final selected = await showModalBottomSheet<ChatAttachment>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DefaultTabController(
        length: 2,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.65,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Prendas'),
                  Tab(text: 'Looks'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      children: [
                        for (final item in wardrobe)
                          ListTile(
                            leading: SizedBox(
                              width: 44,
                              height: 52,
                              child: AppNetworkImage(
                                imageUrl: item.displayImageUrl,
                                fit: BoxFit.contain,
                              ),
                            ),
                            title: Text(item.name),
                            subtitle: Text(item.subType),
                            onTap: () => Navigator.pop(
                              sheetContext,
                              ChatAttachment(
                                title: item.name,
                                imageUrl: item.displayImageUrl,
                                description:
                                    'Prenda del armario: ${item.name}; tipo ${item.subType}; categoría ${item.type}; colores ${item.colors.join(', ')}; marca ${item.brand ?? 'sin marca'}.',
                              ),
                            ),
                          ),
                      ],
                    ),
                    BlocBuilder<SavedOutfitsBloc, SavedOutfitsState>(
                      bloc: savedBloc,
                      builder: (_, state) => state is SavedOutfitsLoaded
                          ? ListView(
                              children: [
                                for (final outfit in state.outfits)
                                  ListTile(
                                    leading: SizedBox(
                                      width: 44,
                                      height: 52,
                                      child: AppNetworkImage(
                                        imageUrl: outfit.tryOnImageUrl,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    title: Text(
                                      'Look · ${outfit.occasion ?? 'personal'}',
                                    ),
                                    subtitle: Text(
                                      '${outfit.outfit.itemIds.length} prendas · ${outfit.matchPercentage}%',
                                    ),
                                    onTap: () => Navigator.pop(
                                      sheetContext,
                                      ChatAttachment(
                                        title: 'Look guardado',
                                        imageUrl: outfit.tryOnImageUrl,
                                        description: () {
                                          final pieces = wardrobe
                                              .where(
                                                (item) => outfit.outfit.itemIds
                                                    .contains(item.id),
                                              )
                                              .map(
                                                (item) =>
                                                    '${item.name} (${item.subType}, ${item.colors.join('/')})',
                                              )
                                              .join(', ');
                                          return 'Look guardado para ${outfit.occasion ?? 'uso personal'}; prendas: ${pieces.isEmpty ? outfit.outfit.itemIds.length : pieces}; estilo ${outfit.styleTags.join(', ')}; colores ${outfit.colors.join(', ')}.';
                                        }(),
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _attachment = selected);
  }
}

class _AttachmentPreview extends StatelessWidget {
  final ChatAttachment attachment;
  final VoidCallback? onRemove;
  const _AttachmentPreview({required this.attachment, this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 44,
          height: 48,
          child: AppNetworkImage(
            imageUrl: attachment.imageUrl,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            attachment.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onRemove != null)
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
          ),
      ],
    ),
  );
}

class _OutfitGarments extends StatelessWidget {
  final ChatOutfitPreview preview;

  const _OutfitGarments({required this.preview});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WardrobeBloc>().state;
    final items = state.allItems
        .where((item) => preview.outfit.itemIds.contains(item.id))
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prendas elegidas (${preview.outfit.itemIds.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('No se pudieron resolver las prendas del armario.'),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 48,
                height: 56,
                child: AppNetworkImage(
                  imageUrl: item.displayImageUrl,
                  fit: BoxFit.contain,
                  errorWidget: const Icon(Icons.checkroom_outlined),
                ),
              ),
              title: Text(item.name),
              subtitle: Text(item.subType),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WardrobeItemDetailPage(item: item),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimatedMessage extends StatelessWidget {
  final Widget child;
  final int index;

  const _AnimatedMessage({super.key, required this.child, required this.index});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index % 3) * 40),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
