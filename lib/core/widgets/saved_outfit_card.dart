import 'package:flutter/material.dart';
import '../../features/outfit/domain/saved_outfit_model.dart';
import '../../features/wardrobe/domain/wardrobe_palette.dart';
import '../l10n/app_strings_es.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_network_image.dart';

/// Card para mostrar un look u outfit guardado en un grid.
class SavedOutfitCard extends StatelessWidget {
  final SavedOutfit outfit;
  final VoidCallback onTap;
  final VoidCallback? onToggleFavorite;

  const SavedOutfitCard({
    super.key,
    required this.outfit,
    required this.onTap,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.ambientCardShadow,
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Imagen del outfit generado
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (outfit.tryOnImageUrl.trim().isNotEmpty)
                      AppNetworkImage(
                        imageUrl: outfit.tryOnImageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: AppColors.surfaceContainer,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                        errorWidget: Container(
                          color: AppColors.surfaceContainer,
                          child: const Center(
                            child: Icon(
                              Icons.auto_awesome,
                              color: AppColors.tertiary,
                              size: 28,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: AppColors.surfaceContainer,
                        child: const Center(
                          child: Icon(
                            Icons.auto_awesome,
                            color: AppColors.gold,
                            size: 32,
                          ),
                        ),
                      ),

                    // Botón flotante de favorito (arriba a la derecha)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onToggleFavorite,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              outfit.isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: outfit.isFavorite
                                  ? AppColors.primary
                                  : Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Pie de la tarjeta con porcentaje de coincidencia y etiquetas
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: Text(
                              AppStringsEs.matchPercent(outfit.matchPercentage),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (outfit.occasion != null &&
                            outfit.occasion!.trim().isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMd),
                              ),
                              child: Text(
                                WardrobePalette.labelOccasion(outfit.occasion!),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 9.5,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
