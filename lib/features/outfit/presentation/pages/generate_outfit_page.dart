import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/l10n/app_strings_es.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/keyboard_utils.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/app_page_app_bar.dart';
import '../../../../core/widgets/atelier_section_header.dart';
import '../../../../core/widgets/cold_start_loader.dart';
import '../bloc/outfit_generation_bloc.dart';
import '../bloc/outfit_generation_event.dart';
import '../bloc/outfit_generation_state.dart';
import '../../domain/outfit_models.dart';
import '../../domain/try_on_status.dart';
import '../../../stylist/domain/chat_models.dart' as chat_models;

/// Página para generar outfits usando IA
class GenerateOutfitPage extends StatefulWidget {
  const GenerateOutfitPage({super.key});

  @override
  State<GenerateOutfitPage> createState() => _GenerateOutfitPageState();
}

class _GenerateOutfitPageState extends State<GenerateOutfitPage> {
  final TextEditingController _promptController = TextEditingController();
  // Heurística: visibilidad del estado del sistema — activado por default para
  // que el usuario vea su try-on sin tener que descubrir este switch primero.
  bool _generateImage = true;

  @override
  void dispose() {
    hideKeyboard();
    _promptController.dispose();
    super.dispose();
  }

  void _generateOutfits() {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStringsEs.enterOutfitDescription),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    context.read<OutfitGenerationBloc>().add(
      GenerateOutfitsRequested(
        userPrompt: prompt,
        generateImage: _generateImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppSubpageAppBar(
        title: AppStringsEs.generateOutfitTitle,
        subtitle: AppStringsEs.generateOutfitSubtitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.checkroom_outlined),
            tooltip: AppStringsEs.savedOutfits,
            onPressed: () => context.push('/saved-outfits'),
          ),
        ],
      ),
      body: BlocListener<OutfitGenerationBloc, OutfitGenerationState>(
        listener: (context, state) {
          if (state is OutfitGenerationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppStringsEs.errorWith(state.message)),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 4),
              ),
            );
          } else if (state is OutfitGenerationLoaded) {
            if (state.outfits.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'No se pudieron generar looks. Prueba otra descripción.',
                  ),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
        child: BlocBuilder<OutfitGenerationBloc, OutfitGenerationState>(
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AtelierSectionHeader(
                    kicker: 'Composición',
                    title: AppStringsEs.describeOutfitWant,
                    subtitle:
                        'Ejemplo: “cena de verano, lino y paleta tierra” o “look formal para una boda”.',
                  ),
                  const SizedBox(height: 24),

                  // Prompt Input
                  TextField(
                    controller: _promptController,
                    decoration: InputDecoration(
                      labelText: AppStringsEs.outfitDescription,
                      hintText: 'ej. look casual de fin de semana',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.auto_awesome),
                      suffixIcon: _promptController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _promptController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    enabled: state is! OutfitGenerationLoading,
                  ),
                  const SizedBox(height: 16),

                  // Generate Image Toggle — prominente y activado por default
                  // (heurística: visibilidad del estado del sistema).
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _generateImage
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: SwitchListTile(
                      secondary: Icon(
                        Icons.auto_awesome,
                        color: _generateImage
                            ? AppColors.primary
                            : AppColors.secondary,
                      ),
                      title: const Text(AppStringsEs.generatePreviewImage),
                      subtitle: const Text(AppStringsEs.generatePreviewSubtitle),
                      value: _generateImage,
                      onChanged: state is OutfitGenerationLoading
                          ? null
                          : (value) {
                              setState(() {
                                _generateImage = value;
                              });
                            },
                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Generate Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: state is OutfitGenerationLoading
                          ? null
                          : _generateOutfits,
                      icon: state is OutfitGenerationLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        state is OutfitGenerationLoading
                            ? _getLoadingText(state)
                            : AppStringsEs.generateOutfitsButton,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                  // Loading Indicator
                  if (state is OutfitGenerationLoading) ...[
                    const SizedBox(height: 32),
                    _buildLoadingIndicator(state),
                  ],

                  // Results
                  if (state is OutfitGenerationLoaded) ...[
                    const SizedBox(height: 32),
                    _buildResults(state),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _getLoadingText(OutfitGenerationLoading state) {
    switch (state.currentPhase) {
      case 'analyzing':
        return AppStringsEs.analyzingRequest;
      case 'filtering':
        return AppStringsEs.filteringWardrobe;
      case 'generating':
        return AppStringsEs.generatingOutfits;
      case 'creating_image':
        return AppStringsEs.creatingPreview;
      default:
        return AppStringsEs.processing;
    }
  }

  Widget _buildLoadingIndicator(OutfitGenerationLoading state) {
    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          _getLoadingText(state),
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildResults(OutfitGenerationLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStringsEs.generatedOutfits,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...state.outfits.asMap().entries.map((entry) {
          final index = entry.key;
          final outfit = entry.value;
          return _buildOutfitCard(
            context,
            state,
            outfit,
            index + 1,
          );
        }),
      ],
    );
  }

  Widget _buildOutfitCard(
    BuildContext context,
    OutfitGenerationLoaded state,
    GeneratedOutfit outfit,
    int index,
  ) {
    final tryOnImageUrl = state.getImageUrlForOutfit(outfit.id);
    final status = state.statusFor(outfit.id);
    final error = state.tryOnErrors[outfit.id];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Outfit $index',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppStringsEs.matchPercent(outfit.matchPercentage),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildTryOnSection(
              context: context,
              outfitId: outfit.id,
              imageUrl: tryOnImageUrl,
              status: status,
              error: error,
            ),
            const SizedBox(height: 16),

            // Explanation
            Text(
              outfit.displayExplanation,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Items
            if (outfit.itemIds.isNotEmpty) ...[
              const Text(
                'Prendas:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: outfit.itemIds.map((itemId) {
                  return Chip(
                    label: Text(
                      itemId.substring(0, 8),
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.grey[200],
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Convertir GeneratedOutfit (outfit_models) a formato compatible con chat_models
                      final chatOutfit = chat_models.GeneratedOutfit(
                        id: outfit.id,
                        matchPercentage: outfit.matchPercentage,
                        itemIds: outfit.itemIds,
                        imageUrl: tryOnImageUrl ?? '',
                      );

                      context.push('/outfit-result', extra: chatOutfit);
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('Ver detalle'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _canRequestTryOn(status)
                        ? () {
                            context.read<OutfitGenerationBloc>().add(
                                  GenerateTryOnImageRequested(
                                    outfitId: outfit.id,
                                  ),
                                );
                          }
                        : null,
                    icon: Icon(_tryOnButtonIcon(status)),
                    label: Text(_tryOnButtonLabel(status)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _canRequestTryOn(TryOnStatus status) {
    return status == TryOnStatus.readyForTryOn ||
        status == TryOnStatus.failed ||
        status == TryOnStatus.none;
  }

  IconData _tryOnButtonIcon(TryOnStatus status) {
    return switch (status) {
      TryOnStatus.generating => Icons.hourglass_top,
      TryOnStatus.ready => Icons.check_circle_outline,
      _ => Icons.image,
    };
  }

  String _tryOnButtonLabel(TryOnStatus status) {
    return switch (status) {
      TryOnStatus.generating => 'Generando…',
      TryOnStatus.ready => 'Vista lista',
      TryOnStatus.readyForTryOn => 'Try-on',
      TryOnStatus.failed => 'Reintentar',
      TryOnStatus.none => 'Try-on',
    };
  }

  Widget _buildTryOnSection({
    required BuildContext context,
    required String outfitId,
    required String? imageUrl,
    required TryOnStatus status,
    required String? error,
  }) {
    if (status == TryOnStatus.ready &&
        imageUrl != null &&
        imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AppNetworkImage(
          imageUrl: imageUrl,
          width: double.infinity,
          height: 300,
          fit: BoxFit.cover,
          placeholder: Container(
            height: 300,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: Container(
            height: 300,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.error_outline, size: 48),
            ),
          ),
        ),
      );
    }

    if (status == TryOnStatus.generating) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: const Center(
          child: ColdStartProgressIndicator(),
        ),
      );
    }

    if (status == TryOnStatus.readyForTryOn) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.25),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.secondary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Listo para try-on — pulsa el botón para generar la vista.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (status == TryOnStatus.failed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          error ?? 'No se pudo generar la vista',
          style: const TextStyle(color: AppColors.error, fontSize: 13),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
