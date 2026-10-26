import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/l10n/app_strings_es.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_page_app_bar.dart';
import '../../../../core/widgets/atelier_empty_state.dart';
import '../../../../core/widgets/saved_outfit_card.dart';
import '../bloc/saved_outfits_bloc.dart';
import '../bloc/saved_outfits_event.dart';
import '../bloc/saved_outfits_state.dart';
import '../widgets/outfit_detail_sheet.dart';
import '../../../wardrobe/domain/wardrobe_palette.dart';

/// Página para mostrar outfits guardados
class SavedOutfitsPage extends StatefulWidget {
  const SavedOutfitsPage({super.key});

  @override
  State<SavedOutfitsPage> createState() => _SavedOutfitsPageState();
}

class _SavedOutfitsPageState extends State<SavedOutfitsPage> {
  String? _selectedOccasion;
  String? _selectedSeason;
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    // Cargar outfits al iniciar
    context.read<SavedOutfitsBloc>().add(LoadSavedOutfits());
  }

  void _applyFilters() {
    context.read<SavedOutfitsBloc>().add(
      LoadSavedOutfits(
        filterByOccasion: _selectedOccasion,
        filterBySeason: _selectedSeason,
        onlyFavorites: _showFavoritesOnly ? true : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppSubpageAppBar(
        title: AppStringsEs.myOutfits,
        subtitle: 'Historial de try-on',
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            tooltip: 'Filters',
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: BlocBuilder<SavedOutfitsBloc, SavedOutfitsState>(
        builder: (context, state) {
          if (state is SavedOutfitsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SavedOutfitsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${state.message}',
                    style: const TextStyle(color: AppColors.error),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<SavedOutfitsBloc>().add(LoadSavedOutfits());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is SavedOutfitsLoaded) {
            if (state.outfits.isEmpty) {
              return const AtelierEmptyState(
                icon: Icons.checkroom_outlined,
                title: 'Aún no hay looks',
                subtitle:
                    'Genera outfits con el atelier y aparecerán aquí como un lookbook personal.',
              );
            }

            return Column(
              children: [
                // Filtros activos
                if (state.filterSummary.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: AppColors.primary.withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Filters: ${state.filterSummary.values.join(', ')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedOccasion = null;
                              _selectedSeason = null;
                              _showFavoritesOnly = false;
                            });
                            _applyFilters();
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                ],

                // Grid de outfits
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.72,
                        ),
                    itemCount: state.outfits.length,
                    itemBuilder: (context, index) {
                      final outfit = state.outfits[index];
                      return SavedOutfitCard(
                        outfit: outfit,
                        onTap: () {
                          context.read<SavedOutfitsBloc>().add(
                            ViewOutfit(outfitId: outfit.id),
                          );
                          OutfitDetailSheet.show(
                            context,
                            outfit,
                            state.outfits,
                          );
                        },
                        onToggleFavorite: () {
                          context.read<SavedOutfitsBloc>().add(
                            ToggleFavorite(
                              outfitId: outfit.id,
                              isFavorite: !outfit.isFavorite,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Outfits'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Occasion
                DropdownButtonFormField<String>(
                  initialValue: _selectedOccasion,
                  decoration: const InputDecoration(
                    labelText: 'Ocasión',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(AppStringsEs.filterAll),
                    ),
                    DropdownMenuItem(
                      value: 'casual',
                      child: Text(WardrobePalette.labelOccasion('casual')),
                    ),
                    DropdownMenuItem(
                      value: 'formal',
                      child: Text(WardrobePalette.labelOccasion('formal')),
                    ),
                    DropdownMenuItem(
                      value: 'sport',
                      child: Text(WardrobePalette.labelOccasion('sport')),
                    ),
                    DropdownMenuItem(
                      value: 'party',
                      child: Text(WardrobePalette.labelOccasion('party')),
                    ),
                    DropdownMenuItem(
                      value: 'work',
                      child: Text(WardrobePalette.labelOccasion('work')),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedOccasion = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Season
                DropdownButtonFormField<String>(
                  initialValue: _selectedSeason,
                  decoration: const InputDecoration(
                    labelText: AppStringsEs.season,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(AppStringsEs.filterAll),
                    ),
                    DropdownMenuItem(
                      value: 'spring',
                      child: Text(WardrobePalette.labelSeason('spring')),
                    ),
                    DropdownMenuItem(
                      value: 'summer',
                      child: Text(WardrobePalette.labelSeason('summer')),
                    ),
                    DropdownMenuItem(
                      value: 'fall',
                      child: Text(WardrobePalette.labelSeason('fall')),
                    ),
                    DropdownMenuItem(
                      value: 'winter',
                      child: Text(WardrobePalette.labelSeason('winter')),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedSeason = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Favorites only
                CheckboxListTile(
                  title: const Text('Favorites only'),
                  value: _showFavoritesOnly,
                  onChanged: (value) {
                    setState(() {
                      _showFavoritesOnly = value ?? false;
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyFilters();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
