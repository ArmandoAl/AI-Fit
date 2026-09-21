import 'package:flutter/material.dart';
import '../../../../core/l10n/app_strings_es.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/cold_start_loader.dart';
import '../../../outfit/domain/try_on_status.dart';
import '../../domain/chat_models.dart';

class StylistOutfitPreviewCard extends StatelessWidget {
  final ChatOutfitPreview preview;
  final VoidCallback? onTap;
  final VoidCallback? onTryOnRequest;
  final bool compact;

  const StylistOutfitPreviewCard({
    super.key,
    required this.preview,
    this.onTap,
    this.onTryOnRequest,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompactCard(context);
    return _buildFullCard(context);
  }

  Widget _buildCompactCard(BuildContext context) {
    final imageUrl = preview.tryOnImageUrl ?? '';
    final hasImage = imageUrl.isNotEmpty;
    final score = preview.outfit.matchPercentage;

    return Material(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  hasImage
                      ? AppNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: const _ShimmerBox(),
                          errorWidget: const _PlaceholderImage(),
                        )
                      : const _PlaceholderImage(),
                  _TryOnStatusOverlay(
                    status: preview.tryOnStatus,
                    onTryOnRequest: onTryOnRequest,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppStringsEs.curatedLook,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$score%',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (preview.outfit.displayExplanation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          preview.outfit.displayExplanation,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.25,
                                    fontSize: 11,
                                  ),
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        Text(
                          AppStringsEs.piecesShort(preview.outfit.itemIds.length),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.open_in_full_rounded,
                          size: 14,
                          color: AppColors.primary.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullCard(BuildContext context) {
    final imageUrl = preview.tryOnImageUrl ?? '';
    final hasImage = imageUrl.isNotEmpty;
    final score = preview.outfit.matchPercentage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    hasImage
                        ? AppNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: const _ShimmerBox(),
                            errorWidget: const _PlaceholderImage(),
                          )
                        : const _PlaceholderImage(),
                    _TryOnStatusOverlay(
                      status: preview.tryOnStatus,
                      onTryOnRequest: onTryOnRequest,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppStringsEs.curatedLook,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            AppStringsEs.matchPercent(score),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (preview.outfit.displayExplanation.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        preview.outfit.displayExplanation,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      AppStringsEs.piecesFromWardrobe(
                        preview.outfit.itemIds.length,
                      ),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
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

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: Icon(Icons.checkroom_outlined, size: 40, color: Colors.grey),
      ),
    );
  }
}

class _TryOnStatusOverlay extends StatelessWidget {
  final TryOnStatus status;
  final VoidCallback? onTryOnRequest;

  const _TryOnStatusOverlay({
    required this.status,
    this.onTryOnRequest,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case TryOnStatus.generating:
        return Container(
          color: Colors.black54,
          padding: const EdgeInsets.all(8),
          child: const Center(
            child: ColdStartProgressIndicator(
              initialMessage: 'Generando vista…',
              coldStartMessage: 'Despertando vestidor… ✨',
              prolongedMessage: 'Preparando percheros… 🦇',
              spinnerColor: AppColors.neonMint,
              textStyle: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      case TryOnStatus.readyForTryOn:
      case TryOnStatus.failed:
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: onTryOnRequest,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    status == TryOnStatus.failed
                        ? 'Reintentar try-on'
                        : 'Generar try-on',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
