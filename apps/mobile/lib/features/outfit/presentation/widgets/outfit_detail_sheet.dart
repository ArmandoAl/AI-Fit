import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/l10n/app_strings_es.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../wardrobe/domain/wardrobe_palette.dart';
import '../../../wardrobe/domain/wardrobe_item_model.dart';
import '../../../wardrobe/presentation/bloc/wardrobe_bloc.dart';
import '../../../wardrobe/presentation/pages/wardrobe_item_detail_page.dart';
import '../../domain/saved_outfit_model.dart';
import '../bloc/saved_outfits_bloc.dart';
import '../bloc/saved_outfits_event.dart';

class OutfitDetailSheet {
  static void show(
    BuildContext context,
    SavedOutfit outfit, [
    List<SavedOutfit>? outfits,
  ]) {
    final available = outfits ?? [outfit];
    var selected = available.indexOf(outfit);
    AppBottomSheet.showDraggable(
      context: context,
      title: 'Detalle del look',
      subtitle: 'Look generado con tu armario',
      builder: (scrollController) => StatefulBuilder(
        builder: (context, setSheetState) {
          final current = available[selected];
          return GestureDetector(
            onHorizontalDragEnd: available.length < 2
                ? null
                : (details) {
                    final next =
                        selected + (details.primaryVelocity! < 0 ? 1 : -1);
                    if (next >= 0 && next < available.length) {
                      setSheetState(() => selected = next);
                    }
                  },
            child: ListView(
              key: ValueKey(current.id),
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                if (available.length > 1)
                  Center(
                    child: Text(
                      '${selected + 1} / ${available.length} · desliza para cambiar',
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        ),
                        child: Text(
                          AppStringsEs.matchPercent(current.matchPercentage),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        current.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: current.isFavorite
                            ? AppColors.primary
                            : AppColors.tertiary,
                      ),
                      onPressed: () {
                        context.read<SavedOutfitsBloc>().add(
                          ToggleFavorite(
                            outfitId: current.id,
                            isFavorite: !current.isFavorite,
                          ),
                        );
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (current.tryOnImageUrl.trim().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    child: AppNetworkImage(
                      imageUrl: current.tryOnImageUrl,
                      width: double.infinity,
                      height: 380,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        height: 380,
                        color: AppColors.surfaceContainer,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                      errorWidget: Container(
                        height: 380,
                        color: AppColors.surfaceContainer,
                        child: const Center(
                          child: Text('No se pudo cargar la imagen del look'),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 240,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: const Center(
                      child: Text('Este look no tiene imagen'),
                    ),
                  ),
                const SizedBox(height: 18),
                _WornItems(itemIds: current.outfit.itemIds),
                if (current.outfit.displayExplanation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    AppStringsEs.whyThisWorks,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    current.outfit.displayExplanation,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondary,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  AppStringsEs.tags,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (current.occasion != null &&
                        current.occasion!.isNotEmpty)
                      Chip(
                        label: Text(
                          WardrobePalette.labelOccasion(current.occasion!),
                        ),
                      ),
                    ...current.colors.map(
                      (c) => Chip(label: Text(WardrobePalette.labelColor(c))),
                    ),
                    ...current.styleTags.map(
                      (t) =>
                          Chip(label: Text(WardrobePalette.labelStyleTag(t))),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WornItems extends StatelessWidget {
  final List<String> itemIds;
  const _WornItems({required this.itemIds});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<WardrobeBloc>().state.allItems;
    final List<WardrobeItem> worn = itemIds
        .map((id) => items.where((item) => item.id == id).firstOrNull)
        .whereType<WardrobeItem>()
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prendas usadas (${itemIds.length})',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (worn.isEmpty)
          const Text('No se pudieron resolver las prendas de este look.'),
        for (final item in worn)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 48,
              height: 56,
              child: AppNetworkImage(
                imageUrl: item.displayImageUrl,
                fit: BoxFit.contain,
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
    );
  }
}
