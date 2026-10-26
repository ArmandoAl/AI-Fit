import 'package:flutter/material.dart';
import 'app_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../../features/wardrobe/domain/wardrobe_item_model.dart';
import '../../features/wardrobe/domain/wardrobe_palette.dart';
import '../../features/wardrobe/presentation/pages/wardrobe_item_detail_page.dart';

class WardrobeItemCard extends StatelessWidget {
  final WardrobeItem item;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetryProcessing;

  const WardrobeItemCard({
    super.key,
    required this.item,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.onRetryProcessing,
  });

  String get _categoryLabel {
    if (item.type.isEmpty) return '';
    return WardrobePalette.labelType(item.type.toLowerCase());
  }

  String? get _brandLine {
    final brand = item.brand?.trim();
    if (brand != null && brand.isNotEmpty) return brand;
    return null;
  }

  String get _imageUrl {
    final cutout = item.cutoutPath?.trim();
    if (cutout != null && cutout.isNotEmpty) {
      return cutout;
    }
    final img = item.imageUrl.trim();
    if (img.isNotEmpty) {
      return img;
    }
    return item.sourcePath ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCutout =
        item.cutoutPath != null && item.cutoutPath!.trim().isNotEmpty;
    final isProcessing =
        item.processingStatus == 'processing' ||
        item.processingStatus == 'pending';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.ambientCardShadow,
        border: (isSelectionMode && isSelected)
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        elevation: 0,
        child: InkWell(
          onTap:
              onTap ??
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => WardrobeItemDetailPage(item: item),
                  ),
                );
              },
          onLongPress: onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: hasCutout
                          ? Colors.white
                          : AppColors.surfaceContainer,
                      child: AppNetworkImage(
                        imageUrl: _imageUrl,
                        fit: hasCutout ? BoxFit.contain : BoxFit.cover,
                        width: double.infinity,
                        placeholder: Container(
                          color: Colors.white,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                        errorWidget: Container(
                          color: AppColors.surfaceContainer,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.tertiary,
                          ),
                        ),
                      ),
                    ),
                    if (_categoryLabel.isNotEmpty)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _categoryLabel.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    if (isSelectionMode)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppColors.primary
                                : Colors.black.withValues(alpha: 0.55),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 15,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      )
                    else if (hasCutout)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_fix_high,
                            size: 14,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                    if (isProcessing)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.6),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.gold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Procesando recorte...',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (item.processingFailed && !isSelectionMode)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton(
                          tooltip: 'Reintentar procesamiento',
                          onPressed: onRetryProcessing,
                          icon: const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                color: AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_brandLine != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _brandLine!.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.secondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
