import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/platform/app_image.dart';
import '../../../../core/services/worker_warmup_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/luxury_bottom_sheet.dart';
import '../../../../core/widgets/shell_bottom_insets.dart';
import '../../../../core/widgets/app_page_app_bar.dart';
import '../../../../core/widgets/atelier_empty_state.dart';
import '../../../../core/widgets/wardrobe_item_card.dart';
import '../../../../core/widgets/saved_outfit_card.dart';
import '../../../../core/l10n/app_strings_es.dart';
import '../../../outfit/presentation/bloc/saved_outfits_bloc.dart';
import '../../../outfit/presentation/bloc/saved_outfits_event.dart';
import '../../../outfit/presentation/bloc/saved_outfits_state.dart';
import '../../../outfit/presentation/widgets/outfit_detail_sheet.dart';
import '../../../wardrobe/domain/wardrobe_item_model.dart';
import '../../../wardrobe/domain/wardrobe_palette.dart';
import '../bloc/wardrobe_bloc.dart';
import '../bloc/wardrobe_event.dart';
import '../bloc/wardrobe_state.dart';
import 'add_wardrobe_item_page.dart';

enum _WardrobeTab { clothes, looks }

class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  static const int _warmupDurationSeconds = 15;
  bool _isWarmingUp = true;
  int _remainingSeconds = _warmupDurationSeconds;
  Timer? _warmupTimer;
  _WardrobeTab _selectedTab = _WardrobeTab.clothes;
  bool _isSelectionMode = false;
  final Set<String> _selectedItemIds = {};

  static const _filterKeys = [
    'All',
    'top',
    'bottom',
    'one_piece',
    'shoes',
    'outerwear',
    'accessories',
  ];

  static String _filterLabel(String key) {
    if (key == 'All') return AppStringsEs.filterAll;
    return WardrobePalette.labelType(key);
  }

  void _onItemLongPress(String itemId) {
    setState(() {
      _isSelectionMode = true;
      if (!_selectedItemIds.add(itemId)) _selectedItemIds.remove(itemId);
    });
  }

  void _onItemTap(String itemId) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedItemIds.contains(itemId)) {
          _selectedItemIds.remove(itemId);
        } else {
          _selectedItemIds.add(itemId);
        }
      });
    }
  }

  Future<void> _deleteSelectedItems() async {
    if (_selectedItemIds.isEmpty) return;
    final count = _selectedItemIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          count == 1 ? '¿Eliminar prenda?' : '¿Eliminar $count prendas?',
        ),
        content: const Text(
          'Esta acción eliminará las prendas seleccionadas de tu armario de forma permanente.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final idsToDelete = _selectedItemIds.toList();
      try {
        await context.read<WardrobeBloc>().deleteItems(idsToDelete);
        if (!mounted) return;
        setState(() {
          _isSelectionMode = false;
          _selectedItemIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count == 1 ? 'Prenda eliminada' : '$count prendas eliminadas',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron eliminar las prendas: $e')),
        );
      }
    }
  }

  Future<void> _retryItem(BuildContext context, WardrobeItem item) async {
    try {
      await context.read<WardrobeBloc>().repository.retryProcessing(item);
      if (context.mounted) {
        context.read<WardrobeBloc>().add(const LoadWardrobeItems());
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo reprocesar: $e')));
      }
    }
  }

  SavedOutfitsBloc? _getSavedOutfitsBloc(BuildContext context) {
    try {
      return BlocProvider.of<SavedOutfitsBloc>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    // Invocación estratégica de warmup y carga de datos
    WorkerWarmupService.warmUp();
    _startWarmupTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _getSavedOutfitsBloc(context)?.add(LoadSavedOutfits());
      }
    });
  }

  void _startWarmupTimer() {
    _isWarmingUp = true;
    _remainingSeconds = _warmupDurationSeconds;
    _warmupTimer?.cancel();
    _warmupTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _isWarmingUp = false;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _warmupTimer?.cancel();
    super.dispose();
  }

  void _onAddButtonPressed(BuildContext context) {
    if (_isWarmingUp) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Preparando motor de imagen... listo en $_remainingSeconds s',
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      );
      return;
    }
    _showImageSourceDialog(context);
  }

  Future<void> _showImageSourceDialog(BuildContext context) async {
    await LuxuryBottomSheet.show(
      context: context,
      title: AppStringsEs.addToWardrobe,
      subtitle: AppStringsEs.addToWardrobeSubtitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LuxurySheetAction(
            animationIndex: 0,
            icon: Icons.photo_library_outlined,
            title: AppStringsEs.chooseGallery,
            subtitle: AppStringsEs.chooseGallerySubtitle,
            onTap: () async {
              final navigator = Navigator.of(context);
              navigator.pop();

              final picker = ImagePicker();
              final images = await picker.pickMultiImage(
                maxWidth: 1600,
                maxHeight: 1600,
                imageQuality: 85,
              );

              if (images.isNotEmpty && context.mounted) {
                final initial = await AppImage.fromXFiles(images);
                if (!context.mounted) return;
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) =>
                        AddWardrobeItemPage(initialImages: initial),
                  ),
                );
              }
            },
          ),
          LuxurySheetAction(
            animationIndex: 1,
            icon: Icons.camera_alt_outlined,
            title: AppStringsEs.takePhoto,
            subtitle: AppStringsEs.takePhotoSubtitle,
            onTap: () async {
              final navigator = Navigator.of(context);
              navigator.pop();

              final picker = ImagePicker();
              final image = await picker.pickImage(
                source: ImageSource.camera,
                maxWidth: 1600,
                maxHeight: 1600,
                imageQuality: 85,
              );

              if (image != null && context.mounted) {
                final initial = await AppImage.fromXFile(image);
                if (!context.mounted) return;
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) =>
                        AddWardrobeItemPage(initialImages: [initial]),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = _filterKeys;
    final savedOutfitsBloc = _getSavedOutfitsBloc(context);

    return BlocBuilder<WardrobeBloc, WardrobeState>(
      builder: (context, wardrobeState) {
        if (savedOutfitsBloc != null) {
          return BlocBuilder<SavedOutfitsBloc, SavedOutfitsState>(
            bloc: savedOutfitsBloc,
            builder: (context, outfitsState) {
              return _buildScaffold(
                context,
                wardrobeState,
                outfitsState,
                filters,
              );
            },
          );
        }
        return _buildScaffold(
          context,
          wardrobeState,
          SavedOutfitsInitial(),
          filters,
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    WardrobeState wardrobeState,
    SavedOutfitsState outfitsState,
    List<String> filters,
  ) {
    final clothesCount = wardrobeState is WardrobeLoaded
        ? wardrobeState.allItems.length
        : 0;
    final looksCount = outfitsState is SavedOutfitsLoaded
        ? outfitsState.outfits.length
        : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _isSelectionMode
          ? AppPageAppBar(
              title: '${_selectedItemIds.length} seleccionadas',
              subtitle: 'MODO SELECCIÓN',
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancelar selección',
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedItemIds.clear();
                  });
                },
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  tooltip: 'Eliminar seleccionadas',
                  onPressed: _selectedItemIds.isNotEmpty
                      ? _deleteSelectedItems
                      : null,
                ),
                const SizedBox(width: 8),
              ],
            )
          : AppPageAppBar(
              title: AppStringsEs.myWardrobe,
              subtitle: AppStringsEs.curateCloset,
              actions: [
                IconButton(
                  onPressed: () => context.push('/smart-wardrobe'),
                  icon: const Icon(
                    Icons.auto_awesome,
                    color: AppColors.neonMagenta,
                  ),
                  tooltip: "Cher's Smart Closet",
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.search_outlined),
                  tooltip: AppStringsEs.search,
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: IconButton(
                      key: ValueKey<bool>(_isWarmingUp),
                      onPressed: () => _onAddButtonPressed(context),
                      icon: _isWarmingUp
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.gold,
                                ),
                              ),
                            )
                          : const Icon(Icons.add),
                      tooltip: _isWarmingUp
                          ? 'Preparando motor de imagen... listo en $_remainingSeconds s'
                          : AppStringsEs.addItem,
                      style: IconButton.styleFrom(
                        backgroundColor: _isWarmingUp
                            ? AppColors.surface
                            : AppColors.primary,
                        foregroundColor: _isWarmingUp
                            ? AppColors.gold
                            : AppColors.onPrimary,
                        side: _isWarmingUp
                            ? const BorderSide(color: AppColors.gold, width: 1)
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
      body: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          context.read<WardrobeBloc>().add(const LoadWardrobeItems());
          context.read<SavedOutfitsBloc>().add(LoadSavedOutfits());
          await Future<void>.delayed(const Duration(milliseconds: 600));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Botones compactos en Row: "Prendas: XX" y "Looks: XX"
            // Desaparecen al scrollear hacia abajo gracias al CustomScrollView
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatTabButton(
                        label: 'Prendas',
                        count: clothesCount,
                        icon: Icons.checkroom_outlined,
                        isSelected: _selectedTab == _WardrobeTab.clothes,
                        onTap: () {
                          if (_selectedTab != _WardrobeTab.clothes) {
                            setState(() => _selectedTab = _WardrobeTab.clothes);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTabButton(
                        label: 'Looks',
                        count: looksCount,
                        icon: Icons.auto_awesome_outlined,
                        isSelected: _selectedTab == _WardrobeTab.looks,
                        onTap: () {
                          if (_selectedTab != _WardrobeTab.looks) {
                            setState(() {
                              _selectedTab = _WardrobeTab.looks;
                              _isSelectionMode = false;
                              _selectedItemIds.clear();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Contenido según la pestaña activa
            if (_selectedTab == _WardrobeTab.clothes) ...[
              // Filtros por categoría de prendas
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 42,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = filters[index];
                      final isSelected =
                          wardrobeState is WardrobeLoaded &&
                          wardrobeState.selectedCategory.toLowerCase() ==
                              category.toLowerCase();
                      final label = _filterLabel(category);

                      return FilterChip(
                        label: Text(label.toUpperCase()),
                        selected: isSelected,
                        showCheckmark: false,
                        onSelected: (_) => context.read<WardrobeBloc>().add(
                          WardrobeFilterChanged(category),
                        ),
                        selectedColor: AppColors.inverseSurface,
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.onInverseSurface
                              : AppColors.onSurface,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                          letterSpacing: 1.4,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.inverseSurface
                              : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusXl,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              // Grid de prendas de vestir
              ..._buildClothesSlivers(context, wardrobeState),
            ] else ...[
              // Pestaña de Looks
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
              // Grid de looks generados / guardados
              ..._buildLooksSlivers(context, outfitsState),
            ],

            // Espaciado inferior para evitar solapamiento con el FAB y barra inferior
            SliverToBoxAdapter(
              child: SizedBox(height: ShellBottomInsets.withFab(context)),
            ),
          ],
        ),
      ),
      floatingActionButton: _LookCta(
        onTap: () => context.push('/generate-outfit'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  List<Widget> _buildClothesSlivers(BuildContext context, WardrobeState state) {
    if (state is WardrobeLoading) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 2,
            ),
          ),
        ),
      ];
    }
    if (state is WardrobeError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AtelierEmptyState(
            icon: Icons.error_outline,
            title: AppStringsEs.error,
            subtitle: state.message,
          ),
        ),
      ];
    }
    if (state is WardrobeLoaded) {
      if (state.filteredItems.isEmpty) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: AtelierEmptyState(
              icon: Icons.checkroom_outlined,
              title: AppStringsEs.emptyWardrobeTitle,
              subtitle: AppStringsEs.emptyWardrobeSubtitle,
              actionLabel: AppStringsEs.addFirstPiece,
              onAction: () => _onAddButtonPressed(context),
            ),
          ),
        ];
      }
      final items = state.filteredItems;
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.66,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              return WardrobeItemCard(
                item: item,
                isSelectionMode: _isSelectionMode,
                isSelected: _selectedItemIds.contains(item.id),
                onTap: _isSelectionMode ? () => _onItemTap(item.id) : null,
                onLongPress: () => _onItemLongPress(item.id),
                onRetryProcessing: () => _retryItem(context, item),
              );
            }, childCount: items.length),
          ),
        ),
      ];
    }
    return [
      const SliverFillRemaining(
        hasScrollBody: false,
        child: AtelierEmptyState(
          icon: Icons.checkroom_outlined,
          title: AppStringsEs.noData,
          subtitle: AppStringsEs.emptyWardrobeSubtitle,
        ),
      ),
    ];
  }

  List<Widget> _buildLooksSlivers(
    BuildContext context,
    SavedOutfitsState state,
  ) {
    if (state is SavedOutfitsLoading) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 2,
            ),
          ),
        ),
      ];
    }
    if (state is SavedOutfitsError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AtelierEmptyState(
            icon: Icons.error_outline,
            title: 'Error al cargar looks',
            subtitle: state.message,
            actionLabel: 'Reintentar',
            onAction: () =>
                context.read<SavedOutfitsBloc>().add(LoadSavedOutfits()),
          ),
        ),
      ];
    }
    if (state is SavedOutfitsLoaded) {
      if (state.outfits.isEmpty) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: AtelierEmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'Aún no tienes looks guardados',
              subtitle:
                  'Genera outfits con tu armario personal y aparecerán organizados aquí.',
              actionLabel: 'CREAR LOOK',
              onAction: () => context.push('/generate-outfit'),
            ),
          ),
        ];
      }
      final outfits = state.outfits;
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final outfit = outfits[index];
              return SavedOutfitCard(
                outfit: outfit,
                onTap: () {
                  context.read<SavedOutfitsBloc>().add(
                    ViewOutfit(outfitId: outfit.id),
                  );
                  OutfitDetailSheet.show(context, outfit);
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
            }, childCount: outfits.length),
          ),
        ),
      ];
    }
    return [
      const SliverFillRemaining(
        hasScrollBody: false,
        child: AtelierEmptyState(
          icon: Icons.auto_awesome_outlined,
          title: 'Cargando looks...',
          subtitle: 'Obteniendo tus outfits guardados',
        ),
      ),
    ];
  }
}

/// Botón estilizado compacto tipo píldora/tarjeta con disposición en Row
class _StatTabButton extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatTabButton({
    required this.label,
    required this.count,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.surfaceContainerHigh
                : AppColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.border.withValues(alpha: 0.6),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected ? AppTheme.ambientCardShadow : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.primary : AppColors.tertiary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? AppColors.onSurface
                          : AppColors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: '$count',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LookCta extends StatelessWidget {
  final VoidCallback onTap;

  const _LookCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      elevation: 0,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 18,
                color: AppColors.onPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                'NUEVO LOOK',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.onPrimary,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
