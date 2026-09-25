import 'package:flutter/material.dart';
import 'app_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../../features/wardrobe/domain/wardrobe_item_model.dart';
import '../../features/wardrobe/domain/wardrobe_palette.dart';
import '../../features/wardrobe/presentation/pages/wardrobe_item_detail_page.dart';

class WardrobeItemCard extends StatelessWidget {
  final WardrobeItem item;
  /// Heurística: ayuda a reconocer y resolver errores. Se llama al tocar el
  /// badge de error cuando processingStatus == 'failed'.
  final VoidCallback? onRetryProcessing;

  const WardrobeItemCard({super.key, required this.item, this.onRetryProcessing});

  String get _categoryLabel {
    if (item.type.isEmpty) return '';
    return WardrobePalette.labelType(item.type.toLowerCase());
  }

  String? get _brandLine {
    final brand = item.brand?.trim();
    if (brand != null && brand.isNotEmpty) return brand;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => WardrobeItemDetailPage(item: item),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: (item.cutoutPath != null && item.cutoutPath!.isNotEmpty)
                          ? Colors.white
                          : AppColors.surfaceContainer,
                      child: AppNetworkImage(
                        imageUrl: item.displayImageUrl,
                        fit: (item.cutoutPath != null && item.cutoutPath!.isNotEmpty)
                            ? BoxFit.contain
                            : BoxFit.cover,
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
                    if (item.cutoutPath != null && item.cutoutPath!.isNotEmpty)
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
                      )
                    else if (item.isProcessing)
                      const Positioned(
                        top: 10,
                        right: 10,
                        child: _StatusBadge(
                          icon: null,
                          color: AppColors.secondary,
                          isSpinner: true,
                        ),
                      )
                    else if (item.processingFailed)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: onRetryProcessing,
                          child: const _StatusBadge(
                            icon: Icons.error_outline,
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

/// Badge circular para estado de procesamiento (spinner) o error (tocable, con
/// tooltip explicando que se puede reintentar).
class _StatusBadge extends StatelessWidget {
  final IconData? icon;
  final Color color;
  final bool isSpinner;

  const _StatusBadge({required this.icon, required this.color, this.isSpinner = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isSpinner
          ? 'Procesando prenda…'
          : 'No se pudo procesar esta prenda. Toca para reintentar.',
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
          ],
        ),
        child: isSpinner
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary),
              )
            : Icon(icon, size: 14, color: color),
      ),
    );
  }
}
